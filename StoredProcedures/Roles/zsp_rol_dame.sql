DROP PROCEDURE IF EXISTS `zsp_rol_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_dame`(pIdRol tinyint)

BEGIN
    /*
        Procedimiento que sirve para instanciar un rol desde la base de datos.
    */
	SELECT	*
    FROM	Roles
    WHERE	IdRol = pIdRol;
END $$
DELIMITER ;

