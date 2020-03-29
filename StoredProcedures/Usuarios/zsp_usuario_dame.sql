DROP PROCEDURE IF EXISTS `zsp_usuario_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame`(pIdUsuario smallint)

BEGIN
    /*
        Procedimiento que sirve para instanciar un usuario por id desde la base de datos.
    */
	SELECT	*
    FROM	Usuarios
    WHERE	IdUsuario = pIdUsuario;
END $$
DELIMITER ;

