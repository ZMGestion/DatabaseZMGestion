DROP PROCEDURE IF EXISTS zsp_lineaVenta_crear_interno;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_crear_interno(pIn JSON, OUT pIdLineaVenta bigint, OUT pError varchar(255))
SALIR: BEGIN
    /*
        Procedimiento interno para crear una linea de venta.
        Devuelve el IdLineaProducto en caso de crear la linea de venta o 0 en caso de error.
    */
    -- Linea de venta
    DECLARE pLineasProducto JSON;
    DECLARE pIdVenta int;
    DECLARE pIdProductoFinal int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pMensaje varchar(255);

    -- Extraigo atributos de la linea de venta
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdVenta = COALESCE(pLineasProducto ->> "$.IdReferencia", 0);
    SET pPrecioUnitario = COALESCE(pLineasProducto ->> "$.PrecioUnitario", 0.00);
    SET pCantidad = COALESCE(pLineasProducto ->> "$.Cantidad", 0);

    -- Extraigo atributos del producto final
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = COALESCE(pProductosFinales ->> "$.IdProducto", 0);
    SET pIdTela = COALESCE(pProductosFinales ->> "$.IdTela", 0);
    SET pIdLustre = COALESCE(pProductosFinales ->> "$.IdLustre", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_NOEXISTE_VENTA";
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0 THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_CANTIDAD_INVALIDA";
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 OR pPrecioUnitario IS NULL THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_INVALIDO_PRECIO";
        LEAVE SALIR;
    END IF;
    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;
    IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
        CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pMensaje);
        IF pMensaje IS NOT NULL THEN
            SET pError = pMensaje;
            SET pIdLineaVenta = 0;
            LEAVE SALIR;
        END IF;
    END IF;
    
    SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);

    IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdVenta AND Tipo = 'V' AND IdProductoFinal = pIdProductoFinal) THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_VENTA_EXISTE_PRODUCTOFINAL";
        LEAVE SALIR;
    END IF;

    INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, NULL, pIdProductoFinal, NULL, pIdVenta, 'V', pPrecioUnitario, pCantidad, NOW(), NULL, 'P');

    SET pIdLineaVenta = LAST_INSERT_ID();
    SET pError = NULL;
END $$
DELIMITER ;
