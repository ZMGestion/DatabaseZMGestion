DROP PROCEDURE IF EXISTS `zsp_lineaPresupuesto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaPresupuesto_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear una linea de presupuesto. 
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno. 
        Controla que tenga permiso de cambiar el precio, en caso contrario setea el precio del producto final
        Devuelve la linea de producto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    DECLARE pIdPresupuesto int;
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaPresupuesto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdPresupuesto = pLineasProducto ->> "$.IdReferencia";
    SET pPrecioUnitario = pLineasProducto ->> "$.PrecioUnitario";
    SET pCantidad = pLineasProducto ->> "$.Cantidad";

    -- Extraigo atributos del producto final
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF pCantidad <= 0  OR pCantidad IS NULL THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 OR pPrecioUnitario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF pIdTela = 0 THEN
            SET pIdTela = NULL;
        END IF;
        IF pIdLustre = 0 THEN
            SET pIdLustre = NULL;
        END IF;
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
        
        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);
 
        IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdPresupuesto AND Tipo = 'P' AND IdProductoFinal = pIdProductoFinal) THEN
            SELECT f_generarRespuesta("ERROR_PRESUPUESTO_EXISTE_PRODUCTOFINAL", NULL) pOut;
            LEAVE SALIR;
        END IF;

        CALL zsp_usuario_tiene_permiso(pToken, 'modificar_precio_presupuesto', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_calcularPrecioProductoFinal(pIdProductoFinal) INTO pPrecioUnitario;
        END IF;

        INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, NULL, pIdProductoFinal, NULL, pIdPresupuesto, 'P', pPrecioUnitario, pCantidad, NOW(), NULL, 'P');

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
