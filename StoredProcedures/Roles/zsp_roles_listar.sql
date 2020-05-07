DROP PROCEDURE IF EXISTS `zsp_roles_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_roles_listar`()

BEGIN
	/*
		Lista todos los roles existentes.
        Ordena por Rol y devuelve un JSON en pSalida.
	*/
    DECLARE pOut JSON;
    DECLARE pRespuesta TEXT;

    SET SESSION  group_concat_max_len = 1024*1024*1024;

    SET pRespuesta = (SELECT 
        COALESCE(
            GROUP_CONCAT(
                JSON_OBJECT("Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol, 
                        'Rol', Rol,
                        'FechaAlta', FechaAlta,
                        'Descripcion', Descripcion
                    )
                )
            ),'')
	FROM Roles
    ORDER BY Rol);
    SELECT f_generarRespuestaLista(NULL, pRespuesta) pOut;
END $$
DELIMITER ;

