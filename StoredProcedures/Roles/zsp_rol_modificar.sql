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
