DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_listar_tareas`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_listar_tareas`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar las lineas de presupuesto de un presupuesto. 
        Controla que exista el presupuesto.
        Devuelve el presupuesto con sus lineas de presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Presupuesto
    DECLARE pIdLineaOrdenProduccion BIGINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pLineasPresupuesto JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_listar_tareas', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pIdLineaOrdenProduccion = pIn ->> "$.LineasOrdenProduccion.IdLineaProducto";

    IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
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
            )
        FROM Presupuestos p
        LEFT JOIN LineasProducto lp ON p.IdPresupuesto = lp.IdReferencia AND lp.Tipo = 'P'
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	p.IdPresupuesto = pIdPresupuesto
    );
	
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;
