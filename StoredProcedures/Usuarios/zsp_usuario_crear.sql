DROP PROCEDURE IF EXISTS `zsp_usuario_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_crear`(pToken char(32), pIdRol tinyint, pIdUbicacion tinyint,pIdTipoDocumento tinyint, pDocumento varchar(15), pNombres varchar(60), pApellidos varchar(60), pEstadoCivil char(1), pTelefono varchar(15),
                                    pEmail varchar(120), pCantidadHijos tinyint, pUsuario varchar(40), pPassword varchar(255), pFechaNacimiento date, pFechaInicio date, OUT pMensaje text, OUT pIdUsuario smallint)

SALIR:BEGIN
    /*
        Procedimiento que permite a un administrador crear un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
        Debe existir el Rol, TipoDocumento y la Ubicacion.
        Almacena el hash de la contraseña.
        Todos los campos son obligatorios.
        Devuelve 'OK' + IdUsuario o el mensaje de error en  Mensaje.
    */
    DECLARE pIdUsuario smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuarioAud smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT 'ERR_NOEXISTE_ROL' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT 'ERR_NOEXISTE_UBICACION' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT 'ERR_NOEXISTE_TIPODOC' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT 'ERR_INGRESAR_DOCUMENTO' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT 'ERR_EXISTE_USUARIO_TIPODOC_DOC' pMensaje;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT 'ERR_INGRESAR_NOMBRE' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT 'ERR_INGRESAR_APELLIDO' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT 'ERR_INVALIDO_ESTADOCIVIL' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT 'ERR_INGRESAR_TELEFONO' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT 'ERR_INGRESAR_EMAIL' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail) THEN
        SELECT 'ERR_EXISTE_EMAIL' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT 'ERR_INGRESAR_CANTIDADHIJOS' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT 'ERR_ESPACIO_USUARIO' pMensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario) THEN
		SELECT 'ERR_EXISTE_USUARIO' pMensaje;
		LEAVE SALIR;
	END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT 'ERR_INGRESAR_PASSWORD' pMensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT 'ERR_FECHANACIMIENTO_ANTERIOR' pMensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT 'ERR_FECHAINICIO_ANTERIOR' pMensaje;
        LEAVE SALIR;
    END IF;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_crear', pIdUsuarioAud, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Usuarios SELECT 0, pIdRol, pIdUbicacion, pIdTipoDocumento, pDocumento, pNombres, pApellidos, pEstadoCivil, pTelefono, pEmail, pCantidadHijos, pUsuario, pPassword ,pFechaNacimiento, pFechaInicio, NOW(), NULL,'A';
        SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        SELECT 'OK ', pMensaje;
    COMMIT;
END $$
DELIMITER ;

