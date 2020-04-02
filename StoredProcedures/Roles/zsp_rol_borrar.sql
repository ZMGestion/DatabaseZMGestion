DROP PROCEDURE IF EXISTS `zsp_rol_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_borrar`(pToken varchar(256), pIdRol tinyint)

SALIR: BEGIN
    /*
        Permite borrar un rol controlando que no exista un usuario asociado.
        Devuelve OK o el mensaje de error en Mensaje.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;
    
    IF pIdRol IS NULL THEN
		SELECT 'ERR_INDICAR_ROL' Mensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol) THEN
        SELECT 'ERR_NOEXISTE_ROL' Mensaje;
        LEAVE SALIR;
    END IF;
    
	IF EXISTS(SELECT IdRol FROM Usuarios WHERE IdRol = pIdRol) THEN
		SELECT 'ERR_BORRAR_ROL_USUARIO' Mensaje;
		LEAVE SALIR;
	END IF;
	
    START TRANSACTION;
	
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;
        DELETE FROM Roles WHERE IdRol = pIdRol;
        SELECT 'OK' Mensaje;

	COMMIT;
END $$
DELIMITER ;

