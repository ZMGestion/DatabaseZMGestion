DROP PROCEDURE IF EXISTS `zsp_usuario_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar`(pToken varchar(256), pIdUsuario smallint, pIdRol tinyint, pIdUbicacion tinyint,pIdTipoDocumento tinyint, pDocumento varchar(15), pNombres varchar(60), pApellidos varchar(60), pEstadoCivil char(1), pTelefono varchar(15),
                                        pEmail varchar(120), pCantidadHijos tinyint, pUsuario varchar(40), pFechaNacimiento date, pFechaInicio date)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUsario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsario)) THEN
        SELECT 'ERR_NOEXISTE_USUARIO' pMensaje;
        LEAVE SALIR;
    END IF;

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

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE TipoDocumento = pIdTipoDocumento AND Documento = pDocumento AND IdUsuario != pIdUsuario) THEN
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

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail AND IdUsuario != pIdUsuario) THEN
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

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario AND IdUsuario != pIdUsuario) THEN
		SELECT 'ERR_EXISTE_USUARIO' pMensaje;
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

    IF(pFechaAlta IS NULL OR pFechaAlta > NOW()) THEN
        SELECT 'ERR_FECHA_ANTERIOR' pMensaje;
        LEAVE SALIR;
    END IF;

    UPDATE  Usuarios 
    SET IdUsuario = pIdUsario,
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
        Usuarios = pUsuario,
        FechaNacimiento = pFechaNacimiento,
        FechaInicio = pFechaInicio
    WHERE IdUsuario = pIdUsuario;
    SELECT 'OK ', pMensaje;

END $$
DELIMITER ;


