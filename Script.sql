DROP FUNCTION IF EXISTS `f_generarRespuesta`;
DELIMITER $$
CREATE FUNCTION `f_generarRespuesta`(pCodigoError varchar(255), pRespuesta JSON) RETURNS JSON
    DETERMINISTIC
BEGIN
    RETURN JSON_OBJECT("error", pCodigoError, "respuesta", pRespuesta);
END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_split`;
DELIMITER $$
CREATE FUNCTION `f_split`(pCadena longtext, pDelimitador varchar(10), pIndice int) RETURNS text CHARSET utf8
    DETERMINISTIC
BEGIN
	
	RETURN	REPLACE(
				SUBSTR(
					SUBSTRING_INDEX(pCadena, pDelimitador, pIndice),
					CHAR_LENGTH(SUBSTRING_INDEX(pCadena, pDelimitador, pIndice -1)) + 1
				),
				pDelimitador, ''
			);
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_rol_asignar_permisos`;
DELIMITER $$
CREATE  PROCEDURE `zsp_rol_asignar_permisos`(pIn JSON)

SALIR: BEGIN
	/*
		Dado el rol y una cadena formada por la lista de los IdPermisos separados por comas, asigna los permisos seleccionados como dados y quita los no dados.
		Cambia el token de los usuarios del rol así deban reiniciar sesión y retomar permisos.
		Devuelve null en 'respuesta' o el codigo de error en 'error'.
	*/	
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pNumero varchar(11);
	DECLARE pMensaje text;
	DECLARE pRoles, pPermisos, pUsuariosEjecuta JSON;
	DECLARE pIdRol int;
	DECLARE pToken varchar(256);

	/*Para el While*/
	DECLARE i INT DEFAULT 0;
	DECLARE pPermiso JSON;
	DECLARE pIdPermiso smallint;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SHOW ERRORS;
		SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> '$.Roles';
	SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
	SET pPermisos = pIn ->> '$.Permisos';

    SET pIdRol = pRoles ->> '$.IdRol';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
	
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_asignar_permisos', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje != 'OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol)THEN
		SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
		DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
        CREATE TEMPORARY TABLE tmp_permisosrol ENGINE = MEMORY AS
        SELECT * FROM PermisosRol WHERE IdRol = pIdRol;
		
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;

		WHILE i < JSON_LENGTH(pPermisos) DO
			SELECT JSON_EXTRACT(pPermisos,CONCAT('$[',i,']')) INTO pPermiso;
			SET pIdPermiso = pPermiso ->> '$.IdPermiso';
			IF NOT EXISTS(SELECT IdPermiso FROM Permisos WHERE IdPermiso = pIdPermiso)THEN
				SELECT f_generarRespuesta('ERROR_NOEXISTE_PERMISO_LISTA', NULL) pOut;
                ROLLBACK;
                LEAVE SALIR;
            END IF;
            INSERT INTO PermisosRol VALUES(pIdPermiso, pIdRol);
			SELECT i + 1 INTO i;
		END WHILE;

        IF EXISTS(SELECT IdPermiso
			FROM
			(SELECT IdPermiso
			FROM tmp_permisosrol
			UNION ALL
			SELECT IdPermiso
			FROM PermisosRol
			WHERE IdRol = pIdRol) p
			GROUP BY IdPermiso
			HAVING COUNT(IdPermiso) = 1) THEN /*Si existen cambios, es decir existe un nuevo tipo de permiso respecto a la tabla original (tmp_permisosrol) => Reseteamos token.*/
                UPDATE Usuarios SET Token = md5(CONCAT(CONVERT(IdUsuario,char(10)),UNIX_TIMESTAMP())) WHERE IdRol = pIdRol;
		END IF;
		SELECT f_generarRespuesta(NULL, NULL) pOut;
        DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
	COMMIT;    
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_borrar`(pIn JSON)

SALIR: BEGIN
    /*
        Permite borrar un rol controlando que no exista un usuario asociado.
        Devuelve null en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pRoles JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdRol int;
    DECLARE pToken varchar(256);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pIdRol IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INDICAR_ROL', NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
	IF EXISTS(SELECT IdRol FROM Usuarios WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_ROL_USUARIO', NULL) pOut;
		LEAVE SALIR;
	END IF;
	
    START TRANSACTION;
	
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;
        DELETE FROM Roles WHERE IdRol = pIdRol;
        SELECT f_generarRespuesta(NULL, NULL) pOut;

	COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_crear`(pIn JSON)

