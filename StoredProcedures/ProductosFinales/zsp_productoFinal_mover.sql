DROP PROCEDURE IF EXISTS zsp_productoFinal_mover;
DELIMITER $$
CREATE PROCEDURE zsp_productoFinal_mover(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite mover un producto final de una ubicacion a otra.
        Devuelve el producto final en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdProductoFinal int;
    DECLARE pCantidad int;
    DECLARE pIdUbicacionEntrada tinyint;
    DECLARE pIdUbicacionSalida tinyint;
    DECLARE pProductosFinales JSON;

    DECLARE pIdLineaRemito bigint;
    DECLARE pError varchar(255);

    DECLARE pRespuesta JSON;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_mover', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdProductoFinal = pIn ->> "$.LineasProducto.IdProductoFinal";
    SET pCantidad = pIn ->> "$.LineasProducto.Cantidad";
    SET pIdUbicacionEntrada = pIn ->> "$.UbicacionesEntrada.IdUbicacion";
    SET pIdUbicacionSalida = pIn ->> "$.UbicacionesSalida.IdUbicacion";

    IF NOT EXISTS(SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacionEntrada) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacionSalida) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad > f_calcularStockProducto(pIdProductoFinal, pIdUbicacionSalida) THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        -- Creo el remito de salida
        INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, NULL, pIdUsuarioEjecuta, 'S', NULL, NOW(), 'Movimiento de productos', 'E');

        SET @pIdRemitoSalida = LAST_INSERT_ID();

        SET pProductosFinales = (
            SELECT JSON_OBJECT(
                'IdProducto', IdProducto,
                'IdLustre', COALESCE(IdLustre, 0),
                'IdTela', COALESCE(IdTela, 0)
            )
            FROM ProductosFinales
            WHERE IdProductoFinal = pIdProductoFinal
        );

        CALL zsp_lineaRemito_crear_interno(
            JSON_OBJECT(
                'LineasProducto',JSON_OBJECT(
                    'IdReferencia', @pIdRemitoSalida,
                    'IdUbicacion', pIdUbicacionSalida,
                    'Cantidad', pCantidad
                ),
                'ProductosFinales', pProductosFinales
            ), 
            pIdLineaRemito,
            pError
        );

        IF pError IS NOT NULL THEN
            SELECT f_generarRespuesta(pError, NULL) pOut;
            LEAVE SALIR;
        END IF;

        -- Creo el remito de entrada
        INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, pIdUbicacionEntrada, pIdUsuarioEjecuta, 'E', NULL, NOW(), 'Movimiento de productos', 'E');
        
        SET @pIdRemitoEntrada = LAST_INSERT_ID();

        CALL zsp_lineaRemito_crear_interno(
            JSON_OBJECT(
                'LineasProducto',JSON_OBJECT(
                    'IdReferencia', @pIdRemitoEntrada,
                    'Cantidad', pCantidad
                ),
                'ProductosFinales', pProductosFinales
            ), 
            pIdLineaRemito,
            pError
        );

        IF pError IS NOT NULL THEN
            SELECT f_generarRespuesta(pError, NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET @pNow = NOW();

        UPDATE Remitos
        SET Estado = 'C',
            FechaEntrega = @pNow
        WHERE IdRemito = @pIdRemitoEntrada;

        UPDATE Remitos
        SET Estado = 'C',
            FechaEntrega = @pNow
        WHERE IdRemito = @pIdRemitoSalida;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                'ProductosFinales', JSON_OBJECT(
                    'IdProductoFinal', pf.IdProductoFinal,
                    'IdProducto', pf.IdProducto,
                    'IdTela', pf.IdTela,
                    'IdLustre', pf.IdLustre,
                    '_Cantidad', @pCantidad
                ),
                'Productos', JSON_OBJECT(
                    'IdProducto', p.IdProducto,
                    'Producto', p.Producto
                ),
                'Telas',IF (t.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela
                    ),NULL
                ),
                'Lustres',IF (l.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        'IdLustre', l.IdLustre,
                        'Lustre', l.Lustre
                    ), NULL
                ),
                'Ubicaciones', CAST(@pUbicaciones AS JSON)
            )
            FROM ProductosFinales pf
            INNER JOIN Productos p ON pf.IdProducto = p.IdProducto
            LEFT JOIN Telas t ON pf.IdTela = t.IdTela
            LEFT JOIN Lustres l ON pf.IdLustre = l.IdLustre
            WHERE pf.IdProductoFinal = pIdProductoFinal
        );

         SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
    COMMIT;
END $$
DELIMITER ;