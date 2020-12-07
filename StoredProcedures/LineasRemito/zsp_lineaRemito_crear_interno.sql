DROP PROCEDURE IF EXISTS zsp_lineaRemito_crear_interno;
DELIMITER $$
CREATE PROCEDURE zsp_lineaRemito_crear_interno(pIn JSON, OUT pIdLineaRemito int, OUT pError varchar(255))
SALIR: BEGIN
    /*
        Procedimiento que contiene los permisos basicos para crer una linea de remito.
        Devuelve el Id de la linea de remito creada o el error en 'error';
    */
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdRemito int;
    DECLARE pCantidad tinyint;
    DECLARE pIdProductoFinal int;

    -- Producto final;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pMensaje varchar(255);

    -- Extraigo atributos de la linea de remito
    SET pIdRemito = COALESCE(pIn ->> "$.LineasProducto.IdReferencia", 0);
    SET pCantidad = COALESCE(pIn ->> "$.LineasProducto.Cantidad", 0);
    SET pIdUbicacion = pIn ->> "$.LineasProducto.IdUbicacion";

    -- Extraigo atributos del producto final
    SET pIdProducto = COALESCE(pIn ->> "$.ProductosFinales.IdProducto", 0);
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela", 0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre", 0);

    SET @pTipo = (SELECT Tipo FROM Remitos WHERE IdRemito = pIdRemito);

    IF @pTipo IN ('S', 'Y') AND NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_UBICACION_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF @pTipo IN ('E', 'X') THEN
        SET pIdUbicacion = NULL;
    END IF;

    IF pCantidad = 0 THEN
        SET pIdLineaRemito = 0;
        SET pError = "ERROR_CANTIDAD_INVALIDA";
        LEAVE SALIR;
    END IF;

    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;
    -- Si no existe el producto final y el remito es de entrada lo creo. No puedo crear una linea de remito para un remito de salida con algo que no existe
    IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
        IF @pTipo IN ('E', 'X') THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pMensaje);
            IF pMensaje IS NOT NULL THEN
                SET pError = pMensaje;
                SET pIdLineaRemito = 0;
                LEAVE SALIR;
            END IF;
        ELSE
            SELECT f_generarRespuesta("ERROR_PRODUCTOFINAL_NOEXISTE", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF @pTipo IN ('S', 'Y') AND pCantidad < f_calcularStockProducto(pIdProductoFinal, pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);

    INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, NULL, pIdProductoFinal, pIdUbicacion, pIdRemito, 'R', NULL, pCantidad, NOW(), NULL, 'P');

    SET pIdLineaRemito = LAST_INSERT_ID();
    SET pError = NULL;
END $$
DELIMITER ;
