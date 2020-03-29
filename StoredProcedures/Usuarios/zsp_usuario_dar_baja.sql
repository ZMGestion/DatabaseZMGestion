DROP PROCEDURE IF EXISTS `zsp_usuario_dar_baja`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_baja`(pToken varchar(256), pIdUsuario smallint)

SALIR: BEGIN
    /*
        Procedimiento que permite dar de baja un usuario activo.
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
		SELECT 'ERR_INDICAR_USUARIO' pMensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'B') THEN
		SELECT 'ERR_USUARIO_ESTA_BAJA' pMensaje;
        LEAVE SALIR;
	END IF;
		

	UPDATE Usuarios SET Estado = 'B' WHERE IdUsuario = pIdUsuario;

END $$
DELIMITER ;

