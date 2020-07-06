DROP PROCEDURE IF EXISTS `zsp_producto_listar_precios`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_listar_precios`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar el historico de precios de un producto.
        Devuelve una lista de precios en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Producto del cual se desea conocer el historico de precios
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_listar_precios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "Precios",
            JSON_OBJECT(
                'IdPrecio', IdPrecio,
                'Precio', Precio,
                'FechaAlta', FechaAlta
            )
        )
    ) 
    FROM Precios 
    WHERE Tipo = 'P' AND IdReferencia = pIdProducto
    ORDER BY IdPrecio DESC
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
