DROP PROCEDURE IF EXISTS `zsp_grupoProducto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_modificar` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un grupo de productos. Controla que no exista un Grupo de Productos con el mismo nombre.
        Devuelve el grupo de productos en 'respuesta' o el codigo de error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de producto a modificar
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pGrupo varchar(40);
    DECLARE pDescripcion varchar(255);

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";
    SET pGrupo = pGruposProducto ->> "$.Grupo";
    SET pDescripcion = pGruposProducto ->> "$.Descripcion";

    IF pIdGrupoProducto IS NULL OR NOT EXISTS(SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pGrupo = '' OR pGrupo IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE Grupo = pGrupo AND IdGrupoProducto <> pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    UPDATE GruposProducto
    SET Grupo = pGrupo,
        Descripcion = pDescripcion
    WHERE IdGrupoProducto = pIdGrupoProducto;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE IdGrupoProducto = pIdGrupoProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
