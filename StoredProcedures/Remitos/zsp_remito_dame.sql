DROP PROCEDURE IF EXISTS zsp_remito_dame;
DELIMITER $$
CREATE PROCEDURE zsp_remito_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instanciar un remito a partir de su Id.
        Devuelve el remito en "respuesta" o el error en "errorr.
    */
    DECLARE pIdRemito int;
    DECLARE pRespuesta JSON;
    DECLARE pExtra JSON;
    

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, "zsp_remito_dame", pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != "OK" THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>"$.Remitos.IdRemito", 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_REMITO_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT lpp.IdLineaProducto FROM LineasProducto lp INNER JOIN LineasProducto lpp ON lp.IdLineaProductoPadre = lpp.IdLineaProducto WHERE lp.IdReferencia = pIdRemito AND lp.Tipo = "R" AND lpp.Tipo = "V") THEN
        SET pExtra = (
            SELECT JSON_OBJECT(
                "Ventas",  JSON_OBJECT(
                    "IdVenta", v.IdVenta,
                    "IdCliente", v.IdCliente,
                    "IdDomicilio", v.IdDomicilio,
                    "IdUbicacion", v.IdUbicacion,
                    "IdUsuario", v.IdUsuario,
                    "FechaAlta", v.FechaAlta,
                    "Observaciones", v.Observaciones,
                    "Estado", f_calcularEstadoVenta(v.IdVenta)
                ),
                "Clientes", JSON_OBJECT(
                    "Nombres", c.Nombres,
                    "Apellidos", c.Apellidos,
                    "RazonSocial", c.RazonSocial
                ),
                "Domicilios", JSON_OBJECT(
                    "Domicilio", d.Domicilio
                )
            )
            FROM LineasProducto lp
            INNER JOIN LineasProducto lpp ON lpp.IdLineaProducto = lp.IdLineaProductoPadre
            INNER JOIN Ventas v ON lpp.IdReferencia = v.IdVenta
            INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
            LEFT JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
            WHERE lp.IdReferencia = pIdRemito AND lp.Tipo = "R" AND lpp.Tipo = "V"
        );
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "Remitos",  JSON_OBJECT(
                "IdRemito", r.IdRemito,
                "IdUbicacion", r.IdUbicacion,
                "IdUsuario", r.IdUsuario,
                "Tipo", r.Tipo,
                "FechaEntrega", r.FechaEntrega,
                "FechaAlta", r.FechaAlta,
                "Observaciones", r.Observaciones,
                "Estado", f_calcularEstadoRemito(r.IdRemito),
                "_Extra", pExtra
            ),
            "Usuarios", JSON_OBJECT(
                "Nombres", u.Nombres,
                "Apellidos", u.Apellidos
            ),
            "Ubicaciones", JSON_OBJECT(
                "Ubicacion", ue.Ubicacion
            ),
            "LineasRemito", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "IdUbicacion", lp.IdUbicacion,
                        "Estado", lp.Estado
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
                    "Ubicaciones", JSON_OBJECT(
                        "Ubicacion", us.Ubicacion
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
        FROM Remitos r
        INNER JOIN Usuarios u ON u.IdUsuario = r.IdUsuario
        LEFT JOIN Ubicaciones ue ON ue.IdUbicacion = r.IdUbicacion
        LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = "R"
        LEFT JOIN Ubicaciones us ON lp.IdUbicacion = us.IdUbicacion
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	r.IdRemito = pIdRemito
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    
END $$
DELIMITER ;
