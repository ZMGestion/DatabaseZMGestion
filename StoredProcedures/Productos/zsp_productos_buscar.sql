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

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                "Productos",
                JSON_OBJECT(
                    'IdProducto', IdProducto,
                    'IdCategoriaProducto', IdCategoriaProducto,
                    'IdGrupoProducto', IdGrupoProducto,
                    'IdTipoProducto', IdTipoProducto,
                    'Producto', Producto,
                    'LongitudTela', LongitudTela,
                    'FechaAlta', FechaAlta,
                    'FechaBaja', FechaBaja,
                    'Observaciones', Observaciones,
                    'Estado', Estado
                )
            )
        )
	FROM Productos 
	WHERE	
        Producto LIKE CONCAT(pProducto, '%') AND
        (Estado = pEstado OR pEstado = 'T') AND
        (IdTipoProducto = pIdTipoProducto OR pIdTipoProducto = 'T') AND
        (IdCategoriaProducto = pIdCategoriaProducto OR pIdCategoriaProducto = 0) AND
        (IdGrupoProducto = pIdGrupoProducto OR pIdGrupoProducto = 0)
	ORDER BY Producto);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    

END $$
DELIMITER ;

