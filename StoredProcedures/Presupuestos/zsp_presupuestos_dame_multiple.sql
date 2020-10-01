DROP PROCEDURE IF EXISTS zsp_presupuestos_dame_multiple;
DELIMITER $$
CREATE PROCEDURE zsp_presupuestos_dame_multiple(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instancias mas de un presupuesto a partir de sus Id.
        Devuelve los presupuestos con sus lineas de presupuesto en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;

    DECLARE pLongitud int unsigned;
    DECLARE pIndex int unsigned DEFAULT 0;
    DECLARE pCondicion varchar(100);

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuestos_dame_multiple', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pLongitud = JSON_LENGTH(pPresupuestos);
    SET pRespuesta = JSON_ARRAY();

    WHILE pIndex < pLongitud DO
        SET pIdPresupuesto = JSON_EXTRACT(pPresupuestos, CONCAT("$[", pIndex, "]"));

        IF NOT EXISTS(SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET @pPresupuesto = (
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
                    'Estado', p.Estado
                ),
                "Clientes", JSON_OBJECT(
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasPresupuesto", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "_PrecioUnitarioActual",  f_calcularPrecioProductoFinal(lp.IdProductoFinal)
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
            LEFT JOIN LineasProducto lp ON p.IdPresupuesto = lp.IdReferencia AND lp.Tipo = 'P'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	p.IdPresupuesto = pIdPresupuesto
        );

        SET pRespuesta = JSON_ARRAY_INSERT(pRespuesta, CONCAT('$[', pIndex, ']'), CAST(@pPresupuesto AS JSON));
        SET pIndex = pIndex + 1;
    END WHILE;
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