SALIR: BEGIN
	/*
		Permite crear un rol controlando que el nombre no exista ya. 
		Devuelve el rol creado en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pRoles JSON;
	DECLARE pUsuarioEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
	DECLARE pIdRol tinyint;
	DECLARE pToken varchar(256);
	DECLARE pRol varchar(40);
	DECLARE pDescripcion varchar(255);
	DECLARE pRespuesta JSON;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> "$.Roles";
	SET pUsuarioEjecuta = pIn ->> "$.UsuariosEjecuta";
	SET pToken = pUsuarioEjecuta ->> "$.Token";
	SET pRol = pRoles ->> "$.Rol";
	SET pDescripcion = pRoles ->> "$.Descripcion";
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBREROL', NULL) pOut;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_NOMBREROL', NULL) pOut;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;
		
        INSERT INTO Roles VALUES (DEFAULT, pRol, NOW(), NULLIF(pDescripcion,''));
		SET pIdRol = (SELECT IdRol FROM Roles WHERE Rol = pRol);
		SET pRespuesta = (SELECT (CAST(
			COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
						)
					,'')
			AS JSON)) FROM Roles WHERE Rol = pRol);
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) AS pOut;
	COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_rol_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_dame`(pIn JSON)

SALIR: BEGIN
    /*
        Procedimiento que sirve para instanciar un rol desde la base de datos. Devuelve el objeto en 'respuesta' o un error en 'error'.
    */
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

	SET pRespuesta = (
        SELECT CAST(
				COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
					)
				,'') AS JSON)
        FROM	Roles
        WHERE	IdRol = pIdRol
    );

    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_listar_permisos`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_listar_permisos`(pIn JSON)

BEGIN
	/*
		Lista todos los permisos existentes para un rol y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta TEXT;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT('Permisos',
                    JSON_OBJECT(
                        'IdPermiso', IdPermiso, 
                        'Permiso', Permiso,
                        'Procedimiento', Procedimiento,
                        'Descripcion', Descripcion
                    )
                )
            )
        ,'')
	FROM Permisos p 
    INNER JOIN PermisosRol pr USING(IdPermiso)
    WHERE pr.IdRol = pIdRol
    ORDER BY Procedimiento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_modificar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_modificar`(pIn JSON)

SALIR: BEGIN
	/*
		Permite modificar un rol controlando que el nombre no exista ya. 
		Devuelve el rol modifica en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pRoles JSON;
	DECLARE pUsuarioEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
	DECLARE pIdRol tinyint;
	DECLARE pToken varchar(256);
	DECLARE pRol varchar(40);
	DECLARE pDescripcion varchar(255);
	DECLARE pRespuesta JSON;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> "$.Roles";
	SET pUsuarioEjecuta = pIn ->> "$.UsuariosEjecuta";
	SET pToken = pUsuarioEjecuta ->> "$.Token";
    SET pIdRol = pRoles ->> "$.IdRol";
	SET pRol = pRoles ->> "$.Rol";
	SET pDescripcion = pRoles ->> "$.Descripcion";
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBREROL', NULL) pOut;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol AND IdRol != pIdRol) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_NOMBREROL', NULL) pOut;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;
		
        UPDATE Roles 
        SET Rol = pRol,
            Descripcion = NULLIF(pDescripcion,'')
        WHERE IdRol = pIdRol;
        
		SET pRespuesta = (SELECT (CAST(
			COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
						)
					,'')
			AS JSON)) FROM Roles WHERE IdRol = pIdRol);
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) AS pOut;
	COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_roles_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_roles_listar`()

BEGIN
	/*
		Lista todos los roles existentes. Ordena por Rol. Devuelve la lista de roles en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pOut JSON;
    DECLARE pRespuesta TEXT;


    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT("Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol, 
                        'Rol', Rol,
                        'FechaAlta', FechaAlta,
                        'Descripcion', Descripcion
                    )
                )
            ),'')
	FROM Roles
    ORDER BY Rol);
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_usuario_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_borrar`(pToken varchar(256), pIdUsuario smallint)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar un usuario.
        Debe controlar que no haya creado un presupuesto, venta, orden de produccion, remito, comprobante, o que no se le 
        haya asignado o haya revisado alguna tarea. 
        Devuelve 'OK' o el error en Mensaje.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SHOW ERRORS;
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

	IF pIdUsuario = 1 THEN
		SELECT 'ERROR_BORRAR_USUARIO_ADAM' Mensaje;
		LEAVE SALIR;
	END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Presupuestos p USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERROR_BORRAR_USUARIO_PRESUPUESTO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Ventas v USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERROR_BORRAR_USUARIO_VENTA' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN OrdenesProduccion op USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERROR_BORRAR_USUARIO_OP' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Comprobantes c USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERROR_BORRAR_USUARIO_COMPROBANTE' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Remitos r USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERROR_BORRAR_USUARIO_REMITO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioFabricante WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERROR_BORRAR_USUARIO_TAREA_F' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioRevisor WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERROR_BORRAR_USUARIO_TAREA_R' Mensaje;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Usuarios WHERE IdUsuario = pIdUsuario;
    SELECT 'OK' Mensaje;
END $$
DELIMITER ;

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
        Devuelve un json con el usuario creado en respuesta o el codigo de error en error.
    */
    DECLARE pIdUsuario smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT 'ERROR_NOEXISTE_ROL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT 'ERROR_NOEXISTE_UBICACION' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT 'ERROR_NOEXISTE_TIPODOC' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT 'ERROR_INGRESAR_DOCUMENTO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT 'ERROR_EXISTE_USUARIO_TIPODOC_DOC' Mensaje;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT 'ERROR_INGRESAR_NOMBRE' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT 'ERROR_INGRESAR_APELLIDO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT 'ERROR_INVALIDO_ESTADOCIVIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT 'ERROR_INGRESAR_TELEFONO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT 'ERROR_INGRESAR_EMAIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail) THEN
        SELECT 'ERROR_EXISTE_EMAIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT 'ERROR_INGRESAR_CANTIDADHIJOS' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT 'ERROR_ESPACIO_USUARIO' Mensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario) THEN
		SELECT 'ERROR_EXISTE_USUARIO' Mensaje;
		LEAVE SALIR;
	END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT 'ERROR_INGRESAR_PASSWORD' Mensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT 'ERROR_FECHANACIMIENTO_ANTERIOR' Mensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT 'ERROR_FECHAINICIO_ANTERIOR' Mensaje;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Usuarios SELECT 0, pIdRol, pIdUbicacion, pIdTipoDocumento, pDocumento, pNombres, pApellidos, pEstadoCivil, pTelefono, pEmail, pCantidadHijos, pUsuario, pPassword, NULL, NULL, 0 ,pFechaNacimiento, pFechaInicio, NOW(), NULL,'A';
        SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        SELECT 'OK ' Mensaje;
    COMMIT;
