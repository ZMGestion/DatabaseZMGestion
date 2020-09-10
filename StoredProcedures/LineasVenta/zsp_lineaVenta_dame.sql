DROP PROCEDURE IF EXISTS `zsp_lineaVenta_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaVenta_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite instanciar una linea de venta a partir de su Id. 
        Controla que la linea de venta exista.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de venta
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = pLineasProducto ->> "$.IdLineaProducto";

    IF pIdLineaProducto IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

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
END $$
DELIMITER ;
