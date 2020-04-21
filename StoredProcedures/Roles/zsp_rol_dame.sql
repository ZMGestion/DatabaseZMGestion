DROP PROCEDURE IF EXISTS `zsp_rol_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_dame`(pIn JSON)

SALIR: BEGIN
    /*
        Procedimiento que sirve para instanciar un rol desde la base de datos.
    */
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

	SET pRespuesta = (SELECT 	CAST(CONCAT(
				COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
					)
				,'')
			)AS JSON) AS pOut
    FROM	Roles
    WHERE	IdRol = pIdRol);
    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) pOut;

END $$
DELIMITER ;

