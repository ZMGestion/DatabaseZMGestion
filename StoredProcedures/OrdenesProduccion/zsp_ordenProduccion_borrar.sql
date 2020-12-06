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

    DECLARE pIdRemito INT;

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

    IF NOT EXISTS (SELECT IdOrdenProduccion FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion AND f_dameEstadoOrdenProduccion(IdOrdenProduccion) IN('E', 'C')) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Obtenemos el IdRemito de "Transformación entrada" (X) asociado, en caso de que se esté fabricando utilizando esqueletos
    SELECT DISTINCT r.IdRemito INTO pIdRemito 
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdReferencia = pIdOrdenProduccion 
            AND lop.Tipo = 'O';

    START TRANSACTION;
        IF COALESCE(pIdRemito, 0) != 0 THEN
            -- Eliminamos todas las lineas de remito del remito
            DELETE FROM LineasProducto
            WHERE 
                IdReferencia = pIdRemito
                AND Tipo = 'R';

            -- Eliminamos el remito
            DELETE FROM Remitos
            WHERE IdRemito = pIdRemito;
        END IF;

        DELETE
        FROM OrdenesProduccion
        WHERE IdOrdenProduccion = pIdOrdenProduccion;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;