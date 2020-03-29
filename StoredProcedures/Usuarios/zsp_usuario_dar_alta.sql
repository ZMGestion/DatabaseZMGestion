DROP PROCEDURE IF EXISTS `zsp_usuario_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_alta`(pToken varchar(256), pIdUsuario smallint)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Usuario a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve OK o el mensaje de error en Mensaje.
	*/
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF pIdUsuario IS NULL THEN
		SELECT 'ERR_INDICAR_USUARIO' pMensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'B') THEN
		SELECT 'ERR_USUARIO_ESTA_ALTA' pMensaje;
        LEAVE SALIR;
	END IF;

    UPDATE Usuarios SET Estado = 'A' WHERE IdUsuario = pIdUsuario;

END $$
DELIMITER ;

