DROP PROCEDURE IF EXISTS zsp_productoFinal_stock;
DELIMITER $$
CREATE PROCEDURE zsp_productoFinal_stock(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite conocer el stock de un producto final en una ubicacion determinada.
    */
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_stock', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdUbicacion = COALESCE(pIn->>'$.Ubicaciones.IdUbicacion', 0);
    SET pIdProductoFinal = COALESCE(pIn->>'$.ProductosFinales.IdProductoFinal', 0);
    SET pIdProducto = COALESCE(pIn->>'$.ProductosFinales.IdProducto', 0);
    SET pIdLustre = COALESCE(pIn->>'$.ProductosFinales.IdLustre', 0);
    SET pIdTela = COALESCE(pIn->>'$.ProductosFinales.IdTela', 0);

    IF pIdProductoFinal = 0 THEN
        SET pIdProductoFinal = COALESCE((SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre)), 0);
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_UBICACION_NOEXISTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdProductoFinal = 0 THEN
        SELECT f_generarRespuesta('ERROR_PRODUCTOFINAL_NOEXISTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET @pCantidad = f_calcularStockProducto(pIdProductoFinal, pIdUbicacion);

    SET @pUbicaciones = (
        SELECT JSON_OBJECT(
            'IdUbicacion', IdUbicacion,
            'Ubicacion', Ubicacion
        ) 
        FROM Ubicaciones 
        WHERE IdUbicacion = pÌdUbicacion
    );

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
    
END $$
DELIMITER ;
