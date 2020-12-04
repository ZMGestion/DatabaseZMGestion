DROP PROCEDURE IF EXISTS zsp_venta_generarOrdenProduccion;
DELIMITER $$
CREATE PROCEDURE zsp_venta_generarOrdenProduccion(pIn JSON)
SALIR: BEGIN
    /*
        Permite a los usuarios generar una orden de producción para una venta

        pIn = {
            LineasVenta = [
                {
                    Cantidad,
                    IdProductoFinal,
                    IdLineasPadre,
                }
                ...
            ],
            LineasOrdenProduccion = [
                {
                    Cantidad,
                    IdProductoFinal,
                    IdLineasPadre,
                }
                ...
            ],
            Observaciones,
        }
    */
    
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    DECLARE pLineasVenta JSON;
    DECLARE pLineaOrdenProduccionVenta JSON;
    DECLARE pLineasOrdenProduccion JSON;
    DECLARE pCantidad INT;
    DECLARE pIdProductoFinal INT;
    DECLARE pObservaciones VARCHAR(255);
    DECLARE pIdLineasPadre JSON;

    DECLARE pLongitud INT UNSIGNED;
    DECLARE pIndex INT UNSIGNED DEFAULT 0;
    DECLARE pLongitudInterna INT UNSIGNED;
    DECLARE pInternalIndex INT UNSIGNED DEFAULT 0;
    DECLARE pCantidadRestante INT DEFAULT 0;
    DECLARE pCantidadActual INT DEFAULT 0;
    DECLARE pIdLineaVentaPadre BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pToken = pIn->>"$.UsuariosEjecuta.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_generarOrdenProduccion', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pLineasVenta = COALESCE(pIn ->> "$.LineasVenta", JSON_ARRAY());
    SET pLineasOrdenProduccion = COALESCE(pIn ->> "$.LineasOrdenProduccion", JSON_ARRAY());
    SET pObservaciones = pIn ->> "$.Observaciones";
    SET pLongitud = JSON_LENGTH(pLineasVenta);

    START TRANSACTION;

        INSERT INTO OrdenesProduccion (IdOrdenProduccion, IdUsuario, FechaAlta, Observaciones, Estado)
        VALUES (0, pIdUsuarioEjecuta, NOW(), pObservaciones, 'P');
        SET @pIdOrdenProduccion = LAST_INSERT_ID();

        WHILE pIndex < pLongitud DO
            SET pLineaOrdenProduccionVenta = JSON_EXTRACT(pLineasVenta, CONCAT("$[", pIndex, "]"));
            SET pCantidad = COALESCE(pLineaOrdenProduccionVenta->>"$.Cantidad",-1);
            SET pIdProductoFinal = pLineaOrdenProduccionVenta->>"$.IdProductoFinal";
            SET pIdLineasPadre = COALESCE(pLineaOrdenProduccionVenta->>"$.IdLineasPadre",JSON_ARRAY());

            SET pLongitud = JSON_LENGTH(pIdLineasPadre);
            WHILE pInternalIndex < pLongitud DO
                SET pIdLineaVentaPadre = JSON_EXTRACT(pIdLineasPadre, CONCAT("$[", pInternalIndex, "]"));
                SET pCantidadActual = (
                    SELECT Cantidad
                    FROM LineasProducto 
                    WHERE 
                        Tipo = 'V' 
                        AND IdReferencia = pIdLineaVentaPadre
                        AND f_dameEstadoLineaVenta(IdLineaProducto) = 'P'
                );

                SET pCantidadRestante := pCantidadRestante - pCantidadActual;
                IF pCantidadRestante < 0 THEN
                    SELECT f_generarRespuesta("ERROR_ORDEN_PRODUCCION_CANTIDAD_LINEA_VENTA", NULL) pOut;
                    LEAVE SALIR;
                END IF;

                INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaVentaPadre, pIdProductoFinal, NULL, @pIdOrdenProduccion, 'O', NULL, pCantidad, NOW(), NULL, 'F');

                SET pInternalIndex := pInternalIndex + 1;
            END WHILE;

            IF pCantidadRestante > 0 THEN
                INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, NULL, pIdProductoFinal, NULL, @pIdOrdenProduccion, 'O', NULL, pCantidad, NOW(), NULL, 'F');
            END IF;
            
            SET pIndex := pIndex + 1;
        END WHILE;

        SET pRespuesta = (
            SELECT CAST( JSON_OBJECT(
                "OrdenesProduccion",  JSON_OBJECT(
                    'IdOrdenProduccion', op.IdOrdenProduccion,
                    'IdUsuario', op.IdUsuario,
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
                            "IdLineaProductoPadre", lp.IdLineaProductoPadre,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "Estado", f_dameEstadoLineaOrdenProduccion(lp.IdLineaProducto)
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
            WHERE IdOrdenProduccion = @pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;