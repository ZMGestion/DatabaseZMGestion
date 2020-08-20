DROP PROCEDURE IF EXISTS `zsp_presupuestos_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuestos_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar un presupuesto por: 
        - Usuario (0: Todos)
        - Cliente (0: Todos)
        - Estado (E:En Creación - C:Creado - V:Vendido - X: Expirado -T:Todos)
        - Producto(0:Todos),
        - Telas(0:Todos),
        - Lustre (0: Todos),
        - Ubicación (0:Todas las ubicaciones)
        Devuelve una lista de presupuestos en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuesto a buscar
    DECLARE pPresupuestos JSON;
    DECLARE pIdCliente int;
    DECLARE pIdUsuario smallint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pFechaLimite datetime;
    DECLARE pEstado char(1);

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    -- Parametros busqueda
    DECLARE pParametrosBusqueda JSON;
    DECLARE pFechaInicio datetime;
    DECLARE pFechaFin datetime;

    -- Productos Final
    DECLARE pProductosFinales JSON;
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuestos_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdCliente = pPresupuestos ->> "$.IdCliente";
    SET pIdUsuario = pPresupuestos ->> "$.IdUsuario";
    SET pIdUbicacion = pPresupuestos ->> "$.IdUbicacion";
    SET pEstado = pPresupuestos ->> "$.Estado";

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    -- Extraigo atributos de los parametros de busqueda
    SET pParametrosBusqueda = pIn ->>"$.ParametrosBusqueda";
    SET pFechaInicio = pParametrosBusqueda ->> "$.FechaInicio";
    SET pFechaFin = pParametrosBusqueda ->> "$.FechaFin";

    CALL zsp_usuario_tiene_permiso(pToken, 'buscar_presupuestos_ajenos', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SET pIdUsuario = pIdUsuarioEjecuta;
    END IF;

    SET pIdCliente = COALESCE(pIdCliente, 0);
    SET pIdUbicacion = COALESCE(pIdUbicacion, 0);
    SET pIdUsuario = COALESCE(pIdUsuario, 0);
    SET pIdProducto = COALESCE(pIdProducto, 0);
    SET pIdTela = COALESCE(pIdTela, 0);
    SET pIdLustre = COALESCE(pIdLustre, 0);

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('C','E', 'V', 'X') THEN
		SET pEstado = 'T';
	END IF;

    IF pEstado = 'X' THEN
        SELECT(DATE_ADD(NOW(), INTERVAL -(SELECT Valor FROM Empresa WHERE Parametro = 'PERIODOVALIDEZ') DAY)) INTO pFechaLimite;
    END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_Presupuestos;
    DROP TEMPORARY TABLE IF EXISTS tmp_LineasPresupuesto;
    DROP TEMPORARY TABLE IF EXISTS tmp_PresupuestosLineasPresupuesto;
    DROP TEMPORARY TABLE IF EXISTS tmp_PresupuestosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmp_presupuestosPrecios;


    -- Presupuestos que cumplen con las condiciones
    CREATE TEMPORARY TABLE tmp_Presupuestos
    AS SELECT *
    FROM Presupuestos p
	WHERE (p.IdUsuario = pIdUsuario OR pIdUsuario = 0)
    AND (p.IdCliente = pIdCliente OR pIdCliente = 0)
    AND (p.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
    AND (p.Estado = pEstado OR pEstado = 'T')
    AND (p.FechaAlta <= pFechaLimite OR p.FechaAlta IS NOT NULL)
    AND (p.FechaAlta BETWEEN pFechaInicio AND pFechaFin OR (p.FechaAlta >= pFechaInicio) OR (p.FechaAlta <= pFechaFin) OR (pFechaInicio IS NULL AND pFechaFin IS NULL));
    
    -- Lineas de presupuesto que cumplen con las condiciones
    CREATE TEMPORARY TABLE tmp_LineasPresupuesto AS 
    SELECT lp.*
    FROM LineasProducto lp
    INNER JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
    WHERE lp.Tipo = 'P'
    AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
    AND (pf.IdTela = pIdTela OR pIdTela = 0)
    AND (pf.IdLustre = pIdLustre OR pIdLustre = 0);

    CREATE TEMPORARY TABLE tmp_PresupuestosLineasPresupuesto AS
    SELECT tmpp.*, tmplp.IdLineaProducto, tmplp.IdProductoFinal, tmplp.PrecioUnitario, tmplp.Cantidad
    FROM tmp_Presupuestos tmpp
    INNER JOIN tmp_LineasPresupuesto tmplp ON (tmpp.IdPresupuesto = tmplp.IdReferencia AND tmplp.Tipo = 'P');

    SET pCantidadTotal = (SELECT COUNT(DISTINCT IdPresupuesto) FROM tmp_PresupuestosLineasPresupuesto);

    -- Presupuestos buscados paginados
    CREATE TEMPORARY TABLE tmp_PresupuestosPaginados AS
    SELECT DISTINCT IdPresupuesto, IdCliente, IdVenta, IdUbicacion, IdUsuario, PeriodoValidez, FechaAlta, Observaciones, Estado
    FROM tmp_PresupuestosLineasPresupuesto
    LIMIT pOffset, pLongitudPagina;

    -- Resultset de los presupuestos con sus montos totales
    CREATE TEMPORARY TABLE tmp_presupuestosPrecios AS
    SELECT  tmpp.*, SUM(tmplpp.Cantidad * tmplpp.PrecioUnitario) AS PrecioTotal 
    FROM    tmp_PresupuestosPaginados tmpp
    INNER JOIN tmp_PresupuestosLineasPresupuesto tmplpp ON tmpp.IdPresupuesto = tmplpp.IdPresupuesto
    GROUP BY tmpp.IdPresupuesto, tmpp.IdCliente, tmpp.IdVenta, tmpp.IdUbicacion, tmpp.IdUsuario, tmpp.PeriodoValidez, tmpp.FechaAlta, tmpp.Observaciones, tmpp.Estado;

    SET pResultado = (SELECT 
        JSON_ARRAYAGG(
            JSON_OBJECT(
                "Presupuestos",  JSON_OBJECT(
                    'IdPresupuesto', tmpp.IdPresupuesto,
                    'IdCliente', tmpp.IdCliente,
                    'IdVenta', tmpp.IdVenta,
                    'IdUbicacion', tmpp.IdUbicacion,
                    'IdUsuario', tmpp.IdUsuario,
                    'PeriodoValidez', tmpp.PeriodoValidez,
                    'FechaAlta', tmpp.FechaAlta,
                    'Observaciones', tmpp.Observaciones,
                    'Estado', tmpp.Estado,
                    '_PrecioTotal', tmpp.PrecioTotal
                )
            )
        )
        FROM tmp_presupuestosPrecios tmpp
        GROUP BY tmpp.IdPresupuesto
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

    DROP TEMPORARY TABLE IF EXISTS tmp_Presupuestos;
    DROP TEMPORARY TABLE IF EXISTS tmp_LineasPresupuesto;
    DROP TEMPORARY TABLE IF EXISTS tmp_PresupuestosLineasPresupuesto;
    DROP TEMPORARY TABLE IF EXISTS tmp_PresupuestosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmp_presupuestosPrecios;

END $$
DELIMITER ;

