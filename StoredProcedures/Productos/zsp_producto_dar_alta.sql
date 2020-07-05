DROP PROCEDURE IF EXISTS `zsp_producto_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_dar_alta`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de alta un producto que se encontraba en estado "Baja". Controla que el producto exista
        Devuelve un json con el producto en 'respuesta' o el error en 'error'.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_dar_alta', pIdUsuarioEjecuta, pMensaje);
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

    IF (SELECT Estado FROM Productos WHERE IdProducto = pIdProducto) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTO_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Productos
        SET Estado = 'A'
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
                        )
                )
             AS JSON)
			FROM	Productos p
			WHERE	p.IdProducto = pIdProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;


    COMMIT;


END $$
DELIMITER ;
