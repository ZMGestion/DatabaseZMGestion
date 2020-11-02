DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear una linea de orden de produccion. 
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno.
        Devuelve la linea de orden de produccion en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Linea de orden de produccion a crear
    DECLARE pIdLineaProducto BIGINT;
    DECLARE pIdOrdenProduccion INT;
    DECLARE pIdProductoFinal INT;
    DECLARE pCantidad TINYINT;

    -- ProductoFinal
    DECLARE pIdProducto INT;
    DECLARE pIdTela SMALLINT;
    DECLARE pIdLustre TINYINT;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de orden de producción
    SET pIdOrdenProduccion = pIn ->> "$.LineasProducto.IdReferencia";
    SET pCantidad = pIn ->> "$.LineasProducto.Cantidad";

    -- Extraigo atributos del producto final
    SET pIdProducto = pIn ->> "$.ProductosFinales.IdProducto";
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela",0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre",0);

    IF NOT EXISTS (SELECT IdOrdenProduccion FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0  OR pCantidad IS NULL THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pMensaje);
            IF pMensaje IS NOT NULL THEN
                SELECT f_generarRespuesta(pMensaje, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
        
        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);
 
        IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdOrdenProduccion AND Tipo = 'O' AND IdProductoFinal = pIdProductoFinal) THEN
            SELECT f_generarRespuesta("ERROR_ORDEN_PRODUCCION_EXISTE_PRODUCTOFINAL", NULL) pOut;
            LEAVE SALIR;
        END IF;

        INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
        VALUES(0, NULL, pIdProductoFinal, NULL, pIdOrdenProduccion, 'O', NULL, pCantidad, NOW(), NULL, 'F');

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
                WHERE	lp.IdLineaProducto = LAST_INSERT_ID()
            );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
