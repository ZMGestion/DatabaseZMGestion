DROP PROCEDURE IF EXISTS `zsp_rol_listar_permisos`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_listar_permisos`(pIdRol tinyint)

BEGIN
	/*
		Lista todos los permisos existentes para un rol
	*/
    
    SELECT	* 
    FROM Permisos p 
    INNER JOIN PermisosRol pr USING(IdPermiso)
    WHERE pr.IdRol = pIdRol
    ORDER BY Procedimiento;

END $$
DELIMITER ;

