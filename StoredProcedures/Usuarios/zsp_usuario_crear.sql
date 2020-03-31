DROP PROCEDURE IF EXISTS `zsp_usuario_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_crear`(pToken varchar(256), pIdRol tinyint, pIdUbicacion tinyint,pIdTipoDocumento tinyint, pDocumento varchar(15), pNombres varchar(60), pApellidos varchar(60), pEstadoCivil char(1), pTelefono varchar(15),
                                    pEmail varchar(120), pCantidadHijos tinyint, pUsuario varchar(40), pPassword varchar(255), pFechaNacimiento date, pFechaInicio date, OUT pIdUsuario smallint)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario crear un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
        Debe existir el Rol, TipoDocumento y la Ubicacion.
        Almacena el hash de la contraseña.
        Todos los campos son obligatorios.
        Devuelve 'OK' + IdUsuario o el mensaje de error en  Mensaje.
    */
    DECLARE pIdUsuario smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT 'ERR_NOEXISTE_ROL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT 'ERR_NOEXISTE_UBICACION' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT 'ERR_NOEXISTE_TIPODOC' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT 'ERR_INGRESAR_DOCUMENTO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT 'ERR_EXISTE_USUARIO_TIPODOC_DOC' Mensaje;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT 'ERR_INGRESAR_NOMBRE' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT 'ERR_INGRESAR_APELLIDO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT 'ERR_INVALIDO_ESTADOCIVIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT 'ERR_INGRESAR_TELEFONO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT 'ERR_INGRESAR_EMAIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail) THEN
        SELECT 'ERR_EXISTE_EMAIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT 'ERR_INGRESAR_CANTIDADHIJOS' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT 'ERR_ESPACIO_USUARIO' Mensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario) THEN
		SELECT 'ERR_EXISTE_USUARIO' Mensaje;
		LEAVE SALIR;
	END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT 'ERR_INGRESAR_PASSWORD' Mensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT 'ERR_FECHANACIMIENTO_ANTERIOR' Mensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT 'ERR_FECHAINICIO_ANTERIOR' Mensaje;
        LEAVE SALIR;
    END IF;



    START TRANSACTION;
        INSERT INTO Usuarios SELECT 0, pIdRol, pIdUbicacion, pIdTipoDocumento, pDocumento, pNombres, pApellidos, pEstadoCivil, pTelefono, pEmail, pCantidadHijos, pUsuario, pPassword, NULL, 0, NULL ,pFechaNacimiento, pFechaInicio, NOW(), NULL,'A';
        SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        SELECT 'OK ', pMensaje;
    COMMIT;
END $$
DELIMITER ;

