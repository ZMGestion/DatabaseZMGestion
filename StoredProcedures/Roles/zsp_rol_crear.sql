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

