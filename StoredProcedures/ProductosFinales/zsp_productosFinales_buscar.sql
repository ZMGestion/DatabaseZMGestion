DROP PROCEDURE IF EXISTS `zsp_productosFinales_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_productosFinales_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar un producto por su nombre, Tipo de Producto (T: Todos), Categoria de Productos (0: Todos), Grupo de Productos (0 : Todos), Estado (A:Activo - B:Baja - T:Todos).
        Devuelve una lista de productos en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a buscar
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;
    DECLARE pEstado char(1);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productosFinales_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";
    SET pEstado = pProductosFinales ->> "$.Estado";

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    SET pIdProducto = COALESCE(pIdProducto, 0);
    SET pIdTela = COALESCE(pIdTela, 0);
    SET pIdLustre = COALESCE(pIdLustre, 0);

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_ProductosFinales;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    -- Resultset completo
    CREATE TEMPORARY TABLE tmp_ProductosFinales
    AS SELECT *
    FROM ProductosFinales
	WHERE (IdProducto = pIdProducto OR pIdProducto = 0)
    AND (IdTela = pIdTela OR pIdTela = 0)
    AND (IdLustre = pIdLustre OR pIdLustre = 0)
    AND (Estado = pEstado OR pEstado = 'T');

    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_ProductosFinales);

    -- Resultset paginado
    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * 
    FROM tmp_ProductosFinales
    LIMIT pOffset, pLongitudPagina;

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

    SET pRespuesta = (SELECT 
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", 
                JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "ProductosFinales",  
                            JSON_OBJECT(
                                'IdProductoFinal', tp.IdProductoFinal,
                                'IdProducto', tp.IdProducto,
                                'IdLustre', tp.IdLustre,
                                'IdTela', tp.IdTela,
                                'FechaAlta', tp.FechaAlta,
                                'FechaBaja', tp.FechaBaja,
                                'Estado', tp.Estado,
                                '_PrecioTotal', (upp.Precio + COALESCE(pr.LongitudTela, 0) * upt.Precio),
                                '_Cantidad', f_calcularStockProducto(tp.IdProductoFinal, 0)
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
                )
        )
	FROM tmp_ResultadosFinal tp
    INNER JOIN Productos pr ON (pr.IdProducto = tp.IdProducto)
    LEFT JOIN Telas te ON (te.IdTela = tp.IdTela)
    LEFT JOIN Lustres lu ON (lu.IdLustre = tp.IdLustre)
    INNER JOIN tmp_ultimosPreciosProductos upp ON (tp.IdProducto = upp.IdReferencia)
    LEFT JOIN tmp_ultimosPreciosTelas upt ON (tp.IdTela = upt.IdReferencia)
	);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_ProductosFinales;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    

END $$
DELIMITER ;

