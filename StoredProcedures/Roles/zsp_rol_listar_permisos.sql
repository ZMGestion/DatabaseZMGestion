DROP PROCEDURE IF EXISTS `zsp_rol_listar_permisos`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_listar_permisos`(pIn JSON)

BEGIN
	/*
		Lista todos los permisos existentes para un rol y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta TEXT;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT('Permisos',
                    JSON_OBJECT(
                        'IdPermiso', IdPermiso, 
                        'Permiso', Permiso,
                        'Procedimiento', Procedimiento,
                        'Descripcion', Descripcion
                    )
                )
            )
        ,'')
	FROM Permisos p 
    INNER JOIN PermisosRol pr USING(IdPermiso)
    WHERE pr.IdRol = pIdRol
    ORDER BY Procedimiento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

