DROP PROCEDURE IF EXISTS `zsp_sesion_cerrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_cerrar`(pToken varchar(256), pIdUsuario smallint)

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_sesion_cerrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;
    
    IF pIdUsuario IS NULL THEN
		SELECT 'ERR_INDICAR_USUARIO' Mensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_NOEXISTE_USUARIO' Mensaje;
        LEAVE SALIR;
    END IF;
	
    START TRANSACTION;
	
        UPDATE Usuarios
        SET Token = ''
        WHERE IdUsuario = pIdusuario;
        SELECT 'OK' Mensaje;

	COMMIT;
END $$
DELIMITER ;

