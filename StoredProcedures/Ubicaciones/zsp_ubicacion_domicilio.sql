DROP PROCEDURE IF EXISTS `zsp_ubicacion_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar una ubicación.
        Debe controlar que no haya sido utilizado en un presupuesto, venta, linea de producto, remito y que no tenga un Usuario. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    
    
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;

    -- Ubicacion a borrar
    DECLARE pUbicaciones JSON;
    DECLARE pIdUbicacion tinyint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicaciones = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicaciones ->> "$.IdUbicacion";

    IF NOT EXISTS (SELECT Ubicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Presupuestos p USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_PRESUPUESTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Ventas v USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_VENTA' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Remitos r USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_REMITO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Ubicaciones u INNER JOIN Usuarios us USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_USUARIO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    
	DELETE FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion;
    SELECT f_generarRespuesta(NULL, NULL)pOut;
END $$
DELIMITER ;