END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame`(pIdUsuario smallint)

BEGIN
    /*
        Procedimiento que sirve para instanciar un usuario por id desde la base de datos.
    */
	SELECT	*
    FROM	Usuarios
    WHERE	IdUsuario = pIdUsuario;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dame_por_token`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame_por_token`(pToken varchar(256))

BEGIN

    /*
        Procedimiento que sirve para instanciar un usuario por token desde la base de datos.
    */	
	SELECT	*
    FROM	Usuarios
    WHERE	Token = pToken;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_alta`(pToken varchar(256), pIdUsuario smallint)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Usuario a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve OK o el mensaje de error en Mensaje.
	*/
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF pIdUsuario IS NULL THEN
		SELECT 'ERROR_INGRESAR_USUARIO' Mensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'B') THEN
		SELECT 'ERROR_USUARIO_ESTA_ALTA' Mensaje;
        LEAVE SALIR;
	END IF;

    UPDATE Usuarios
    SET Estado = 'A',
        Intentos = 0
    WHERE IdUsuario = pIdUsuario;
    SELECT'OK' Mensaje;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dar_baja`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_baja`(pToken varchar(256), pIdUsuario smallint)

SALIR: BEGIN
    /*
        Permite cambiar el estado del Usuario a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve OK o el mensaje de error en Mensaje.
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
		SELECT 'ERROR_INGRESAR_USUARIO' pMensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS (SELECT IdUsuario From Usuarios WHERE IdUsuario = pIdUsuario) THEN
		SELECT 'ERROR_NOEXISTE_USUARIO' pMensaje;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
		SELECT 'ERROR_USUARIO_ESTA_BAJA' pMensaje;
        LEAVE SALIR;
	END IF;
		

	UPDATE Usuarios SET Estado = 'B' WHERE IdUsuario = pIdUsuario;
    SELECT'OK', Mensaje;

END $$
DELIMITER ;

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

    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT 'ERROR_NOEXISTE_USUARIO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT 'ERROR_NOEXISTE_ROL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT 'ERROR_NOEXISTE_UBICACION' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT 'ERROR_NOEXISTE_TIPODOC' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT 'ERROR_INGRESAR_DOCUMENTO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento AND IdUsuario != pIdUsuario) THEN
        SELECT 'ERROR_EXISTE_USUARIO_TIPODOC_DOC' Mensaje;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT 'ERROR_INGRESAR_NOMBRE' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT 'ERROR_INGRESAR_APELLIDO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT 'ERROR_INVALIDO_ESTADOCIVIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT 'ERROR_INGRESAR_TELEFONO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT 'ERROR_INGRESAR_EMAIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail AND IdUsuario != pIdUsuario) THEN
        SELECT 'ERROR_EXISTE_EMAIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT 'ERROR_INGRESAR_CANTIDADHIJOS' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT 'ERROR_ESPACIO_USUARIO' Mensaje;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario AND IdUsuario != pIdUsuario) THEN
		SELECT 'ERROR_EXISTE_USUARIO' Mensaje;
		LEAVE SALIR;
	END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT 'ERROR_FECHANACIMIENTO_ANTERIOR' Mensaje;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT 'ERROR_FECHAINICIO_ANTERIOR' Mensaje;
        LEAVE SALIR;
    END IF;

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
    SELECT 'OK ', pMensaje;

END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_modificar_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar_pass`(pToken varchar(256),pPasswordActual varchar(255), pPasswordNueva varchar(255))

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar su contraseña comprobando que la contraseña actual ingresada sea correcta.
        Devuelve 'OK' o el mensaje de error en Mensaje
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar_pass', pIdUsuarioEjecuta, pMensaje);

    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuarioEjecuta AND Password = pPasswordActual) THEN
        SELECT 'ERROR_PASSWORD_INCORRECTA' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pPasswordActual = pPasswordNueva) THEN
        SELECT 'ERROR_PASSOWRDS_IGUALES' Mensaje;
        LEAVE SALIR;
    END IF;


    IF(pPasswordNueva IS NULL OR pPasswordNueva = '') THEN
        SELECT 'ERROR_INGRESAR_PASSWORD' Mensaje;
        LEAVE SALIR;
    END IF;
    
    UPDATE  Usuarios 
    SET Password = pPasswordNueva
    WHERE IdUsuario = pIdUsuarioEjecuta;
    SELECT 'OK ' Mensaje;
END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_restablecer_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_restablecer_pass`(pToken varchar(256), pIdUsuario smallint ,pPassword varchar(255))

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario restablecer la contraseña de otro usuario.
        Devuelve 'OK' o el mensaje de error en Mensaje
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_restablecer_pass', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT 'ERROR_NOEXISTE_USUARIO' Mensaje;
        LEAVE SALIR;
    END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT 'ERROR_INGRESAR_PASSWORD' Mensaje;
        LEAVE SALIR;
    END IF;

    UPDATE  Usuarios 
    SET Password = pPassword
    WHERE IdUsuario = pIdUsuario;
    SELECT 'OK ' Mensaje;

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
        SET pMensaje = 'ERROR_SIN_PERMISOS';
    ELSE
        SET pMensaje = 'OK';
    END IF;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuarios_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuarios_buscar`(
    pToken varchar(256),
    pNombresApellidos varchar(80),
    pUsuario varchar(40),
    pEmail varchar(120),
    pDocumento varchar(15),
    pTelefono varchar(15),
    pEstadoCivil char(1),
    pTieneHijos char(1),
    pEstado char(1),
    pIdRol tinyint,
    pIdUbicacion tinyint)
SALIR: BEGIN
	/*
		Permite buscar los usuarios por una cadena, o bien, por sus nombres y apellidos, nombre de usuario, email, documento, telefono,
        estado civil (C:Casado - S:Soltero - D:Divorciado - T:Todos), estado (A:Activo - B:Baja - T:Todos), rol (0:Todos los roles),
        ubicacion en la que trabaja (0:Todas las ubicaciones) y si tiene hijos o no (S:Si - N:No - T:Todos).
	*/

    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuarios_buscar', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT pMensaje Mensaje;
		LEAVE SALIR;
	END IF;

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pEstadoCivil IS NULL OR pEstadoCivil = '' OR pEstadoCivil NOT IN ('C','S','D') THEN
		SET pEstado = 'T';
	END IF;

    IF pTieneHijos IS NULL OR pTieneHijos = '' OR pTieneHijos NOT IN ('S','N') THEN
		SET pTieneHijos = 'T';
	END IF;
    
    SET pNombresApellidos = COALESCE(pNombresApellidos,'');
    SET pUsuario = COALESCE(pUsuario,'');
    SET pEmail = COALESCE(pEmail,'');
    SET pDocumento = COALESCE(pDocumento,'');
    SET pTelefono = COALESCE(pTelefono,'');
    SET pIdRol = COALESCE(pIdRol,0);
    SET pIdUbicacion = COALESCE(pIdUbicacion,0);
    
	SELECT		u.*, Rol, Ubicacion,
				IF(u.Estado = 'B','S','N') OpcionDarAlta, IF(u.Estado = 'A','S','N') OpcionDarBaja
	FROM		Usuarios u
	INNER JOIN	Roles r USING (IdRol)
    INNER JOIN	Ubicaciones USING (IdUbicacion)
	WHERE		IdRol IS NOT NULL AND 
				(
                    CONCAT(Apellidos,',',Nombres) LIKE CONCAT('%', pNombresApellidos, '%') AND
                    Usuario LIKE CONCAT(pUsuario, '%') AND
                    Email LIKE CONCAT(pEmail, '%') AND
                    Documento LIKE CONCAT(pDocumento, '%') AND
                    Telefono LIKE CONCAT(pTelefono, '%')
				) AND 
                (IdRol = pIdRol OR pIdRol = 0) AND
                (IdUbicacion = pIdUbicacion OR pIdUbicacion = 0) AND
                (u.Estado = pEstado OR pEstado = 'T') AND
                (u.EstadoCivil = pEstadoCivil OR pEstadoCivil = 'T') AND
                IF(pTieneHijos = 'S', u.CantidadHijos > 0, IF(pTieneHijos = 'N', u.CantidadHijos = 0, pTieneHijos = 'T'))
	ORDER BY	CONCAT(Apellidos, ' ', Nombres), Usuario;
