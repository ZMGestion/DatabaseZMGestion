DROP PROCEDURE IF EXISTS zsp_lineaRemito_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaRemito_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una linea de remito. Controla que se encuentre pendiente de entrega.
        Devuelve la linea de remito modificada en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdLineaRemito bigint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdRemito int;
    DECLARE pCantidad tinyint;
    DECLARE pIdProductoFinal int;
    
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    DECLARE pError varchar(255);

    DECLARE pRespuesta JSON;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    SET pIdLineaRemito = COALESCE(pIn->>'$.LineasProducto.IdLineaProducto', 0);
    SET pIdUbicacion = COALESCE(pIn->>'$.LineasProducto.IdUbicacion', 0);
    SET pCantidad = COALESCE(pIn->>'$.LineasProducto.Cantidad', 0);
    SET pIdProducto = COALESCE(pIn->>'$.ProductosFinales.IdProducto', 0);
    SET pIdTela = COALESCE(pIn->>'$.ProductosFinales.IdTela', 0);
    SET pIdLustre = COALESCE(pIn->>'$.ProductosFinales.IdLustre', 0);

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito);
    SET @pTipo = (SELECT Tipo FROM Remitos WHERE IdRemito = pIdRemito);

    IF @pTipo IN ('S', 'Y') AND NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_UBICACION_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT FechaEntrega FROM Remitos WHERE IdRemito = pIdRemito) IS NOT NULL OR (SELECT Estado FROM Remitos WHERE IdRemito = pIdRemito) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_NOPENDIENTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0 THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
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

        UPDATE LineasProducto
        SET IdProductoFinal = pIdProductoFinal,
            Cantidad = pCantidad,
            IdUbicacion = NULLIF(pIdUbicacion, 0)
        WHERE IdLineaProducto = pIdLineaRemito;
        
        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
                        'IdLineaProducto', lp.IdLineaProducto,
                        'IdLineaProductoPadre', lp.IdLineaProductoPadre,
                        'IdProductoFinal', lp.IdProductoFinal,
                        'IdUbicacion', lp.IdUbicacion,
                        'IdReferencia', lp.IdReferencia,
                        'Tipo', lp.Tipo,
                        'PrecioUnitario', lp.PrecioUnitario,
                        "_PrecioUnitarioActual",  f_calcularPrecioProductoFinal(lp.IdProductoFinal),
                        'Cantidad', lp.Cantidad,
                        'FechaAlta', lp.FechaAlta,
                        'FechaCancelacion', lp.FechaCancelacion,
                        'Estado', lp.Estado
                    ) ,
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
            AS JSON)
            FROM	LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaRemito AND lp.Tipo = 'R'
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
