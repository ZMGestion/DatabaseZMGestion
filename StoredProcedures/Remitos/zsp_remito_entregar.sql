DROP PROCEDURE IF EXISTS zsp_remito_entregar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_entregar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite entregar un remito. Controla que tenga lineas y setea la fecha de entrega en caso de recibirla.
        Devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;
    DECLARE pFechaEntrega datetime;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_entregar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);
    SET pFechaEntrega = COALESCE(pIn->>'$.Remitos.FechaEntrega', NOW());

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdReferencia = pIdRemito AND Tipo = 'R') THEN
        SELECT f_generarRespuesta("ERROR_SINLINEAS_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'C' AND FechaEntrega IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_NOCREADO_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Remitos
        SET FechaEntrega = pFechaEntrega
        WHERE IdRemito = pIdRemito;

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
                    "Estado", f_calcularEstadoRemito(r.IdRemito)
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
            LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = 'R'
            LEFT JOIN Ubicaciones us ON lp.IdUbicacion = us.IdUbicacion
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	r.IdRemito = pIdRemito
        );

        SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
    COMMIT;  
END $$
DELIMITER ;
