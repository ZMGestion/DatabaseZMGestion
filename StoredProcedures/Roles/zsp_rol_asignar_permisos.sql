DROP PROCEDURE IF EXISTS `zsp_rol_asignar_permisos`;
DELIMITER $$
CREATE  PROCEDURE `zsp_rol_asignar_permisos`(pToken varchar(256), pIdRol tinyint, pPermisos varchar(5000))

SALIR: BEGIN
	/*
		Dado el rol y una cadena formada por la lista de los IdPermisos separados por comas, asigna los permisos seleccionados como dados y quita los no dados.
		Cambia el token de los usuarios del rol así deban reiniciar sesión y retomar permisos.
		Devuelve OK o el mensaje de error en Mensaje.
	*/	
    DECLARE pIndice, pIdPermiso, pIdUsuarioEjecuta smallint;
    DECLARE pNumero varchar(11);
	DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SHOW ERRORS;
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;
	
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_asignar_permisos', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje != 'OK' THEN
		SELECT pMensaje Mensaje;
		LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol)THEN
		SELECT 'ERR_NOEXISTE_ROL' Mensaje;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
		DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
        CREATE TEMPORARY TABLE tmp_permisosrol ENGINE = MEMORY AS
        SELECT * FROM PermisosRol WHERE IdRol = pIdRol;
		
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;
        SET pIndice = 0;
        
        loop_1: LOOP
			SET pIndice = pIndice + 1;
            SET pNumero = f_split(pPermisos, ',', pIndice);
            IF pNumero = '' THEN
				LEAVE loop_1;
			END IF;
            SET pIdPermiso = pNumero;
            IF NOT EXISTS(SELECT IdPermiso FROM Permisos WHERE IdPermiso = pIdPermiso)THEN
				SELECT 'ERR_NOEXISTE_PERMISO_LISTA' Mensaje;
                ROLLBACK;
                LEAVE SALIR;
            END IF;
            INSERT INTO PermisosRol VALUES(pIdPermiso, pIdRol);
		END LOOP loop_1;

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
        SELECT 'OK' Mensaje;
        DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
	COMMIT;    
END $$
DELIMITER ;

