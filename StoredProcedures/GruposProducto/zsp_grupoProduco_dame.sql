DROP PROCEDURE IF EXISTS `zsp_grupoProducto_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Permite instanciar un grupo de productos a partir de su Id.
        Devuelve el grupo de producto en 'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- GrupoProducto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto int;
    
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_GRUPOPRODUCTO', NULL)pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS (SELECT Estado FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_GRUPOPRODUCTO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
                    'IdGrupoProducto', IdGrupoProducto,
                    'Grupo', Grupo,
                    'FechaAlta', FechaAlta,
                    'FechaBaja', FechaBaja,
                    'Descripcion', Descripcion,
                    'Estado', Estado
                )
        FROM	GruposProducto
        WHERE	IdGrupoProducto = pIdGrupoProducto
    );
    SELECT f_generarRespuesta(NULL, JSON_OBJECT("GruposProducto", pRespuesta)) AS pOut;


END $$
DELIMITER ;
