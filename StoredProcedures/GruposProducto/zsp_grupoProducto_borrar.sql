DROP PROCEDURE IF EXISTS `zsp_grupoProducto_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_borrar`(pIn JSON)
SALIR: BEGIN
	/*
        Permite borrar un grupo de producto. Controla que no exista ningun producto que pertenezca al grupo de productos.
        Devuelve NULL'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de prodcuto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    
    -- Respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProducto FROM Productos WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTO_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;


    DELETE FROM GruposProducto
    WHERE IdGrupoProducto = pIdGrupoProducto;

    SELECT f_generarRespuesta(NULL, NULL) AS pOut;

END $$
DELIMITER ;

