DROP PROCEDURE IF EXISTS `zsp_roles_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_roles_listar`()

BEGIN
	/*
		Lista todos los roles existentes. Ordena por Rol. Devuelve la lista de roles en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pOut JSON;
    DECLARE pRespuesta TEXT;


    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
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
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;
