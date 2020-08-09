DROP PROCEDURE IF EXISTS `zsp_producto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_modificar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un producto. Controla que no exista uno con el mismo nombre y que pertenezca a la misma catgoria y grupo de productos, quue la longitud de tela necesaria
        sea mayor o igual que cero, que existan la categoeria, el grupo y el tipo de producto.
        Devuelve el producto con su precio en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;
    DECLARE pIdCategoriaProducto tinyint;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pIdTipoProducto char(1);
    DECLARE pProducto varchar(80);
    DECLARE pLongitudTela decimal(10,2);
    DECLARE pObservaciones varchar(255);
    
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";
    SET pProducto = pProductos ->> "$.Producto";
    SET pIdCategoriaProducto = pProductos ->> "$.IdCategoriaProducto";
    SET pIdGrupoProducto = pProductos ->> "$.IdGrupoProducto";
    SET pIdTipoProducto = pProductos ->> "$.IdTipoProducto";
    SET pLongitudTela = pProductos ->> "$.LongitudTela";
    SET pObservaciones = pProductos ->> "$.Observaciones";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pProducto IS NULL OR pProducto = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdCategoriaProducto IS NULL OR NOT EXISTS (SELECT IdCategoriaProducto FROM CategoriasProducto WHERE IdCategoriaProducto = pIdCategoriaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CATEGORIAPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto AND Estado = 'A')) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProducto FROM Productos WHERE Producto = pProducto AND IdCategoriaProducto = pIdCategoriaProducto AND IdGrupoProducto = pIdGrupoProducto AND IdProducto <> pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pLongitudTela < 0 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDA_LONGITUDTELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdTipoProducto FROM TiposProducto WHERE IdTipoProducto = pIdTipoProducto) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

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

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    START TRANSACTION;

    IF pPrecio <> (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        -- Verificamos que tenga permiso para modificar el precio
        CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_modificar_precio', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;

        INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'P', pIdProducto, NOW());

        SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;
    END IF;

    
    UPDATE Productos
    SET IdCategoriaProducto = pIdCategoriaProducto,
        IdGrupoProducto = pIdGrupoProducto,
        IdTipoProducto = pIdTipoProducto,
        Producto = pProducto,
        LongitudTela = pLongitudTela,
        Observaciones = NULLIF(pObservaciones, '')
    WHERE IdProducto = pIdProducto;

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
            INNER JOIN Precios ps ON (ps.Tipo = 'P' AND ps.IdReferencia = pIdPrecio)
			WHERE	p.IdProducto = pIdProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
