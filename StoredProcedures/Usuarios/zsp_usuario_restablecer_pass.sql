DROP PROCEDURE IF EXISTS `zsp_usuario_restablecer_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_restablecer_pass`(pToken varchar(256), pIdUsuario smallint ,pPassword varchar(255))

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario restablecer la contraseña de otro usuario.
        Devuelve 'OK' o el mensaje de error en Mensaje
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_restablecer_pass', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT 'ERR_NOEXISTE_USUARIO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT 'ERR_INGRESAR_PASSWORD' Mensaje;
        LEAVE SALIR;
    END IF;

    UPDATE  Usuarios 
    SET Password = pPassword
    WHERE IdUsuario = pIdUsuario;
    SELECT 'OK ' Mensaje;

END $$
DELIMITER ;


