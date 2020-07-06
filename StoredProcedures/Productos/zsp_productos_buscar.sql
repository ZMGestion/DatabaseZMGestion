DROP PROCEDURE IF EXISTS `zsp_productos_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_productos_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar un producto por su nombre, Tipo de Producto (T: Todos), Categoria de Productos (0: Todos), Grupo de Productos (0 : Todos), Estado (A:Activo - B:Baja - T:Todos).
        Devuelve una lista de productos en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdCategoriaProducto tinyint;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pIdTipoProducto char(1);
    DECLARE pProducto varchar(80);
    DECLARE pEstado char(1);

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productos_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pProducto = pProductos ->> "$.Producto";
    SET pIdCategoriaProducto = pProductos ->> "$.IdCategoriaProducto";
    SET pIdGrupoProducto = pProductos ->> "$.IdGrupoProducto";
    SET pIdTipoProducto = pProductos ->> "$.IdTipoProducto";
    SET pEstado = pProductos ->> "$.Estado";

    IF pIdTipoProducto IS NULL OR pIdTipoProducto = '' THEN
		SET pIdTipoProducto = 'T';
	END IF;

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    SET pProducto = COALESCE(pProducto, '');
    SET pIdCategoriaProducto = COALESCE(pIdCategoriaProducto, 0);
    SET pIdGrupoProducto = COALESCE(pIdGrupoProducto, 0);

    DROP TEMPORARY TABLE IF EXISTS tmp_Productos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;


    CREATE TEMPORARY TABLE tmp_Productos 
    AS SELECT *
    FROM Productos 
	WHERE	
        Producto LIKE CONCAT(pProducto, '%') AND
        (Estado = pEstado OR pEstado = 'T') AND
        (IdTipoProducto = pIdTipoProducto OR pIdTipoProducto = 'T') AND
        (IdCategoriaProducto = pIdCategoriaProducto OR pIdCategoriaProducto = 0) AND
        (IdGrupoProducto = pIdGrupoProducto OR pIdGrupoProducto = 0)
	ORDER BY Producto;

    CREATE TEMPORARY TABLE tmp_preciosProductos AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'P' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPrecios AS
    SELECT pr.* 
    FROM tmp_preciosProductos tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                "Productos",
                    JSON_OBJECT(
                        'IdProducto', tp.IdProducto,
                        'IdCategoriaProducto', tp.IdCategoriaProducto,
                        'IdGrupoProducto', tp.IdGrupoProducto,
                        'IdTipoProducto', tp.IdTipoProducto,
                        'Producto', tp.Producto,
                        'LongitudTela', tp.LongitudTela,
                        'FechaAlta', tp.FechaAlta,
                        'FechaBaja', tp.FechaBaja,
                        'Observaciones', tp.Observaciones,
                        'Estado', tp.Estado
                    ),
                "Precios", 
                    JSON_OBJECT(
                        'IdPrecio', tps.IdPrecio,
                        'Precio', tps.Precio
                    )
            )
        )
	FROM tmp_Productos tp
    INNER JOIN tmp_ultimosPrecios tps ON (tps.Tipo = 'P' AND tp.IdProducto = tps.IdReferencia)
	);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_Productos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;

    

END $$
DELIMITER ;
