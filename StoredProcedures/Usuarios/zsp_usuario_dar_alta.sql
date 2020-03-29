DROP PROCEDURE IF EXISTS `zsp_usuario_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_alta`(pToken varchar(256), pIdUsuario smallint, OUT pMensaje text)

SALIR: BEGIN
    /*
        Permite cambiar el estado del Usuario a 'Alta' siempre y cuando no esté en estado 'Alta' ya. Devuelve OK o el mensaje de error en Mensaje.
    */

    DECLARE pIdUsuario smallint;
    DECLARE pMensaje varchar(255);
    DECLARE pIdUsuarioAud smallint;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
		SELECT 'Error en la transacción. Contáctese con el administrador.' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_alta', pIdUsuarioAud, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF pIdUsuario IS NULL THEN
		SELECT 'Debe indicar un usuario.' pMensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
		SELECT 'El usuario ya está estado de "Alta"' pMensaje;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;
        UPDATE Usuarios SET Estado = 'A' WHERE IdUsuario = pIdUsuario;
        SELECT 'OK' pMensaje;
    COMMIT;
END $$
DELIMITER ;

