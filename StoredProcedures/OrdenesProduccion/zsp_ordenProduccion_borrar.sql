DROP PROCEDURE IF EXISTS zsp_ordenProduccion_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una orden de producción. Controla que se encuentre en Estado = 'E', en caso positivo borra sus lineas tambien.
        Devuelve NULL en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdOrdenProduccion int;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdOrdenProduccion = pIn ->> '$.OrdenesProduccion.IdOrdenProduccion';

    IF NOT EXISTS (SELECT IdOrdenProduccion FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion AND Estado = 'E') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM LineasProducto
        WHERE Tipo = 'O' AND IdReferencia = pIdOrdenProduccion;

        DELETE
        FROM OrdenesProduccion
        WHERE IdOrdenProduccion = pIdOrdenProduccion;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;