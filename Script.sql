DROP PROCEDURE IF EXISTS `zsp_rol_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_crear`(pToken varchar(256), pRol varchar(40), pDescripcion varchar(255))

SALIR: BEGIN
	/*
		Permite crear un rol controlando que el nombre no exista ya. 
		Devuelve OK + Id o el mensaje de error en Mensaje.
	*/
    DECLARE pIdUsuario smallint;
	DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'Error en la transacción. Contáctese con el administrador.' Mensaje;
        ROLLBACK;
	END;
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuario, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT pMensaje Mensaje;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
        SELECT 'Debe ingresar el nombre del rol.' Mensaje;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol) THEN
		SELECT 'El nombre del rol ya existe.' Mensaje;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;

        INSERT INTO Roles VALUES (DEFAULT, pRol, 'A', NULLIF(pDescripcion,''));
		SELECT 'OK' Mensaje;

	COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_borrar`(pToken varchar(256), pIdUsuario smallint, OUT pMensaje text)


SALIR: BEGIN
	/*
        Procedimiento que permite a un administrador borrar un usuario.
        Debe controlar que  no haya creado un presupuesto, una venta, una orden de produccion, un remito, un comprobante, que se le 
        haya asignado al menos una tarea o que haya revisado al menos una tarea. 
        Devuelve 'OK' o el error en pMensaje
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SHOW ERRORS;
		SELECT 'Error en la transacción interna. Contáctese con el administrador.' pMensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

	IF pIdUsuario = 1 THEN
		SELECT 'ERR_USUARIO_BORRAR_ADAM' pMensaje;
		LEAVE SALIR;
	END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Presupuestos p USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_PRESUPUESTO' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Ventas v USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_VENTA' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN OrdenesProduccion op USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_OP' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Comprobantes c USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_COMPROBANTE' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Remitos r USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_REMITO' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioFabricante WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_TAREA_F' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioRevisor WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_TAREA_R' pMensaje;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Usuarios WHERE IdUsuario = pIdUsuario;
    SELECT 'OK' pMensaje;
END $$
DELIMITER ;
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
		SELECT 'Error en la transacción. Contáctese con el administrador.' Mensaje;
        ROLLBACK;
	END;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT 'El rol seleccionado no existe' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT 'La ubicación seleccionada no existe' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT 'El tipo de documento seleccionado no existe' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT 'Debe ingresar el documento' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT 'Ya existe un usuario con el tipo y número de documento ingresado.' pMensaje;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT 'Debe ingresar el nombre.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT 'Debe ingresar el apellido.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT 'Debe seleccionar un estado civil valido.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT 'Debe ingresar el número de telefono.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT 'Debe ingresar el correo electronico.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail) THEN
        SELECT 'El correo electrnico ingresado ya esta en uso.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT 'Debe ingresar la cantidad de hijos.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT 'Espacio no permitido en usuario.' pMensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario) THEN
		SELECT 'El nombre del usuario ya existe.' pMensaje;
		LEAVE SALIR;
	END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT 'Debe especificar la contraseña.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT 'La fecha de nacimiento debe ser anterior a la fecha actual.' pMensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT 'La fecha de inicio de actividad debe ser anterior a la fecha actual.' pMensaje;
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

DROP PROCEDURE IF EXISTS `zsp_usuario_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_alta`(pToken varchar(256), pIdUsuario smallint, OUT pMensaje text)

SALIR: BEGIN
    /*
        Permite cambiar el estado del Usuario a 'Alta' siempre y cuando no esté en estado 'Alta' ya. Devuelve OK o el mensaje de error en Mensaje.
    */

    DECLARE pIdUsuario smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuarioAud smallint;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
		SELECT 'Error en la transacción. Contáctese con el administrador.' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_alta', pIdUsuarioAud, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF pIdUsuario IS NULL THEN
		SELECT 'Debe indicar un usuario.' pMensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
		SELECT 'El usuario ya está estado de "Alta"' pMensaje;
        LEAVE SALIR;
	END IF;

    UPDATE Usuarios SET Estado = 'A' WHERE IdUsuario = pIdUsuario;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_tiene_permiso`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_tiene_permiso`(pToken varchar(256), pProcedimiento varchar(255), out pIdUsuario smallint, out pMensaje text)


BEGIN
    /*
        Permite determinar si un usuario, a traves de su Token, tiene los permisos necesarios para ejecutar cierto procedimiento.
    */

	SELECT  IdUsuario
    INTO    pIdUsuario
    FROM    Usuarios u
    INNER JOIN  PermisosRol pr USING(IdRol)
    INNER JOIN  Permisos p USING(IdPermiso)
    WHERE   u.Token = pToken AND u.Estado = 'A'
            AND p.Procedimiento = pProcedimiento;
    
    IF pIdUsuario IS NULL THEN
        SET pMensaje = 'ERR_SIN_PERMISOS';
    ELSE
        SET pMensaje = 'OK';
    END IF;
END $$
DELIMITER ;

