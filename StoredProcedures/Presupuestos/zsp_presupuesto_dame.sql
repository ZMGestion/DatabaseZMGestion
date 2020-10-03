DROP PROCEDURE IF EXISTS `zsp_presupuesto_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite pasar instanciar un presupuesto a partir de su Id. 
        Devuelve el presupuesto con sus lineas de presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuestos
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pLineasPresupuesto JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdPresupuesto = pPresupuestos ->> "$.IdPresupuesto";

    IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    CALL zsp_usuario_tiene_permiso(pToken, 'dame_presupuesto_ajeno', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto AND IdUsuario = pIdUsuarioEjecuta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "Presupuestos",  JSON_OBJECT(
                'IdPresupuesto', p.IdPresupuesto,
                'IdCliente', p.IdCliente,
                'IdVenta', p.IdVenta,
                'IdUbicacion', p.IdUbicacion,
                'IdUsuario', p.IdUsuario,
                'PeriodoValidez', p.PeriodoValidez,
                'FechaAlta', p.FechaAlta,
                'Observaciones', p.Observaciones,
                'Estado', p.Estado,
                '_PrecioTotal', SUM(lp.Cantidad * lp.PrecioUnitario)
            ),
            "Clientes", JSON_OBJECT(
                'Nombres', c.Nombres,
                'Apellidos', c.Apellidos,
                'RazonSocial', c.RazonSocial,
                'Documento', c.Documento
            ),
            "Usuarios", JSON_OBJECT(
                "Nombres", u.Nombres,
                "Apellidos", u.Apellidos
            ),
            "Ubicaciones", JSON_OBJECT(
                "Ubicacion", ub.Ubicacion
            ),
            "Domicilios", JSON_OBJECT(
                "Domicilio", d.Domicilio
            ),
            "LineasPresupuesto", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario
                        ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            ), JSON_ARRAY())
        )
        FROM Presupuestos p
        INNER JOIN Clientes c ON c.IdCliente = p.IdCliente
        INNER JOIN Usuarios u ON u.IdUsuario = p.IdUsuario
        INNER JOIN Ubicaciones ub ON ub.IdUbicacion = p.IdUbicacion
        INNER JOIN Domicilios d ON d.IdDomicilio = ub.IdDomicilio
        LEFT JOIN LineasProducto lp ON p.IdPresupuesto = lp.IdReferencia AND lp.Tipo = 'P'
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	p.IdPresupuesto = pIdPresupuesto
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
