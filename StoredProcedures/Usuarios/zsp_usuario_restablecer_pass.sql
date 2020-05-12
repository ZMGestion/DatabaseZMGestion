DROP PROCEDURE IF EXISTS `zsp_usuario_restablecer_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_restablecer_pass`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario restablecer la contraseña de otro usuario. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pIdUsuario smallint;
    DECLARE pPassword varchar(255);
    DECLARE pToken varchar(256);
    DECLARE pUsuarios, pUsuariosEjecuta, pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_restablecer_pass', pIdUsuarioEjecuta, pMensaje);

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";
    SET pPassword = pUsuarios ->> "$.Password";
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_PASSWORD', NULL) pOut;
        LEAVE SALIR;
    END IF;

    UPDATE  Usuarios 
    SET Password = pPassword
    WHERE IdUsuario = pIdUsuario;
    
    SELECT f_generarRespuesta(NULL, NULL) pOut;

END $$
DELIMITER ;


