DROP PROCEDURE IF EXISTS `zsp_usuario_dar_baja`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_baja`(pToken varchar(256), pIdUsuario smallint)

SALIR: BEGIN
    /*
        Permite cambiar el estado del Usuario a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve OK o el mensaje de error en Mensaje.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'Error en la transacción. Contáctese con el administrador.' Mensaje;
        ROLLBACK;
	END;

	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;
    
    IF pIdUsuario IS NULL THEN
		SELECT 'ERROR_INDICAR_USUARIO' pMensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS (SELECT IdUsuario From Usuarios WHERE IdUsuario = pIdUsuario) THEN
		SELECT 'ERROR_NOEXISTE_USUARIO' pMensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
		SELECT 'ERROR_USUARIO_ESTA_BAJA' pMensaje;
        LEAVE SALIR;
	END IF;
		

	UPDATE Usuarios SET Estado = 'B' WHERE IdUsuario = pIdUsuario;
    SELECT'OK', Mensaje;

END $$
DELIMITER ;

