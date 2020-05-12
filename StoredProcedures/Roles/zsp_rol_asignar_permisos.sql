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

