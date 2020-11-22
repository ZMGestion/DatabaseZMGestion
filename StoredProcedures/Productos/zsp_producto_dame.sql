DROP PROCEDURE IF EXISTS `zsp_producto_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite instanciar un producto a partir de su Id.
        Devuelve el producto con su precio actual en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a borrar
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Precio actual
    DECLARE pIdPrecio int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Para stock
    DECLARE pStock JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_dame', pIdUsuarioEjecuta, pMensaje);
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

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    SELECT IdProductoFinal INTO @pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdTela IS NULL AND IdLustre IS NULL;

    IF COALESCE(@pIdProductoFinal, 0) > 0 THEN
        SET pStock = (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', IdUbicacion,
                        'IdDomicilio', IdDomicilio,
                        'Ubicacion', Ubicacion,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ),
                    "Cantidad", f_calcularStockProducto(@pIdProductoFinal, IdUbicacion)
                )
            ) Stock
            FROM Ubicaciones
            WHERE f_calcularStockProducto(@pIdProductoFinal, IdUbicacion) > 0
        );
    END IF;

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
                        'Estado', p.Estado,
                        'Stock', pStock
                    ),
                    "GruposProducto", 
                        JSON_OBJECT(
                            'IdGrupoProducto', gp.IdGrupoProducto,
                            'Grupo', gp.Grupo,
                            'Estado', gp.Estado
                        ),
                    "CategoriasProducto", 
                        JSON_OBJECT(
                            'IdCategoriaProducto', cp.IdCategoriaProducto,
                            'Categoria', cp.Categoria
                        ),
                    "TiposProducto", 
                        JSON_OBJECT(
                            'IdTipoProducto', tp.IdTipoProducto,
                            'TipoProducto', tp.TipoProducto
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
            INNER JOIN GruposProducto gp ON (gp.IdGrupoProducto = p.IdGrupoProducto)
            INNER JOIN TiposProducto tp ON (p.IdTipoProducto = tp.IdTipoProducto)
            INNER JOIN CategoriasProducto cp ON (cp.IdCategoriaProducto = p.IdCategoriaProducto)
			WHERE	p.IdProducto = pIdProducto AND ps.IdPrecio = pIdPrecio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;

