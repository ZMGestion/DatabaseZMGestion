DROP PROCEDURE IF EXISTS `zsp_categoriasProducto_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_categoriasProducto_listar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar las categorias de producto.
        Devuelve una lista de categorias de producto en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_categoriasProducto_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "CategoriasProducto",
            JSON_OBJECT(
                'IdCategoriaProducto', IdCategoriaProducto,
                'Categoria', Categoria,
                'Descripcion', Descripcion
            )
        )
    ) 
    FROM CategoriasProducto
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;
