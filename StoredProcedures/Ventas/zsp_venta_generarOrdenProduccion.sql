DROP PROCEDURE IF EXISTS zsp_venta_generarOrdenProduccion;
DELIMITER $$
CREATE PROCEDURE zsp_venta_generarOrdenProduccion(pIn JSON)
SALIR: BEGIN
    /*
        Permite a los usuarios generar una orden de producción para una venta

        pIn = {
            LineasVenta = [
                IdLineaVenta,
                ...
            ],
            Cantidades = {
                IdLineaVenta: Cantidad,
                ...
            },
            Observaciones,
        }
    */
    
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    DECLARE pLineasVenta JSON;
    DECLARE pCantidades JSON;
    DECLARE pObservaciones VARCHAR(255);

    DECLARE

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
    SET pObservaciones = pIn ->> "$.Observaciones";
    SET pLongitud = JSON_LENGTH(pLineasVenta);

    START TRANSACTION;

        WHILE pIndex < pLongitud DO
            SET pIdLineaVenta = JSON_EXTRACT(pLineasVenta, CONCAT("$[", pIndex, "]"));

            IF pIndex = 0 THEN
                SET pIdVenta = (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta);

                INSERT INTO OrdenesProduccion (IdOrdenProduccion, IdUsuario, IdVenta, FechaAlta, Observaciones, Estado)
                VALUES (0, pIdUsuarioEjecuta, pIdVenta, NOW(), pObservaciones, 'P');
                SET @pIdVenta = LAST_INSERT_ID();
            ELSE
                IF (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta) !=  pIdVenta THEN
                    SELECT f_generarRespuesta("ERROR", NULL) pOut;
                    LEAVE SALIR;
                END IF;
            END IF;
            
            SET pIndex := pIndex + 1;
        END WHILE;

    
        INSERT INTO OrdenesProduccion (IdOrdenProduccion, IdUsuario, IdVenta, FechaAlta, Observaciones, Estado) VALUES (0, pIdUsuarioEjecuta, pIdVenta, NOW(), pObservaciones, 'E');

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', IdOrdenProduccion,
                        'IdUsuario', IdUsuario,
                        'IdVenta', IdVenta,
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