END $$
DELIMITER ;

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
		SELECT 'ERROR_INGRESAR_USUARIO' Mensaje;
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

DROP PROCEDURE IF EXISTS `zsp_sesion_iniciar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_iniciar`(pIn JSON)

SALIR: BEGIN
	/*
		Procedimiento que permite a un usuario iniciar sesion en ZMGestion.
        Devuelve el usuario que ha iniciado sesion en pOut o el codigo de error en caso de error.
	*/
    DECLARE pIdUsuario smallint;
    DECLARE pTIEMPOINTENTOS, pMAXINTPASS, pIntentos int;
    DECLARE pFechaUltIntento datetime;
    DECLARE pUsuarios JSON;
    DECLARE pPass VARCHAR(255);
    DECLARE pUsuario VARCHAR(40);
    DECLARE pEmail VARCHAR(120);
    DECLARE pToken VARCHAR(120);

    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pToken = pUsuarios ->> '$.Token'; 

    IF pToken IS NULL OR pToken = '' THEN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pUsuario = pUsuarios ->> '$.Usuario';
    SET pEmail = pUsuarios ->> '$.Email';
    SET pPass = pUsuarios ->> '$.Password'; 


    SET pTIEMPOINTENTOS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='TIEMPOINTENTOS');
    SET pMAXINTPASS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='MAXINTPASS');

    
    IF (pUsuario IS NULL OR pUsuario = '') AND (pEmail IS NULL OR pEmail = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Control porque no se puede enviar usuario y correo electronico. Debe ser uno de los dos
    IF (pUsuario IS NOT NULL AND pUsuario <> '') AND (pEmail IS NOT NULL AND pEmail <> '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pEmail IS NOT NULL AND pEmail <> '' THEN
        IF(NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail)) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
		ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        END IF;
    ELSE
        IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
        ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario);
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
        SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pIntentos = (SELECT Intentos FROM Usuarios WHERE IdUsuario = pIdUsuario);
        SET pFechaUltIntento = (SELECT FechaUltIntento FROM Usuarios WHERE IdUsuario = pIdUsuario);

        IF DATE_ADD(pFechaUltIntento, INTERVAL pTIEMPOINTENTOS MINUTE) < NOW() THEN
            SET pIntentos = 0;
            SELECT pTIEMPOINTENTOS Mensaje;
        END IF;

        IF NOT EXISTS (SELECT Estado FROM Usuarios WHERE `Password` = pPass AND ESTADO = 'A' AND IdUsuario = pIdUsuario) THEN
            IF (pIntentos + 1) >= pMAXINTPASS THEN
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW(),
                    Estado = 'B'
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
            ELSE
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW()
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            END IF;
            LEAVE SALIR;
        ELSE
            UPDATE Usuarios
            SET Token = pToken,
                FechaUltIntento = NOW(),
                Intentos = 0
            WHERE IdUsuario = pIdUsuario;

            SET pUsuarios = (
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
                                'Token', Token,
                                'FechaNacimiento', FechaNacimiento,
                                'FechaInicio', FechaInicio,
                                'FechaAlta', FechaAlta,
                                'Estado', Estado
                            )
                        ,'') AS JSON)
                FROM	Usuarios
                WHERE	IdUsuario = pIdUsuario
            );

            SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pUsuarios)) pOut; 
        END IF;        
    COMMIT;

END $$
DELIMITER ;