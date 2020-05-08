DROP PROCEDURE IF EXISTS `zsp_rol_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_borrar`(pIn JSON)

SALIR: BEGIN
    /*
        Permite borrar un rol controlando que no exista un usuario asociado.
        Devuelve OK o el mensaje de error en Mensaje.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pRoles JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdRol int;
    DECLARE pToken varchar(256);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pIdRol IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INDICAR_ROL', NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
	IF EXISTS(SELECT IdRol FROM Usuarios WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_ROL_USUARIO', NULL) pOut;
		LEAVE SALIR;
	END IF;
	
    START TRANSACTION;
	
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;
        DELETE FROM Roles WHERE IdRol = pIdRol;
        SELECT f_generarRespuesta(NULL, NULL) pOut;

	COMMIT;
END $$
DELIMITER ;

