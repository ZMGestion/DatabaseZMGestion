DROP PROCEDURE IF EXISTS `zsp_sesion_cerrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_cerrar`(pIn JSON)

SALIR: BEGIN
    /*
        Permite cerrar la sesion de un usuario a partir de su Id.
        Devuelve OK o el mensaje de error en Mensaje.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pIdUsuario smallint;
    DECLARE pUsuarios, pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    SET pIdUsuario = pUsuarios ->> '$.IdUsuario';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_sesion_cerrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pIdUsuario IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INDICAR_USUARIO', NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL) pOut;
        LEAVE SALIR;
    END IF;
	
    START TRANSACTION;
        UPDATE Usuarios
        SET Token = ''
        WHERE IdUsuario = pIdusuario;
        SELECT f_generarRespuesta(NULL, NULL) pOut;
	COMMIT;
END $$
DELIMITER ;

