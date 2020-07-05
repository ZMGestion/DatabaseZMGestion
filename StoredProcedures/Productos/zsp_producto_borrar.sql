DROP PROCEDURE IF EXISTS `zsp_producto_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar un producto junto con todos sus precios, controlando que no sea usado por un producto final.
        Devuelve null en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
         -- Para poder borrar en la tabla precios
        SET SQL_SAFE_UPDATES = 0;
        DELETE FROM Productos WHERE IdProducto = pIdProducto;
        DELETE FROM Precios WHERE Tipo = 'P' AND  IdReferencia = pIdProducto;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
        SET SQL_SAFE_UPDATES = 1;

    COMMIT;


END $$
DELIMITER ;
