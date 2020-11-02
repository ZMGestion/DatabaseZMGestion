DROP PROCEDURE IF EXISTS zsp_ordenProduccion_dame;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instanciar una orden de producción desde la base de datos.
        Devuelve la orden de producción en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    DECLARE pIdOrdenProduccion INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdOrdenProduccion = pIn ->> '$.OrdenesProduccion.IdOrdenProduccion';

    IF pIdOrdenProduccion IS NULL OR NOT EXISTS (SELECT IdOrdenProduccion FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pRespuesta = (
            SELECT CAST( JSON_OBJECT(
                "OrdenesProduccion",  JSON_OBJECT(
                    'IdOrdenProduccion', op.IdOrdenProduccion,
                    'IdUsuario', op.IdUsuario,
                    'IdVenta', op.IdVenta,
                    'FechaAlta', op.FechaAlta,
                    'Observaciones', op.Observaciones,
                    'Estado', f_dameEstadoOrdenProduccion(op.IdOrdenProduccion)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "LineasOrdenProduccion", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
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
            ) AS JSON)
            FROM OrdenesProduccion op
            INNER JOIN Usuarios u ON u.IdUsuario = op.IdUsuario
            LEFT JOIN LineasProducto lp ON op.IdOrdenProduccion = lp.IdReferencia AND lp.Tipo = 'O'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE IdOrdenProduccion = pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;