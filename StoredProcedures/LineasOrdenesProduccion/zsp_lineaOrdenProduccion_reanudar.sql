DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_reanudar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_reanudar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite reanudar una linea de orden de produccion.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Linea de presupuesto
    DECLARE pIdLineaProducto BIGINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pIdRemito INT;

    DECLARE pIdProductosFinales JSON;
    DECLARE pLineaProducto JSON;
    DECLARE pIdProductoFinal INT;
    DECLARE pIdUbicacion INT;
    DECLARE pIndex INT DEFAULT 0;
    DECLARE pLongitud INT DEFAULT 0;
    DECLARE pCantidadStock INT;
    DECLARE pCantidadSolicitada INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_reanudar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pIdLineaProducto = COALESCE(pIn ->> "$.LineasProducto.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF COALESCE((SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O'),'') != 'C' THEN
        SELECT f_generarRespuesta("ERROR_REANUDAR_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET @pIdLineaVentaPadre = (
        SELECT IdLineaProductoPadre FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O'
    );
    IF COALESCE(@pIdLineaVentaPadre, 0) > 0 THEN
        IF COALESCE((
            SELECT Cantidad
            FROM LineasProducto 
            WHERE 
                Tipo = 'V' 
                AND IdLineaProducto = @pIdLineaVentaPadre
                AND f_dameEstadoLineaVenta(IdLineaProducto) = 'P'
        ), 0) < (
            SELECT Cantidad 
            FROM LineasProducto 
            WHERE 
                IdLineaProducto = pIdLineaProducto 
                AND Tipo = 'O'
        ) THEN
            SELECT f_generarRespuesta("ERROR_REANUDAR_LINEA_ORDEN_PRODUCCION_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SELECT DISTINCT r.IdRemito INTO pIdRemito 
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdLineaProducto = pIdLineaProducto 
            AND lop.Tipo = 'O';

    START TRANSACTION;
        IF COALESCE(pIdRemito, 0) != 0 THEN
            SET pIdProductosFinales = (
                SELECT JSON_ARRAYAGG(JSON_OBJECT(
                    'IdLineaProducto', IdLineaProducto,
                    'IdLineaProductoPadre', IdLineaProductoPadre,
                    'IdProductoFinal', IdProductoFinal,
                    'IdUbicacion', IdUbicacion,
                    'Cantidad', Cantidad
                )) 
                FROM LineasProducto 
                WHERE 
                    IdReferencia = pIdRemito
                    AND Tipo = 'R'
            );

            SET pLongitud = JSON_LENGTH(pIdProductosFinales);

            WHILE pIndex < pLongitud DO
                SET pLineaProducto = JSON_EXTRACT(pIdProductosFinales, CONCAT("$[", pIndex, "]"));
                
                SELECT lr.Cantidad INTO pCantidadSolicitada 
                FROM Remitos r
                INNER JOIN LineasProducto lr 
                WHERE 
                    lr.IdReferencia = r.IdRemito 
                    AND lr.Tipo = 'R' 
                    AND r.IdRemito = pIdRemito;

                SET pIdProductoFinal = pLineaProducto->>"$.IdProductoFinal";
                SET pIdUbicacion = pLineaProducto->>"$.IdUbicacion";

                IF f_calcularStockProducto(pIdProductoFinal, pIdUbicacion) < pCantidadSolicitada THEN
                    SELECT f_generarRespuesta("ERROR_SIN_STOCK", NULL) pOut;
                    LEAVE SALIR;
                END IF;

                SET pIndex = pIndex + 1;
            END WHILE;

            UPDATE Remitos
            SET FechaEntrega = NOW()
            WHERE IdRemito = pIdRemito; 
        END IF;

        UPDATE LineasProducto 
        SET Estado = 'F'
        WHERE 
            IdLineaProducto = pIdLineaProducto
            AND Tipo = 'O';

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
                        'Cantidad', lp.Cantidad,
                        'FechaAlta', lp.FechaAlta,
                        'FechaCancelacion', lp.FechaCancelacion,
                        'Estado', lp.Estado
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
            AS JSON)
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
