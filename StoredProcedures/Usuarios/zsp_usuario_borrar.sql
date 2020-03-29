DROP PROCEDURE IF EXISTS `zsp_usuario_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_borrar`(pToken varchar(256), pIdUsuario smallint, OUT pMensaje text)


SALIR: BEGIN
	/*
        Procedimiento que permite a un administrador borrar un usuario.
        Debe controlar que  no haya creado un presupuesto, una venta, una orden de produccion, un remito, un comprobante, que se le 
        haya asignado al menos una tarea o que haya revisado al menos una tarea. 
        Devuelve 'OK' o el error en pMensaje
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SHOW ERRORS;
		SELECT 'ERR_TRANSACCION' pMensaje;
        ROLLBACK;
	END;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT pMensaje Mensaje;
        LEAVE SALIR;
    END IF;

	IF pIdUsuario = 1 THEN
		SELECT 'ERR_USUARIO_BORRAR_ADAM' pMensaje;
		LEAVE SALIR;
	END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Presupuestos p USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_PRESUPUESTO' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Ventas v USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_VENTA' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN OrdenesProduccion op USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_OP' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Comprobantes c USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_COMPROBANTE' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Remitos r USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_REMITO' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioFabricante WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_TAREA_F' pMensaje;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioRevisor WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT 'ERR_USUARIO_BORRAR_TAREA_R' pMensaje;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Usuarios WHERE IdUsuario = pIdUsuario;
    SELECT 'OK' pMensaje;
END $$
DELIMITER ;
