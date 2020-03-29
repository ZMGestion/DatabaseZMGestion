DROP PROCEDURE IF EXISTS `zsp_roles_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_roles_listar`()

BEGIN
	/*
		Lista todos los roles existentes.
        Ordena por Rol.
	*/
    
    SELECT	* 
    FROM Roles r 
    ORDER BY Rol;

END $$
DELIMITER ;