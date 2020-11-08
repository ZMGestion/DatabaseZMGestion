DROP PROCEDURE IF EXISTS `zsp_ordenesProduccion_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ordenesProduccion_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar una orden de producción por: 
        - Usuario (0: Todos)
        - Estado (E:En Creación - P:Pendiente - C:Cancelada - R:En Producción - V:Verificada - T:Todos)
        - IdUsuarioFabricante(0:Todos),
        - IdUsuarioRevisor(0:Todos),
        - Producto(0:Todos),
        - Telas(0:Todos),
        - Lustre (0: Todos),
        - Periodo de fechas
        Devuelve una lista de órdenes de producción en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Orden de producción a buscar
    DECLARE pIdUsuario SMALLINT;
    DECLARE pEstado CHAR(1);

    -- Paginacion
    DECLARE pPagina INT;
    DECLARE pLongitudPagina INT;
    DECLARE pCantidadTotal INT;
    DECLARE pOffset INT;

    -- Parametros busqueda
    DECLARE pParametrosBusqueda JSON;
    DECLARE pFechaInicio DATETIME;
    DECLARE pFechaFin DATETIME;

    -- Tareas
    DECLARE pIdUsuarioRevisor SMALLINT;
    DECLARE pIdUsuarioFabricante SMALLINT;

    -- Productos Final
    DECLARE pIdProducto INT;
    DECLARE pIdLustre TINYINT;
    DECLARE pIdTela SMALLINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pResultado JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn->>"$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta->>"$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenesProduccion_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la orden de producción
    SET pIdUsuario = COALESCE(pIn ->> "$.OrdenesProduccion.IdUsuario", 0);
    SET pEstado = COALESCE(pIn ->> "$.OrdenesProduccion.Estado", 'T');

    -- Extraigo atributos de tareas
    SET pIdUsuarioRevisor = COALESCE(pIn ->> "$.Tareas.IdUsuarioRevisor", 0);
    SET pIdUsuarioFabricante = COALESCE(pIn ->> "$.Tareas.IdUsuarioFabricante", 0);

    -- Extraigo atributos del producto final
    SET pIdProducto = COALESCE(pIn ->> "$.ProductosFinales.IdProducto", 0);
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela", 0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre", 0);

    -- Extraigo atributos de la paginacion
    SET pPagina = pIn ->> "$.Paginaciones.Pagina";
    SET pLongitudPagina = pIn ->> "$.Paginaciones.LongitudPagina";

    -- Extraigo atributos de los parámetros de busqueda
    SET pParametrosBusqueda = pIn ->>"$.ParametrosBusqueda";
    IF CHAR_LENGTH(COALESCE(pParametrosBusqueda ->>"$.FechaInicio", '')) > 0 THEN
        SET pFechaInicio = pParametrosBusqueda ->> "$.FechaInicio";
    END IF;
    IF CHAR_LENGTH(COALESCE(pParametrosBusqueda ->>"$.FechaFin", '')) = 0 THEN
        SET pFechaFin = NOW();
    ELSE
        SET pFechaFin = CONCAT(pParametrosBusqueda ->> "$.FechaFin"," 23:59:59");
    END IF;

    IF pEstado NOT IN ('E','P','C','R','V','T') THEN
		SET pEstado = 'T';
	END IF;

    IF COALESCE(pPagina, 0) < 1 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccion;
    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccionPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_lineasOrdenesProduccion;


    -- Órdenes de producción que cumplen con las condiciones
    CREATE TEMPORARY TABLE tmp_OrdenesProduccion
    AS SELECT op.IdOrdenProduccion AS IdOrdenProduccion
    FROM OrdenesProduccion op
    LEFT JOIN LineasProducto lp ON (lp.IdReferencia = op.IdOrdenProduccion AND lp.Tipo = 'O')
    LEFT JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
    LEFT JOIN Tareas t ON (t.IdLineaProducto = lp.IdLineaProducto)
	WHERE 
        (op.IdUsuario = pIdUsuario OR pIdUsuario = 0)
        AND (t.IdUsuarioFabricante = pIdUsuarioFabricante OR pIdUsuarioFabricante = 0)
        AND (t.IdUsuarioRevisor = pIdUsuarioRevisor OR pIdUsuarioRevisor = 0)
        AND (op.Estado = pEstado OR pEstado = 'T')
        AND ((pFechaInicio IS NULL AND op.FechaAlta <= pFechaFin) OR (pFechaInicio IS NOT NULL AND op.FechaAlta BETWEEN pFechaInicio AND pFechaFin))
        AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
        AND (pf.IdTela = pIdTela OR pIdTela = 0)
        AND (pf.IdLustre = pIdLustre OR pIdLustre = 0)
    ORDER BY op.IdOrdenProduccion DESC;

    SET pCantidadTotal = (SELECT COUNT(DISTINCT IdOrdenProduccion) FROM tmp_OrdenesProduccion);

    -- Órdenes de producción buscadas paginadas
    CREATE TEMPORARY TABLE tmp_OrdenesProduccionPaginadas AS
    SELECT DISTINCT IdOrdenProduccion
    FROM tmp_OrdenesProduccion
    ORDER BY IdOrdenProduccion DESC
    LIMIT pOffset, pLongitudPagina;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    -- Lineas de las órdenes de producción
    CREATE TEMPORARY TABLE tmp_lineasOrdenesProduccion AS
    SELECT  
		tmpp.IdOrdenProduccion,
        IF(COUNT(lp.IdLineaProducto) > 0, CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
            "LineasProducto",  
                JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad
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
                ), NULL),
            "Lustres",IF (lu.IdLustre  IS NOT NULL,
                JSON_OBJECT(
                    "IdLustre", lu.IdLustre,
                    "Lustre", lu.Lustre
                ), NULL)
        ) ORDER BY lp.Cantidad DESC),''), ']') AS JSON), NULL) AS LineasOrdenProduccion
    FROM    tmp_OrdenesProduccionPaginadas tmpp
    LEFT JOIN LineasProducto lp ON (lp.IdReferencia = tmpp.IdOrdenProduccion AND lp.Tipo = 'O')
    LEFT JOIN ProductosFinales pf ON pf.IdProductoFinal = lp.IdProductoFinal
    LEFT JOIN Productos pr ON pr.IdProducto = pf.IdProducto
    LEFT JOIN Telas te ON te.IdTela = pf.IdTela
    LEFT JOIN Lustres lu ON lu.IdLustre = pf.IdLustre
    GROUP BY tmpp.IdOrdenProduccion;

    SET pRespuesta = JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", (
                SELECT CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', op.IdOrdenProduccion,
                        'IdUsuario', op.IdUsuario,
                        'FechaAlta', op.FechaAlta,
                        'Observaciones', op.Observaciones,
                        'Estado', f_dameEstadoOrdenProduccion(op.IdOrdenProduccion)
                    ),
                    "Usuarios", JSON_OBJECT(
                        "Nombres", u.Nombres,
                        "Apellidos", u.Apellidos
                    ),
                    "LineasOrdenProduccion", tmpp.LineasOrdenProduccion
                ) ORDER BY op.FechaAlta DESC),''), ']') AS JSON)
                FROM tmp_lineasOrdenesProduccion tmpp
                INNER JOIN OrdenesProduccion op ON op.IdOrdenProduccion = tmpp.IdOrdenProduccion
                INNER JOIN Usuarios u ON op.IdUsuario = u.IdUsuario
            )
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccion;
    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccionPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_lineasOrdenesProduccion;
END $$
DELIMITER ;
