DROP PROCEDURE IF EXISTS `zsp_usuario_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
        Debe existir el Rol, TipoDocumento y la Ubicacion.
        Almacena el hash de la contraseña.
        Todos los campos son obligatorios.
        Devuelve 'OK' + IdUsuario o el mensaje de error en  Mensaje.
    */

    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuario smallint;
    DECLARE pToken varchar(256);
    DECLARE pIdRol tinyint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pNombres varchar(60);
    DECLARE pApellidos varchar(60);
    DECLARE pEstadoCivil char(1);
    DECLARE pTelefono varchar(15);
    DECLARE pEmail varchar(120);
    DECLARE pCantidadHijos tinyint;
    DECLARE pUsuario varchar(40);
    DECLARE pPassword varchar(255);
    DECLARE pFechaNacimiento date;
    DECLARE pFechaInicio date;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;


    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pIdUbicacion = pUsuarios ->> "$.IdUbicacion";
    SET pIdTipoDocumento = pUsuarios ->> "$.IdTipoDocumento";
    SET pDocumento = pUsuarios ->> "$.Documento";
    SET pNombres = pUsuarios ->> "$.Nombres";
    SET pApellidos = pUsuarios ->> "$.Apellidos";
    SET pEstadoCivil = pUsuarios ->> "$.EstadoCivil";
    SET pTelefono = pUsuarios ->> "$.Telefono";
    SET pEmail = pUsuarios ->> "$.Email";
    SET pCantidadHijos = pUsuarios ->> "$.CantidadHijos";
    SET pPassword = pUsuarios ->> "$.Password";
    SET pUsuario = pUsuarios ->> "$.Usuario";
    SET pFechaNacimiento = pUsuarios ->> "$.FechaNacimiento";
    SET pFechaInicio = pUsuarios ->> "$.FechaInicio";


    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_TIPODOC', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_DOCUMENTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento AND IdUsuario != pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_EXISTE_USUARIO_TIPODOC_DOC', NULL)pOut;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBRE', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_APELLIDO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT f_generarRespuesta('ERROR_INVALIDO_ESTADOCIVIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_TELEFONO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT f_generarRespuesta('ERROR_INGRESAR_EMAIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail AND IdUsuario != pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_EXISTE_EMAIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_CANTIDADHIJOS', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF pUsuario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_USUARIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT f_generarRespuesta('ERROR_ESPACIO_USUARIO', NULL)pOut;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario AND IdUsuario != pIdUsuario) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_USUARIO', NULL)pOut;
		LEAVE SALIR;
	END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT f_generarRespuesta('ERROR_FECHANACIMIENTO_ANTERIOR', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT f_generarRespuesta('ERROR_FECHAINICIO_ANTERIOR', NULL)pOut;
        LEAVE SALIR;
    END IF;
    START TRANSACTION;  
    
        UPDATE  Usuarios 
        SET IdUsuario = pIdUsuario,
            IdRol = pIdRol,
            IdUbicacion = pIdUbicacion,
            IdTipoDocumento = pIdTipoDocumento,
            Documento = pDocumento,
            Nombres = pNombres, 
            Apellidos = pApellidos,
            EstadoCivil =  pEstadoCivil,
            Telefono = pTelefono,
            Email = pEmail,
            CantidadHijos = pCantidadHijos,
            Usuario = pUsuario,
            FechaNacimiento = pFechaNacimiento,
            FechaInicio = pFechaInicio
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


