DROP PROCEDURE IF EXISTS `zsp_rol_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_crear`(pIn JSON)

SALIR: BEGIN
	/*
		Permite crear un rol controlando que el nombre no exista ya. 
		Devuelve 'OK'+Id o el mensaje de error en Mensaje.
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


	BEGIN
		GET DIAGNOSTICS CONDITION 1 @sqlstate = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
		SELECT f_generarRespuesta(CONCAT("ERROR ", COALESCE(@errno, ''), " (", COALESCE(@sqlstate, ''), "): ", COALESCE(@text, '')), NULL) pOut;
	END;

    
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
			CONCAT(COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
						)
					,'')
			)AS JSON)) FROM Roles WHERE Rol = pRol);
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) AS pOut;
	COMMIT;
END $$
DELIMITER ;
