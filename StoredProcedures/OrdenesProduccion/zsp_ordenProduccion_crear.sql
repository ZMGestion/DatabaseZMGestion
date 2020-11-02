DROP PROCEDURE IF EXISTS zsp_ordenProduccion_crear;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una nueva orden de producción en estado En Creación.
        Si se le pasa una venta se controla que la misma contenga al menos 
        una linea de venta pendiente y que contenga un producto fabricable/producible
        Devuelve la orden de producción en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE pIdVenta INT;
    DECLARE pObservaciones VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pToken = pIn->>"$.UsuariosEjecuta.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_crear', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdVenta = pIn->>"$.UsuariosEjecuta.IdVenta";
    SET pObservaciones = COALESCE(pIn->>"$.UsuariosEjecuta.Observaciones", "");

    IF COALESCE(pIdVenta, 0) > 0 THEN
        -- Venta pendiente con al menos una linea de venta pendiente cuyo producto es fabricable
        IF NOT EXISTS(
            SELECT 
                lv.IdLineaProducto,
                COUNT(lr.Estado) CantidadLineasRemito,
                COUNT(lr.Estado='C') CantidadCanceladas
            FROM Ventas v
            INNER JOIN LineasProducto lv ON (lv.Tipo = 'V' AND lv.IdReferencia = v.IdVenta)
            INNER JOIN ProductosFinales pf ON (pf.IdProductoFinal = lv.IdProductoFinal)
            INNER JOIN Productos p ON (p.IdProducto = pf.IdProducto)
            LEFT JOIN LineasProducto lr ON (lr.Tipo = 'R' AND lr.IdLineaProductoPadre = lv.IdLineaProducto)
            WHERE 
                v.IdVenta = pIdVenta 
                AND v.Estado = 'C'
                AND lv.Estado = 'P'
                AND p.IdTipoProducto = 'P'
            GROUP BY lv.IdLineaProducto
            HAVING CantidadLineasRemito = CantidadCanceladas
        ) THEN
            SELECT f_generarRespuesta("ERROR_INVALIDO_VENTA_ORDEN_PRODUCCION", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    START TRANSACTION;
        INSERT INTO OrdenesProduccion (IdOrdenProduccion, IdUsuario, IdVenta, FechaAlta, Observaciones, Estado) VALUES (0, pIdUsuarioEjecuta, pIdVenta, NOW(), pObservaciones, 'E');

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
            WHERE   IdOrdenProduccion = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;