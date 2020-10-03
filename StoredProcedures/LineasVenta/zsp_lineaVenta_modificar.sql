DROP PROCEDURE IF EXISTS zsp_lineaVenta_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una linea de venta.
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno. 
        Controla que tenga permiso de cambiar el precio, en caso contrario setea el precio del producto final
        Devuelve la linea de producto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de venta
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
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
    DECLARE pError varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = COALESCE(pLineasProducto ->> "$.IdLineaProducto", 0);
    SET pIdVenta = COALESCE(pLineasProducto ->> "$.IdReferencia", 0);
    SET pPrecioUnitario = COALESCE(pLineasProducto ->> "$.PrecioUnitario", 0.00);
    SET pCantidad = COALESCE(pLineasProducto ->> "$.Cantidad", 0);

    -- Extraigo atributos del producto final
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = COALESCE(pProductosFinales ->> "$.IdProducto", 0);
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0 THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
        
        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre);

        IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdLineaProducto != pIdLineaProducto AND Tipo = 'V' AND IdProductoFinal = pIdProductoFinal AND IdReferencia = pIdVenta) THEN
            SELECT f_generarRespuesta("ERROR_VENTA_EXISTE_PRODUCTOFINAL", NULL) pOut;
            LEAVE SALIR;
        END IF;

        CALL zsp_usuario_tiene_permiso(pToken, 'modificar_precio_venta', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_calcularPrecioProductoFinal(pIdProductoFinal) INTO pPrecioUnitario;
        END IF;

        UPDATE LineasProducto
        SET IdProductoFinal = pIdProductoFinal,
            Cantidad = pCantidad,
            PrecioUnitario = pPrecioUnitario
        WHERE IdLineaProducto = pIdLineaProducto;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "LineasProducto", JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad,
                    "PrecioUnitario", lp.PrecioUnitario
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
            FROM LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
