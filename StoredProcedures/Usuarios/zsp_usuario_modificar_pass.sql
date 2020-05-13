DROP PROCEDURE IF EXISTS `zsp_usuario_modificar_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar_pass`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar su contraseña comprobando que la contraseña actual ingresada sea correcta.
        Devuelve 'OK' o el mensaje de error en Mensaje
    */
    DECLARE pMensaje text;

    DECLARE pUsuariosEjecuta, pUsuariosActual, pUsuariosNuevo, pRespuesta JSON;

    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pPasswordActual varchar(255);
    DECLARE pPasswordNueva varchar(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar_pass', pIdUsuarioEjecuta, pMensaje);

    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuariosActual = pIn ->> "$.UsuariosActual";
    SET pPasswordActual = pUsuariosActual ->> "$.Password";

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuarioEjecuta AND Password = pPasswordActual) THEN
        SELECT f_generarRespuesta('ERROR_PASSWORD_INCORRECTA', NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuariosNuevo = pIn ->> "$.UsuariosNuevo";
    SET pPasswordNueva = pUsuariosNuevo ->> "$.Password";

    IF (pPasswordActual = pPasswordNueva) THEN
        SELECT f_generarRespuesta('ERROR_PASSWORDS_IGUALES', NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF(pPasswordNueva IS NULL OR pPasswordNueva = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_PASSWORD', NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;  
        UPDATE  Usuarios 
        SET Password = pPasswordNueva
        WHERE IdUsuario = pIdUsuarioEjecuta;

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


