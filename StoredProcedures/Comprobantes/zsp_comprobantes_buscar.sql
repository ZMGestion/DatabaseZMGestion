DROP PROCEDURE IF EXISTS zsp_comprobantes_buscar;
DELIMITER $$
CREATE PROCEDURE zsp_comprobantes_buscar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite buscar un comprobante a partir de:
            - Venta a la cual pertenece (0: Todas)
            - Usuario (0: Todos)
            - Numero (0: Todos)
            - Tipo de comprobante (A: Factura A, B: Factura B, N: Nota de Credito A, M: Nota de Credito B, R: Recibo, T:Todos).
        Devuelve el comporbante en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pComprobantes JSON;
    DECLARE pIdVenta int;
    DECLARE pIdUsuario smallint;
    DECLARE pTipo char(1);
    DECLARE pNumeroComprobante int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobantes_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdVenta = COALESCE(pComprobantes ->> "$.IdVenta", 0);
    SET pIdUsuario = COALESCE(pComprobantes ->> "$.IdUsuario", 0);
    SET pTipo = COALESCE(pComprobantes ->> "$.Tipo", 'T');
    SET pNumeroComprobante = COALESCE(pComprobantes ->> "$.NumeroComprobante", 0);

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantes;
    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantesPaginados;

    CREATE TEMPORARY TABLE tmp_comprobantes AS
    SELECT *
    FROM Comprobantes 
    WHERE 
    (
        IdUsuario = pIdUsuario OR pIdUsuario = 0
        IdVenta = pIdVenta OR pIdVenta = 0
        Tipo = pTipo OR pTipo = 'T'
        NumeroComprobante = pNumeroComprobante OR pNumeroComprobante = 0
    );

    CREATE TEMPORARY TABLE  tmp_comprobantesPaginados AS
    SELECT * 
    FROM tmp_comprobantes
    LIMIT pOffset, pLongitudPagina;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                    "Pagina", pPagina,
                    "LongitudPagina", pLongitudPagina,
                    "CantidadTotal", pCantidadTotal
            ),
            'Comprobantes', JSON_ARRAYAGG(
                JSON_OBJECT(
                    'IdComprobante', IdComprobante,
                    'IdVenta', IdVenta,
                    'IdUsuario', IdUsuario,
                    'Tipo', Tipo,
                    'NumeroComprobante', NumeroComprobante,
                    'Monto', Monto,
                    'FechaAlta', FechaAlta,
                    'FechaBaja', FechaBaja,
                    'Observaciones', Observaciones,
                    'Estado', Estado
                )
            )
        )
        FROM tmp_comprobantesPaginados
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantes;
    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantesPaginados;

END $$
DELIMITER ;