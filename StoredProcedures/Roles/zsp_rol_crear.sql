DROP PROCEDURE IF EXISTS `zsp_rol_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_crear`(pToken varchar(256), pRol varchar(40), pDescripcion varchar(255))

SALIR: BEGIN
	/*
		Permite crear un rol controlando que el nombre no exista ya. 
		Devuelve 'OK'+Id o el mensaje de error en Mensaje.
	*/
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
	DECLARE pIdRol smallint;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT pMensaje Mensaje;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
        SELECT 'ERR_INGRESAR_NOMBREROL' Mensaje;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol) THEN
		SELECT 'ERR_EXISTE_NOMBREROL' Mensaje;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;
		
        INSERT INTO Roles VALUES (DEFAULT, pRol, 'A', NULLIF(pDescripcion,''));
		SET pIdRol = (SELECT IdRol FROM Roles WHERE Rol = pRol);
		SELECT CONCAT('OK',pIdRol) Mensaje;

	COMMIT;
END $$
DELIMITER ;

