DROP PROCEDURE IF EXISTS zsp_remitos_buscar;
DELIMITER $$
CREATE PROCEDURE zsp_remitos_buscar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite buscar remitos.
        Se pueden buscarlo a partir:
            -Rango de fechas en el cual fue creado
            -Ubicacion de entrada o salida del remito (0:Todas)
            -Rango de fecha en el que fue entregado
            -Estado del remito (E:"En Creacion", C:"Creado", N:"Cancelado", F:"Entregado", T:Todos)
            -Tipo de remito (E:"Entrada", S:"Salida", X:"Transformación Entrada", Y:"Transformación Salida", T:Todos)
            -Usuario que lo creo(0:Todos)
    */
    DECLARE pIdUbicacionEntrada tinyint;
    DECLARE pIdUsuario int;
    DECLARE pTipo char(1);
    DECLARE pEstado char(1);

    -- Lineas de remito
    DECLARE pIdUbicacionSalida tinyint;

    -- Producto final
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Paginacion
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    -- Parametros busqueda
    DECLARE pParametrosBusqueda JSON;
    DECLARE pFechaEntregaDesde date;
    DECLARE pFechaEntregaHasta date;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, "zsp_remitos_buscar", pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != "OK" THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdUsuario = COALESCE(pIn->>"$.Remitos.IdUsuario", 0);

    IF pIdUsuario != pIdUsuarioEjecuta THEN
        CALL zsp_usuario_tiene_permiso(pToken, "remitos_buscar_ajeno", pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != "OK" THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SET pTipo = COALESCE(pIn->>"$.Remitos.Tipo", "T");
    SET pEstado = COALESCE(pIn->>"$.Remitos.Estado", "T");
    SET pIdUbicacionEntrada = COALESCE(pIn->>"$.Remitos.IdUbicacion", 0);
    SET pIdUbicacionSalida = COALESCE(pIn->>"$.LineasProducto.IdUbicacion", 0);

    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaEntregaDesde", "")) > 0 THEN
        SET pFechaEntregaDesde = pIn ->> "$.ParametrosBusqueda.FechaEntregaDesde";
    END IF;
    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaEntregaHasta", "")) = 0 THEN
        SET pFechaEntregaHasta = NOW();
    ELSE
        SET pFechaEntregaHasta = pIn ->> "$.ParametrosBusqueda.FechaEntregaHasta";
    END IF;


    SET pIdProducto = COALESCE(pIn->>"$.ProductosFinales.IdProducto", 0);
    SET pIdLustre = COALESCE(pIn->>"$.ProductosFinales.IdLustre", 0);
    SET pIdTela = COALESCE(pIn->>"$.ProductosFinales.IdTela", 0);

    SET pPagina = COALESCE(pIn ->> "$.Paginaciones.Pagina", 1);
    SET pLongitudPagina = COALESCE(pIn ->> "$.Paginaciones.LongitudPagina", (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = "LONGITUDPAGINA"));

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultadosSinPaginar;
    DROP TEMPORARY TABLE IF EXISTS  tmp_resultadosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmpp_resultadoFinal;

    CREATE TEMPORARY TABLE tmp_resultadosSinPaginar
    AS SELECT DISTINCT(r.IdRemito)
    FROM Remitos r
    LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = "R"
    LEFT JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
    WHERE
        (r.IdUbicacion = pIdUbicacionEntrada OR pIdUbicacionEntrada = 0)
        AND (r.Tipo = pTipo OR pTipo = "T")
        AND (r.Estado = pEstado OR pEstado = "T")
        AND (r.IdUsuario = pIdUsuario OR pIdUsuario = 0)
        -- AND ((pFechaEntregaDesde IS NULL AND r.FechaEntrega <= pFechaEntregaHasta) OR (pFechaEntregaDesde IS NOT NULL AND r.FechaEntrega BETWEEN pFechaEntregaDesde AND pFechaEntregaHasta)) 
        AND (lp.IdUbicacion = pIdUbicacionSalida OR pIdUbicacionSalida = 0)
        AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
        AND (pf.IdTela = pIdTela OR pIdTela = 0)
        AND (pf.IdLustre = pIdLustre OR pIdLustre = 0)
    ORDER BY r.IdRemito DESC;

    SET pCantidadTotal = COALESCE((SELECT COUNT(DISTINCT IdRemito) FROM tmp_resultadosSinPaginar), 0);

    CREATE TEMPORARY TABLE tmp_resultadosPaginados
    AS SELECT IdRemito
    FROM tmp_resultadosSinPaginar
    LIMIT pOffset, pLongitudPagina;

    CREATE TEMPORARY TABLE  tmpp_resultadoFinal
    AS SELECT
        tmpp.IdRemito,
        IF(COUNT(lp.IdLineaProducto) > 0, 
            JSON_ARRAYAGG(
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
                    "Ubicaciones", JSON_OBJECT(
                        "Ubicacion", u.Ubicacion
                    ),
                    "Productos", JSON_OBJECT(
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
		    ), NULL
        ) AS LineasRemito
    FROM    tmp_resultadosPaginados tmpp
    LEFT JOIN LineasProducto lp ON tmpp.IdRemito = lp.IdReferencia AND lp.Tipo = "R"
    LEFT JOIN Ubicaciones u ON u.IdUbicacion = lp.IdUbicacion
    LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
    LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
    LEFT JOIN Telas te ON pf.IdTela = te.IdTela
    LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
    GROUP BY tmpp.IdRemito;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    SET pRespuesta = JSON_OBJECT(
        "Paginaciones", JSON_OBJECT(
            "Pagina", pPagina,
            "LongitudPagina", pLongitudPagina,
            "CantidadTotal", pCantidadTotal
        ),
        "resultado", (
            SELECT CAST(CONCAT("[", COALESCE(GROUP_CONCAT(JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    "IdRemito", r.IdRemito,
                    "IdUbicacion", r.IdUbicacion,
                    "IdUsuario", r.IdUsuario,
                    "Tipo", r.Tipo,
                    "FechaEntrega", r.FechaEntrega,
                    "FechaAlta", r.FechaAlta,
                    "Observaciones", r.Observaciones,
                    "Estado", f_calcularEstadoRemito(r.IdRemito)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasRemito", tmpp.LineasRemito
            )ORDER BY r.FechaAlta DESC),""), "]") AS JSON)
            FROM tmpp_resultadoFinal tmpp
            INNER JOIN Remitos r ON r.IdRemito = tmpp.IdRemito
            INNER JOIN Usuarios u ON r.IdUsuario = u.IdUsuario
            LEFT JOIN Ubicaciones ub ON r.IdUbicacion = ub.IdUbicacion
            ORDER BY r.FechaAlta DESC
        )    
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultadosSinPaginar;
    DROP TEMPORARY TABLE IF EXISTS  tmp_resultadosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmpp_resultadoFinal;
END $$
DELIMITER ;
