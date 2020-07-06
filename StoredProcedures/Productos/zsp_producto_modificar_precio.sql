DROP PROCEDURE IF EXISTS `zsp_producto_modificar_precio`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_modificar_precio`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el precio de un producto. Controla que el precio sea mayor que cero.
        Devuelve un json con el producto y el precio en 'respuesta' o el 'error' en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Precio
    DECLARE pPrecios JSON;
    DECLARE pIdPrecio int;
    DECLARE pPrecio decimal(10,2);

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_modificar_precio', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos del producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";
    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";


    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    IF pPrecio = (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'P', pIdProducto, NOW());

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Productos",  JSON_OBJECT(
                        'IdProducto', p.IdProducto,
                        'IdCategoriaProducto', p.IdCategoriaProducto,
                        'IdGrupoProducto', p.IdGrupoProducto,
                        'IdTipoProducto', p.IdTipoProducto,
                        'Producto', p.Producto,
                        'LongitudTela', p.LongitudTela,
                        'FechaAlta', p.FechaAlta,
                        'FechaBaja', p.FechaBaja,
                        'Observaciones', p.Observaciones,
                        'Estado', p.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', ps.IdPrecio,
                        'Precio', ps.Precio,
                        'FechaAlta', ps.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Productos p
            INNER JOIN Precios ps ON (ps.Tipo = 'P' AND p.IdProducto = ps.IdReferencia)
			WHERE	p.IdProducto = pIdProducto AND ps.IdPrecio = pIdPrecio
        );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT;
END $$
DELIMITER ;
