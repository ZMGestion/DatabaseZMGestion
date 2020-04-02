DROP PROCEDURE IF EXISTS `zsp_usuario_dame_por_token`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame_por_token`(pToken varchar(256))

BEGIN

    /*
        Procedimiento que sirve para instanciar un usuario por token desde la base de datos.
    */	
	SELECT	*
    FROM	Usuarios
    WHERE	Token = pToken;
END $$
DELIMITER ;

