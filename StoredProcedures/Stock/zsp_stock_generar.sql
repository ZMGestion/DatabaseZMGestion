DROP PROCEDURE IF EXISTS zsp_stock_calcular;
DELIMITER $$
CREATE PROCEDURE zsp_stock_calcular(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite conocer el stock de los productos finales.
        Se puede filtrar por producto final, tela, lustre o ubicacion.
        Devuelve una lista de productos finales junto con su cantidad en 'respuesta' o un error en 'error'.
    */
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;
    DECLARE pIdUbicacion tinyint;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_stock_calcular', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdProducto = COALESCE(pIn->>'$.ProductosFinales.IdProducto', 0);
    SET pIdTela = COALESCE(pIn->>'$.ProductosFinales.IdTela', 0);
    SET pIdLustre = COALESCE(pIn->>'$.ProductosFinales.IdLustre', 0);
    SET pIdUbicacion = COALESCE(pIn->>'$.Ubicaciones.IdUbicacion', 0);

    SET pIdProductoFinal = COALESCE((SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND  (IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela)) AND (IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre))), 0);

    DROP TEMPORARY TABLE IF EXISTS tmp_stock;

    CREATE TEMPORARY TABLE tmp_stock AS
    SELECT
        IdProductoFinal,
        CASE 
            WHEN pIdUbicacion != 0 THEN r.IdUbicacion
        END,
        SUM(IF(r.Tipo IN ('E', 'X'), lp.Cantidad, -1 * lp.Cantidad)) Total
    FROM Remitos r
    INNER JOIN LineasProducto lp ON lp.IdReferencia = r.IdRemito AND lp.Tipo = 'R'
    INNER JOIN ProductosFinales pf ON pf.IdProductoFinal = lp.IdProductoFinal
    WHERE 
        (lp.IdProductoFinal = pIdProductoFinal OR pIdProductoFinal = 0)
        AND (r.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
    GROUP BY
        IdProductoFinal,
        (CASE 
            WHEN pIdUbicacion != 0 THEN r.IdUbicacion
        END);

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    SET pRespuesta = JSON_OBJECT(
        "resultado", (
            SELECT CAST(CONCAT("[", COALESCE(GROUP_CONCAT(JSON_OBJECT(
                "ProductosFinales",  JSON_OBJECT(
                    "IdProductoFinal", pf.IdProductoFinal,
                    "IdProducto", pf.IdProducto,
                    "IdTela", pf.IdTela,
                    "IdLustre", pf.IdLustre,
                    "__Cantidad", tmp.Total
                ),
                "Productos", JSON_OBJECT(
                    "IdProducto", p.IdProducto,
                    "Producto", p.Producto
                ),
                "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", t.IdTela,
                        "Tela", t.Tela
                    ),NULL),
                "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", l.IdLustre,
                        "Lustre", l.Lustre
                    ), NULL),
                "Ubicaciones", (pIdUbicacion != 0,
                    JSON_OBJECT(
                        "IdUbicacion", u.IdUbicacion,
                        "Ubicacion", u.Ubicacion
                    ), NULL)
            )),""), "]") AS JSON)
            FROM tmp_stock tmp
            INNER JOIN ProductosFinales pf ON pf.IdProductoFinal = tmp.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = p.IdProducto
            LEFT JOIN Telas t ON pf.IdTela = t.IdTela
            LEFT JOIN Lustres l ON pf.IdLustre = l.IdLustre
            LEFT JOIN Ubicaciones u ON u.IdUbicacion = tmp.IdUbicacion
        )    
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_stock;
END $$
DELIMITER ;