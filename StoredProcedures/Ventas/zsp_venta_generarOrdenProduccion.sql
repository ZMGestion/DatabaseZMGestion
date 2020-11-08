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
            SELECT CAST(
                JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', IdOrdenProduccion,
                        'IdUsuario', IdUsuario,
                        'FechaAlta', FechaAlta,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM    OrdenesProduccion
            WHERE   IdOrdenProduccion = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;