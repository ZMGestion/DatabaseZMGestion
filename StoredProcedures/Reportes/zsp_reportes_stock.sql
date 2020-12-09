DROP PROCEDURE IF EXISTS zsp_reportes_stock;
DELIMITER $$
CREATE PROCEDURE zsp_reportes_stock(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que devuelve todos los productos junto con su stock total
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, "zsp_reportes_stock", pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != "OK" THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                "ProductosFinales",JSON_OBJECT(
                    "IdProductoFinal", pf.IdProductoFinal,
                    "IdProducto", pf.IdProducto,
                    "IdLustre", pf.IdLustre,
                    "IdTela", pf.IdTela,
                    "FechaAlta", pf.FechaAlta,
                    "FechaBaja", pf.FechaBaja,
                    "Estado", pf.Estado,
                    "_Cantidad", COALESCE(f_calcularStockProducto(pf.IdProductoFinal, 0), 0)
                ),
                "Productos",JSON_OBJECT(
                    "IdProducto", pr.IdProducto,
                    "IdCategoriaProducto", pr.IdCategoriaProducto,
                    "IdGrupoProducto", pr.IdGrupoProducto,
                    "IdTipoProducto", pr.IdTipoProducto,
                    "Producto", pr.Producto,
                    "LongitudTela", pr.LongitudTela,
                    "FechaAlta", pr.FechaAlta,
                    "FechaBaja", pr.FechaBaja,
                    "Observaciones", pr.Observaciones,
                    "Estado", pr.Estado
                ),
                "Lustres", IF(pf.IdLustre IS NOT NULL, 
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL),
                "Telas", IF(pf.IdTela IS NOT NULL, 
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ) , NULL) 
            )
        ) 
        FROM	ProductosFinales pf            
        INNER JOIN Productos pr ON (pr.IdProducto = pf.IdProducto)
        LEFT JOIN Telas te ON (te.IdTela = pf.IdTela)
        LEFT JOIN Lustres lu ON (lu.IdLustre = pf.IdLustre)
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
