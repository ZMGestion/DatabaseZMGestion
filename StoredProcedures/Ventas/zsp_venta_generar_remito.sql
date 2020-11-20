DROP PROCEDURE IF EXISTS zsp_venta_generar_remito;
DELIMITER $$
CREATE PROCEDURE zsp_venta_generar_remito(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear un remito a partir de una venta.
        Deben especificarse las lineas de venta a utilizarse.
        Devuelve el remito en 'respuesta' o el error en 'error'.
        LineasVenta : [
            {
                IdLineaVenta,
                IdUbicacion,
            }
        ]
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdVenta int;
    DECLARE pIdDomicilio int;
    DECLARE pLineasVenta JSON;
    DECLARE pLineaVenta JSON;
    DECLARE pIdLineaVenta bigint;
    DECLARE pIdProductoFinal int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pCantidadSolicitada tinyint;
    DECLARE pIdRemito int DEFAULT 0;
    DECLARE pCantidad tinyint;
    DECLARE pIndice tinyint DEFAULT 0;
    DECLARE pLongitud tinyint DEFAULT 0;
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_generar_remito', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdVenta = COALESCE(pIn->>'$.Ventas.IdVenta', 0);
    SET pIdDomicilio = COALESCE(pIn->>'$.Ventas.IdDomicilio', 0);
    SET pLineasVenta = COALESCE(pIn->>'$.LineasVenta', JSON_ARRAY());
    
    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_VENTA_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Si la venta no se encuentra en estado 'Pendiente'
    IF (SELECT f_calcularEstadoVenta(pIdVenta)) != 'C' THEN
        SELECT f_generarRespuesta("ERROR_VENTA_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT dc.IdDomicilio FROM DomiciliosCliente dc INNER JOIN Clientes c ON c.IdCliente = dc.IdCliente INNER JOIN Ventas v ON v.IdCliente = c.IdCliente WHERE v.IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_DOMICILIO_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF JSON_LENGTH(pLineasVenta) = 0 THEN
        SELECT f_generarRespuesta("ERROR_SIN_LINEASVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
        WHILE pIndice < JSON_LENGTH(pLineasVenta) DO
            SET pLineaVenta = JSON_EXTRACT(pLineasVenta, CONCAT("$[", pIndice, "]"));
            SET pIdLineaVenta = COALESCE(pLineaVenta->>'$.IdLineaProducto', 0);
            SET pIdUbicacion = COALESCE(pLineaVenta->>'$.IdUbicacion', 0);
            SET pCantidadSolicitada = COALESCE(pLineaVenta->>'$.Cantidad', 0);

            IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta AND IdReferencia = pIdVenta AND Tipo = 'V' AND Estado = 'P') THEN
                SELECT f_generarRespuesta("ERROR_LINEAVENTA_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
                SELECT f_generarRespuesta("ERROR_UBICACION_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pCantidadSolicitada = 0 THEN
                SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
                LEAVE SALIR;
            END IF;

            SELECT IdProductoFinal, Cantidad INTO pIdProductoFinal, pCantidad FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta;

            IF f_dameEstadoLineaVenta(pIdLineaVenta) != 'P' THEN
                SELECT f_generarRespuesta("ERROR_LINEAVENTA_ESTADO_REMITO", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pCantidadSolicitada > pCantidad THEN
                SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA_LINEASVENTA", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF NOT EXISTS(SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal AND Estado = 'A') THEN
                SELECT f_generarRespuesta("ERROR_PRODUCTOFINAL_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            -- Creo un remito de salida en estado 'En Creación'
            IF pIndice = 0 THEN
                INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, NULL, pIdUsuarioEjecuta, 'S', NULL, NOW(), NULL, 'E');
                SET pIdRemito = LAST_INSERT_ID();
            END IF;

            IF pIdRemito = 0 THEN
                SELECT f_generarRespuesta("ERROR_REMITO_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pCantidadSolicitada < pCantidad THEN
                -- Debemos partir la linea de venta.
                UPDATE LineasProducto
                SET Cantidad = pCantidadSolicitada
                WHERE IdLineaProducto = pIdLineaVenta;

                INSERT INTO LineasProducto SELECT 0, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta; 

                UPDATE LineasProducto
                SET Cantidad = pCantidad - pCantidadSolicitada
                WHERE IdLineaProducto = LAST_INSERT_ID();

            END IF;

            INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, pIdLineaVenta, pIdProductoFinal, pIdUbicacion, pIdRemito, 'R', NULL, pCantidadSolicitada, NOW(), NULL, 'P');
            
            SET pIndice = pIndice + 1;
        END WHILE;

        SET @pIdDomicilio = (SELECT IdDomicilio FROM Ventas WHERE IdVenta = pIdVenta);

        IF @pIdDomicilio IS NULL OR @pIdDomicilio != pIdDomicilio THEN
            UPDATE Ventas
            SET IdDomicilio = pIdDomicilio
            WHERE IdVenta = pIdVenta;
        END IF;

        UPDATE Remitos
        SET Estado = 'C'
        WHERE IdRemito = pIdRemito;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    "IdRemito", r.IdRemito,
                    "IdUbicacion", r.IdUbicacion,
                    "IdUsuario", r.IdUsuario,
                    "Tipo", r.Tipo,
                    "FechaEntrega", r.FechaEntrega,
                    "FechaAlta", r.FechaAlta,
                    "Observaciones", r.Observaciones,
                    "Estado", f_calcularEstadoRemito(r.IdRemito)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ue.Ubicacion
                ),
                "LineasRemito", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "IdUbicacion", lp.IdUbicacion,
                            "Estado", lp.Estado
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
                        "Ubicaciones", JSON_OBJECT(
                            "Ubicacion", us.Ubicacion
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
            )
            FROM Remitos r
            INNER JOIN Usuarios u ON u.IdUsuario = r.IdUsuario
            LEFT JOIN Ubicaciones ue ON ue.IdUbicacion = r.IdUbicacion
            LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = 'R'
            LEFT JOIN Ubicaciones us ON lp.IdUbicacion = us.IdUbicacion
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	r.IdRemito = pIdRemito
        );

        SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT;
END $$
DELIMITER ;