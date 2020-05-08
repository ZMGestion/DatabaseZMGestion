DROP PROCEDURE IF EXISTS `zsp_rol_listar_permisos`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_listar_permisos`(pIn JSON)

BEGIN
	/*
		Lista todos los permisos existentes para un rol y devuelve un JSON en pSalida.
	*/
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta TEXT;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET SESSION  group_concat_max_len = 1024*1024*1024;
    SET pRespuesta = (SELECT 
        COALESCE(
            GROUP_CONCAT(
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

    SELECT f_generarRespuestaLista(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

