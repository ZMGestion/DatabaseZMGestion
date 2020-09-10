DROP PROCEDURE IF EXISTS zsp_lineaVenta_crear;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una linea de venta.
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno. 
        Controla que tenga permiso de cambiar el precio, en caso contrario setea el precio del producto final
        Devuelve la linea de producto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdLineaVenta bigint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        
        CALL zsp_lineasVenta_crear_interno(pIn, pIdLineaVenta);
        IF pError IS NOT NULL THEN
            SELECT f_generarRespuesta(pError, NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
                        'IdLineaProducto', lp.IdLineaProducto,
                        'IdLineaProductoPadre', lp.IdLineaProductoPadre,
                        'IdProductoFinal', lp.IdProductoFinal,
                        'IdUbicacion', lp.IdUbicacion,
                        'IdReferencia', lp.IdReferencia,
                        'Tipo', lp.Tipo,
                        'PrecioUnitario', lp.PrecioUnitario,
                        'Cantidad', lp.Cantidad,
                        'FechaAlta', lp.FechaAlta,
                        'FechaCancelacion', lp.FechaCancelacion,
                        'Estado', lp.Estado
                    ) 
                )
            AS JSON)
            FROM	LineasProducto lp
            WHERE	lp.IdLineaProducto = pIdLineaVenta
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
