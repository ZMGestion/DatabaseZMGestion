DROP PROCEDURE IF EXISTS zsp_lineasOrdenProduccion_verificar;
DELIMITER $$
CREATE PROCEDURE zsp_lineasOrdenProduccion_verificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite verificar una línea de órden de producción.
        Devuelve la línea de órden de producción en 'respuesta' o el error en 'error'
    */

    DECLARE pLineasOrdenProduccion JSON;
    DECLARE pLineaOrdenProduccion JSON;
    DECLARE pIdOrdenProduccion INT;
    DECLARE pIdLineaOrdenProduccion bigint;
    DECLARE pIndice tinyint DEFAULT 0;
    DECLARE pIdRemitoTransformacion BIGINT;
    DECLARE pIdRemito BIGINT;
    DECLARE pIdUbicacion TINYINT;

    -- Para lineas remito
    DECLARE pIdProductoFinal INT;
    DECLARE pCantidad TINYINT;

    DECLARE pRespuesta JSON;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdVenta INT;
    DECLARE pIdLineaVenta BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineasOrdenProduccion_verificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF; 
    
    SET pLineasOrdenProduccion = COALESCE(pIn->>'$.LineasOrdenProduccion', JSON_ARRAY());
    SET pIdUbicacion = COALESCE(pIn ->> "$.Ubicaciones.IdUbicacion", 0); 

    IF JSON_LENGTH(pLineasOrdenProduccion) = 0 THEN
        SELECT f_generarRespuesta("ERROR_SIN_LINEASORDENPRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
        WHILE pIndice < JSON_LENGTH(pLineasOrdenProduccion) DO
            SET pLineaOrdenProduccion = JSON_EXTRACT(pLineasOrdenProduccion, CONCAT("$[", pIndice, "]"));
            SET pIdLineaOrdenProduccion = COALESCE(pLineaOrdenProduccion->>'$.IdLineaProducto', 0);

            IF pIndice = 0 THEN
                SET pIdOrdenProduccion = (SELECT COALESCE(IdReferencia, 0) FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Tipo = 'O');
            END IF;

            IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Tipo = 'O') THEN
                SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAORDENPRODUCCION", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF f_dameEstadoLineaOrdenProduccion(pIdLineaOrdenProduccion) != 'I' THEN
                SELECT f_generarRespuesta("ERROR_VERIFICAR_LINEAORDENPRODUCCION_ESTADO_LINEA", NULL) pOut;
                LEAVE SALIR;
            END IF; 

            IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND IdReferencia = pIdOrdenProduccion AND Tipo = 'O') THEN
                SELECT f_generarRespuesta("ERROR_DIFERENTE_ORDEN_LINEAORDENPRODUCCION", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF EXISTS(SELECT IdTarea FROM Tareas WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Estado != 'V') THEN
                SELECT f_generarRespuesta("ERROR_NOVERIFICADAS_TAREAS", NULL) pOut;
                LEAVE SALIR;
            END IF;

            SELECT IdProductoFinal, Cantidad INTO pIdProductoFinal, pCantidad FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion;

            IF EXISTS(
                SELECT lr.IdLineaProducto 
                FROM LineasProducto lo 
                INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
                INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
                WHERE 
                    lo.IdLineaProducto = pIdLineaOrdenProduccion
                    AND r.Tipo = 'Y'
            ) THEN
                -- El producto final está siendo transformado. 
                -- Seteo en remito el Id del remito de transformacion entrada.
                SET pIdRemito = (
                    SELECT r.IdRemito 
                    FROM LineasProducto lo 
                    INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
                    INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
                    WHERE 
                        lo.IdLineaProducto = pIdLineaOrdenProduccion
                        AND r.Tipo = 'X'
                );
                IF pIdRemito IS NULL THEN
                    INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) 
                    VALUES(0, pIdUbicacion, pIdUsuarioEjecuta, 'X', NULL, NOW(), 'Remito de transformación entrada por órden de producción', 'E');

                    SET pIdRemito = LAST_INSERT_ID();
                END IF;

                INSERT INTO LineasProducto(IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaOrdenProduccion, pIdProductoFinal, NULL, pIdRemito, 'R', NULL, pCantidad, NOW(), NULL, 'P');
            ELSE
                SET pIdRemito = (
                    SELECT r.IdRemito 
                    FROM LineasProducto lo 
                    INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
                    INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
                    WHERE 
                        lo.IdLineaProducto = pIdLineaOrdenProduccion
                        AND r.Tipo = 'E'
                );

                IF pIdRemito IS NULL THEN
                    INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, pIdUbicacion, pIdUsuarioEjecuta, 'E', NULL, NOW(), 'Remito de entrada por órden de producción', 'E');
                    SET pIdRemito = LAST_INSERT_ID();            
                END IF;

                INSERT INTO LineasProducto(IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaOrdenProduccion, pIdProductoFinal, NULL, pIdRemito, 'R', NULL, pCantidad, NOW(), NULL, 'P');
            END IF;

            -- Si viene a partir de una venta generamos un remito de salida para la venta asociada a la linea de venta.
            SELECT lv.IdLineaProducto, lv.IdReferencia INTO pIdLineaVenta, pIdVenta
            FROM LineasProducto lop
            INNER JOIN LineasProducto lv ON lv.IdLineaProducto = lop.IdLineaProductoPadre AND lv.Tipo = 'V'
            WHERE lop.IdLineaProducto = pIdLineaOrdenProduccion;
            
            IF COALESCE(pIdLineaVenta, 0) != 0 THEN
                INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) 
                VALUES(0, NULL, pIdUsuarioEjecuta, 'S', NULL, NOW(), 'Remito de reserva', 'C');

                INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaVenta, pIdProductoFinal, pIdUbicacion, LAST_INSERT_ID(), 'R', NULL, pCantidad, NOW(), NULL, 'P');
            END IF;

            UPDATE LineasProducto
            SET Estado = 'V'
            WHERE 
                IdLineaProducto = pIdLineaOrdenProduccion 
                AND Tipo = 'O';

            SET pIndice = pIndice + 1;
        END WHILE;

        SET pIdRemito = (
            SELECT r.IdRemito 
            FROM LineasProducto lo
            INNER JOIN OrdenesProduccion op ON lo.IdReferencia = op.IdOrdenProduccion AND lo.Tipo = 'O' 
            INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
            INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
            WHERE 
                op.IdOrdenProduccion = pIdOrdenProduccion
                AND r.Tipo = 'E'
        );

        IF pIdRemito IS NOT NULL THEN
            UPDATE Remitos
            SET Estado = 'C',
                FechaEntrega = NOW()
            WHERE IdRemito = pIdRemito;
        END IF;

        SET pIdRemito = (
            SELECT r.IdRemito 
            FROM LineasProducto lo
            INNER JOIN OrdenesProduccion op ON lo.IdReferencia = op.IdOrdenProduccion AND lo.Tipo = 'O' 
            INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
            INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
            WHERE 
                op.IdOrdenProduccion = pIdOrdenProduccion
                AND r.Tipo = 'X'
        );
        IF pIdRemito IS NOT NULL THEN
            UPDATE Remitos
            SET Estado = 'C',
                FechaEntrega = NOW()
            WHERE IdRemito = pIdRemito;
        END IF;

        SET pRespuesta = (
            SELECT CAST( JSON_OBJECT(
                "OrdenesProduccion",  JSON_OBJECT(
                    'IdOrdenProduccion', op.IdOrdenProduccion,
                    'IdUsuario', op.IdUsuario,
                    'FechaAlta', op.FechaAlta,
                    'Observaciones', op.Observaciones,
                    'Estado', f_dameEstadoOrdenProduccion(op.IdOrdenProduccion)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "LineasOrdenProduccion", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "IdLineaProductoPadre", lp.IdLineaProductoPadre,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "Estado", f_dameEstadoLineaOrdenProduccion(lp.IdLineaProducto),
                            "_IdRemito", r.IdRemito
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            ) AS JSON)
            FROM OrdenesProduccion op
            INNER JOIN Usuarios u ON u.IdUsuario = op.IdUsuario
            LEFT JOIN LineasProducto lp ON op.IdOrdenProduccion = lp.IdReferencia AND lp.Tipo = 'O'
            LEFT JOIN LineasProducto lr ON lp.IdLineaProducto = lr.IdLineaProductoPadre
            LEFT JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE IdOrdenProduccion = pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;