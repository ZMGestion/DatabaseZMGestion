DROP PROCEDURE IF EXISTS `zsp_usuario_dar_baja`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_baja`(pIn JSON)

SALIR: BEGIN
    /*
        Permite cambiar el estado del Usuario a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve el usuario en 'respuesta' o el codigo de error en 'error.
    */
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";

    IF pIdUsuario = 1 THEN
		SELECT f_generarRespuesta('ERROR_DARBAJA_USUARIO_ADAM', NULL)pOut;
		LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

     IF (@pEstado = 'B') THEN
        SELECT f_generarRespuesta('ERROR_USUARIO_ESTA_BAJA', NULL)pOut;
        LEAVE SALIR;
    END IF;
		
    START TRANSACTION;
        UPDATE Usuarios 
        SET Estado = 'B',
            Token = NULL 
        WHERE IdUsuario = pIdUsuario;
        SET pRespuesta = (
                SELECT CAST(
                        COALESCE(
                            JSON_OBJECT(
                                'IdUsuario', IdUsuario,
                                'IdRol', IdRol,
                                'IdUbicacion', IdUbicacion,
                                'IdTipoDocumento', IdTipoDocumento,
                                'Documento', Documento,
                                'Nombres', Nombres,
                                'Apellidos', Apellidos,
                                'EstadoCivil', EstadoCivil,
                                'Telefono', Telefono,
                                'Email', Email,
                                'CantidadHijos', CantidadHijos,
                                'Usuario', Usuario,
                                'FechaUltIntento', FechaUltIntento,
                                'FechaNacimiento', FechaNacimiento,
                                'FechaInicio', FechaInicio,
                                'FechaAlta', FechaAlta,
                                'FechaBaja', FechaBaja,
                                'Estado', Estado
                            )
                        ,'') AS JSON)
                FROM	Usuarios
                WHERE	IdUsuario = pIdUsuario
            );
            SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;

