DROP PROCEDURE IF EXISTS `zsp_roles_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_roles_listar`()

BEGIN
	/*
		Lista todos los roles existentes.
        Ordena por Rol y devuelve un JSON en pSalida.
	*/
    
    SELECT 
    CAST(CONCAT(
        '[',
        COALESCE(
            GROUP_CONCAT(
                JSON_OBJECT(
        	        'IdRol', IdRol, 
			        'Rol', Rol,
                    'FechaAlta', FechaAlta,
                    'Descripcion', Descripcion
                    )
            ),''),
        ']'
        )AS JSON) AS pSalida
	FROM Roles
    ORDER BY Rol;
END $$
DELIMITER ;

