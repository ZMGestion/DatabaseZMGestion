DROP PROCEDURE IF EXISTS zsp_ordenProduccion_pasarAPendiente;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_pasarAPendiente(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite pasar a pendiente una determinada orden de producción.
        Devuelve la orden de producción en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE pIdOrdenProduccion INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pToken = pIn->>"$.UsuariosEjecuta.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_pasarAPendiente', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdOrdenProduccion = pIn->>"$.OrdenesProduccion.IdOrdenProduccion";

    IF NOT EXISTS(
        SELECT
            lop.IdLineaProducto
        FROM OrdenesProduccion op
        INNER JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdReferencia = op.IdOrdenProduccion)
        WHERE 
            op.IdOrdenProduccion = pIdOrdenProduccion
            AND op.Estado = 'E'
    ) THEN
        SELECT f_generarRespuesta("ERROR_ORDEN_PRODUCCION_SIN_LINEAS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdVenta FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion) IS NOT NULL THEN
        /*
            Controlamos que todas las lineas ingresadas se correspondan a una linea de venta pendiente cuyos productos sean producibles/fabricables
        */ 
        IF EXISTS(
            SELECT
                lv.IdLineaProducto,
                COUNT(lr.Estado) CantidadLineasRemito,
                COUNT(lr.Estado='C') CantidadCanceladas
            FROM OrdenesProduccion op
            INNER JOIN LineasProducto lv ON (lv.Tipo = 'V' AND lv.IdReferencia = op.IdVenta)
            INNER JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdReferencia = op.IdOrdenProduccion AND lop.IdLineaProductoPadre = lv.IdLineaProducto)
            INNER JOIN ProductosFinales pf ON (pf.IdProductoFinal = lv.IdProductoFinal)
            INNER JOIN Productos p ON (p.IdProducto = pf.IdProducto)
            LEFT JOIN LineasProducto lr ON (lr.Tipo = 'R' AND lr.IdLineaProductoPadre = lv.IdLineaProducto)
            WHERE 
                op.IdOrdenProduccion = pIdOrdenProduccion
                AND (lv.Estado != 'P' OR p.IdTipoProducto != 'P')
            GROUP BY lv.IdLineaProducto
            HAVING CantidadLineasRemito != CantidadCanceladas
        ) THEN
            SELECT f_generarRespuesta("ERROR_INVALIDO_LINEA_ORDEN_PRODUCCION", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        /*
            Controlamos que todas las lineas ingresadas sean producibles/fabricables
        */
        IF EXISTS(
            SELECT
                lop.IdLineaProducto
            FROM OrdenesProduccion op
            INNER JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdReferencia = op.IdOrdenProduccion)
            INNER JOIN ProductosFinales pf ON (pf.IdProductoFinal = lop.IdProductoFinal)
            INNER JOIN Productos p ON (p.IdProducto = pf.IdProducto)
            LEFT JOIN LineasProducto lp ON (lp.IdLineaProducto = lop.IdLineaProducto)
            WHERE 
                op.IdOrdenProduccion = pIdOrdenProduccion
                AND (p.IdTipoProducto != 'P')
        ) THEN
            SELECT f_generarRespuesta("ERROR_INVALIDO_LINEA_ORDEN_PRODUCCION", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    START TRANSACTION;
        UPDATE OrdenesProduccion
        SET Estado = 'C'
        WHERE IdOrdenProduccion = pIdOrdenProduccion;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', IdOrdenProduccion,
                        'IdUsuario', IdUsuario,
                        'IdVenta', IdVenta,
                        'FechaAlta', FechaAlta,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM    OrdenesProduccion
            WHERE   IdOrdenProduccion = pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;