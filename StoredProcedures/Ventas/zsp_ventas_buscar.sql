DROP PROCEDURE IF EXISTS zsp_ventas_buscar;
DELIMITER $$
CREATE PROCEDURE zsp_ventas_buscar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite buscar una venta
        - Usuario (0: Todos)
        - Cliente (0: Todos)
        - Estado (E:En Creación - C:Pendiente - R:En revisión - N: Entregado - A:Cancelado - T:Todos) //Revisar esto
        - Producto(0:Todos),
        - Telas(0:Todos),
        - Lustre (0: Todos),
        - Ubicación (0:Todas las ubicaciones)
        - Periodo de fechas
        Devuelve una lista de ventas en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pIdUsuario smallint;
    DECLARE pIdCliente int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pEstado char(1);

    -- Paginacion
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    -- Parametros busqueda
    DECLARE pFechaInicio datetime;
    DECLARE pFechaFin datetime;
    DECLARE pFechaAux datetime;

    -- Productos Final
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pResultado JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ventas_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Atributos ventas
    SET pIdCliente = COALESCE(pIn ->> "$.Ventas.IdCliente", 0);
    SET pIdUsuario = COALESCE(pIn ->> "$.Ventas.IdUsuario", 0);
    SET pIdUbicacion = COALESCE(pIn ->> "$.Ventas.IdUbicacion", 0);
    SET pEstado = TRIM(COALESCE(pIn ->> "$.Ventas.Estado", "T"));

    -- Atributos productos finales
    SET pIdProducto = COALESCE(pIn ->> "$.ProductosFinales.IdProducto", 0);
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela", 0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre", 0);

    -- Atributos paginaciones
    SET pPagina = COALESCE(pIn ->> '$.Paginaciones.Pagina', 1);
    SET pLongitudPagina = COALESCE(pIn ->> '$.Paginaciones.LongitudPagina', 0);

    -- Atributos parametros de busqueda
    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaInicio", '')) > 0 THEN
        SET pFechaInicio = pIn ->> "$.ParametrosBusqueda.FechaInicio";
    END IF;
    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaFin", '')) = 0 THEN
        SET pFechaFin = NOW();
    ELSE
        SET pFechaFin = pIn ->>"$.ParametrosBusqueda.FechaFin";
    END IF;

    -- Arreglo el orden de las fechas
    IF pFechaInicio IS NOT NULL AND pFechaFin < pFechaInicio THEN
        SET pFechaAux = pFechaInicio;
        SET pFechaInicio = pFechaFin;
        SET pFechaFin = pFechaAux;
    END IF;

    CALL zsp_usuario_tiene_permiso(pToken, 'buscar_ventas_ajenas', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        IF pIdUsuarioEjecuta <> pIdUsuario THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF pEstado NOT IN ('E', 'C', 'R', 'N', 'A','T') THEN
        SELECT f_generarRespuesta("ERROR_ESTADO_INVALIDO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT Valor FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;
    
    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_Ventas;
    DROP TEMPORARY TABLE IF EXISTS tmp_VentasPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ventasPrecios;
    
    -- Ventas que cumplen con las condiciones sin paginar
    CREATE TEMPORARY TABLE tmp_Ventas
    AS SELECT v.*
    FROM Ventas v
    LEFT JOIN LineasProducto lp ON (lp.IdReferencia = v.IdVenta AND lp.Tipo = 'V')
    LEFT JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
	WHERE (v.IdUsuario = pIdUsuario OR pIdUsuario = 0)
    AND (v.IdCliente = pIdCliente OR pIdCliente = 0)
    AND (v.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
    AND (
            f_calcularEstadoVenta(v.IdVenta) = pEstado
            OR pEstado = 'T'
        )
    AND ((pFechaInicio IS NULL AND v.FechaAlta <= pFechaFin) OR (pFechaInicio IS NOT NULL AND v.FechaAlta BETWEEN pFechaInicio AND pFechaFin))
    AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
    AND (pf.IdTela = pIdTela OR pIdTela = 0)
    AND (pf.IdLustre = pIdLustre OR pIdLustre = 0);
    
    -- Para devolver CantidadTotal en Paginaciones
    SET pCantidadTotal = (SELECT COUNT(DISTINCT IdVenta) FROM tmp_Ventas);
    
    -- Ventas paginadas
    CREATE TEMPORARY TABLE tmp_VentasPaginadas AS
    SELECT DISTINCT IdVenta, IdCliente, IdDomicilio,IdUbicacion, IdUsuario, FechaAlta, Observaciones, Estado
    FROM tmp_Ventas
    LIMIT pOffset, pLongitudPagina;


    -- Resultset de las ventas con sus montos totales
    CREATE TEMPORARY TABLE tmp_ventasPrecios AS
    SELECT  
		tmpv.*, 
        SUM(lp.Cantidad * lp.PrecioUnitario) AS PrecioTotal, 
        IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
			JSON_OBJECT(
                "LineasProducto",  
                    JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario
                    ),
                "ProductosFinales",
                    JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                "Productos",
                    JSON_OBJECT(
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
		), JSON_ARRAY()) AS LineasVenta
    FROM    tmp_VentasPaginadas tmpv
    LEFT JOIN LineasProducto lp ON tmpv.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
    LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
    LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
    LEFT JOIN Telas te ON pf.IdTela = te.IdTela
    LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
    GROUP BY tmpv.IdVenta, tmpv.IdCliente, tmpv.IdDomicilio, tmpv.IdUbicacion, tmpv.IdUsuario, tmpv.FechaAlta, tmpv.Observaciones, tmpv.Estado;

    SET pResultado = (SELECT 
        JSON_ARRAYAGG(
            JSON_OBJECT(
                "Ventas",  JSON_OBJECT(
                    'IdVenta', tmpv.IdVenta,
                    'IdCliente', tmpv.IdCliente,
                    'IdUbicacion', tmpv.IdUbicacion,
                    'IdUsuario', tmpv.IdUsuario,
                    'FechaAlta', tmpv.FechaAlta,
                    'Observaciones', tmpv.Observaciones,
                    'Estado', f_calcularEstadoVenta(tmpv.IdVenta),
                    '_PrecioTotal', tmpv.PrecioTotal
                ),
                "Clientes", JSON_OBJECT(
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasVenta", tmpv.LineasVenta
            )
        )
        FROM tmp_ventasPrecios tmpv
        INNER JOIN Clientes c ON tmpv.IdCliente = c.IdCliente
        INNER JOIN Usuarios u ON tmpv.IdUsuario = u.IdUsuario
        INNER JOIN Ubicaciones ub ON tmpv.IdUbicacion = ub.IdUbicacion
    );

    SET pRespuesta = JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", pResultado
    );
        
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_Ventas;
    DROP TEMPORARY TABLE IF EXISTS tmp_VentasPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ventasPrecios;
END $$
DELIMITER ;
