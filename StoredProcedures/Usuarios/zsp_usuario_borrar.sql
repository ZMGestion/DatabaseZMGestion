DROP PROCEDURE IF EXISTS `zsp_usuario_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar un usuario.
        Debe controlar que no haya creado un presupuesto, venta, orden de produccion, remito, comprobante, o que no se le 
        haya asignado o haya revisado alguna tarea. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pUsuarios JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";

	IF pIdUsuario = 1 THEN
		SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_ADAM', NULL)pOut;
		LEAVE SALIR;
	END IF;

    IF NOT EXISTS (SELECT Usuario FROM Usuarios WHERE IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Presupuestos p USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_PRESUPUESTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Ventas v USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_VENTA' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN OrdenesProduccion op USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_OP' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Comprobantes c USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_COMPROBANTE' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Remitos r USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_REMITO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioFabricante WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_TAREA_F' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioRevisor WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_TAREA_R' , NULL)pOut;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Usuarios WHERE IdUsuario = pIdUsuario;
    SELECT f_generarRespuesta(NULL, NULL)pOut;
END $$
DELIMITER ;

