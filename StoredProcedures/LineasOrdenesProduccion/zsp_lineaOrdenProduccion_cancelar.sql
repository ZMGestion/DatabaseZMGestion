DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_cancelar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_cancelar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite cancelar una linea de orden de produccion. 
        Controla que la linea de orden de produccion no se encuentre verificada.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    DECLARE pIdRemitoAnterior INT;
    DECLARE pIdRemitoNuevo INT;

    -- Linea de presupuesto
    DECLARE pIdLineaProducto BIGINT;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_cancelar', pIdUsuarioEjecuta, pMensaje);
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

    IF COALESCE((SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O'),'') != 'F' THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT DISTINCT r.IdRemito INTO pIdRemitoAnterior
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdLineaProducto = pIdLineaProducto 
            AND lop.Tipo = 'O';

    START TRANSACTION;
        IF COALESCE(pIdRemitoAnterior, 0) != 0 THEN
            -- (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado)
            INSERT INTO Remitos 
            SELECT 0, IdUbicacion, IdUsuario, Tipo, NULL, NOW(), Observaciones, Estado FROM Remitos WHERE IdRemito = pIdRemitoAnterior;

            UPDATE LineasProducto
            SET IdReferencia = LAST_INSERT_ID()
            WHERE 
                IdLineaProductoPadre = pIdLineaProducto
                AND Tipo = 'R'; 

            IF NOT EXISTS(
                SELECT IdLineaProducto
                FROM LineasProducto
                WHERE  
                    IdReferencia = pIdRemitoAnterior
                    AND Tipo = 'R'
            ) THEN
                -- Quedó huerfana borramos el remito
                DELETE FROM Remitos
                WHERE IdRemito = pIdRemitoAnterior;
            END IF;
        END IF;

        UPDATE LineasProducto 
        SET Estado = 'C'
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
