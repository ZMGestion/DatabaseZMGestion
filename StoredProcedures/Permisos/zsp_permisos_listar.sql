DROP PROCEDURE IF EXISTS `zsp_permisos_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_permisos_listar`()

BEGIN
	/*
		Lista todos los permisos existentes y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/

    DECLARE pRespuesta TEXT;

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
    ORDER BY Procedimiento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
