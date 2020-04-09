DROP PROCEDURE IF EXISTS `zsp_rol_listar_permisos`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_listar_permisos`(pIdRol tinyint)

BEGIN
	/*
		Lista todos los permisos existentes para un rol y devuelve un JSON en pSalida.
	*/

    GET DIAGNOSTICS CONDITION 1 @sqlstate = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
    SELECT JSON_OBJECT('Error', CONCAT("ERROR ", COALESCE(@errno, ''), " (", COALESCE(@sqlstate, ''), "): ", COALESCE(@text, ''))) pSalida;
    
    SELECT	
    CONCAT(
        '[',
        COALESCE(
            GROUP_CONCAT(
                JSON_OBJECT(
                    'IdPermiso', IdPermiso,
                    'Permiso', Permiso,
                    'Procedimiento', Procedimiento,
                    'Descripcion', Descripcion
                    )
            ),''),
        ']'
        )AS pSalida 
    FROM Permisos p 
    INNER JOIN PermisosRol pr USING(IdPermiso)
    WHERE pr.IdRol = pIdRol
    ORDER BY Procedimiento;

END $$
DELIMITER ;

