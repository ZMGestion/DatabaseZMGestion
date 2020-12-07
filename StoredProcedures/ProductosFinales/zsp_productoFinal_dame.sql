DROP PROCEDURE IF EXISTS `zsp_productoFinal_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite instanciar un producto final a partir de su Id.
        Devuelve el producto final en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pTelas JSON;
    DECLARE pLustres JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProductoFinal = pProductosFinales ->> "$.IdProductoFinal";
    -- SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    -- SET pIdTela = pProductosFinales ->> "$.IdTela";
    -- SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;

    -- Ultimos precios Productos
    CREATE TEMPORARY TABLE tmp_preciosProductos AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'P' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPreciosProductos AS
    SELECT pr.* 
    FROM tmp_preciosProductos tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    -- Ultimos precios Telas
    CREATE TEMPORARY TABLE tmp_preciosTelas AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'T' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPreciosTelas AS
    SELECT pr.* 
    FROM tmp_preciosTelas tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "ProductosFinales",  
                            JSON_OBJECT(
                                'IdProductoFinal', pf.IdProductoFinal,
                                'IdProducto', pf.IdProducto,
                                'IdLustre', pf.IdLustre,
                                'IdTela', pf.IdTela,
                                'FechaAlta', pf.FechaAlta,
                                'FechaBaja', pf.FechaBaja,
                                'Estado', pf.Estado,
                                '_PrecioTotal', (upp.Precio + COALESCE(pr.LongitudTela, 0) * upt.Precio),
                                '_Cantidad', f_calcularStockProducto(pf.IdProductoFinal, 0)
                            ),
                        "Productos",
                            JSON_OBJECT(
                                'IdProducto', pr.IdProducto,
                                'IdCategoriaProducto', pr.IdCategoriaProducto,
                                'IdGrupoProducto', pr.IdGrupoProducto,
                                'IdTipoProducto', pr.IdTipoProducto,
                                'Producto', pr.Producto,
                                'LongitudTela', pr.LongitudTela,
                                'FechaAlta', pr.FechaAlta,
                                'FechaBaja', pr.FechaBaja,
                                'Observaciones', pr.Observaciones,
                                'Estado', pr.Estado
                            ),
                        "Lustres",
                            JSON_OBJECT(
                                'IdLustre', lu.IdLustre,
                                'Lustre', lu.Lustre
                            ),
                        "Telas",  
                            JSON_OBJECT(
                                'IdTela', te.IdTela,
                                'Tela', te.Tela
                            )
                )
             AS JSON)
			FROM	ProductosFinales pf            
            INNER JOIN Productos pr ON (pr.IdProducto = pf.IdProducto)
            LEFT JOIN Telas te ON (te.IdTela = pf.IdTela)
            LEFT JOIN Lustres lu ON (lu.IdLustre = pf.IdLustre)
            INNER JOIN tmp_ultimosPreciosProductos upp ON (pf.IdProducto = upp.IdReferencia)
            LEFT JOIN tmp_ultimosPreciosTelas upt ON (pf.IdTela = upt.IdReferencia)
            WHERE pf.IdProductoFinal = pIdProductoFinal
        );
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;

END $$
DELIMITER ;

