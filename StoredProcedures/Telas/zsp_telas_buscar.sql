DROP PROCEDURE IF EXISTS `zsp_telas_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_telas_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar telas por su nombre y Estado (A:Activo - B:Baja - T:Todos)
        Devuelve un JSON con la lista de telas en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Tela de la cual se desea conocer el historico de precios
    DECLARE pTelas JSON;
    DECLARE pTela varchar(60);
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_telas_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTelas = pIn ->> "$.Telas";
    SET pTela = pTelas ->> "$.Tela";
    SET pEstado = pTelas ->> "$.Estado";

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

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

    SET pTela = COALESCE(pTela,'');

    DROP TEMPORARY TABLE IF EXISTS tmp_Telas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;    
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    -- Resultset completo
    CREATE TEMPORARY TABLE tmp_Telas 
    AS SELECT *
    FROM Telas 
    WHERE
	    Tela LIKE CONCAT(pTela, '%') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY Tela;
    
    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_Telas);

    -- Resultset paginado
    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * 
    FROM tmp_Telas
    LIMIT pOffset, pLongitudPagina;

    CREATE TEMPORARY TABLE tmp_preciosTelas AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'T' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPrecios AS
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
                        "Telas",
                        JSON_OBJECT(
                            'IdTela', tt.IdTela,
                            'Tela', tt.Tela,
                            'FechaAlta', tt.FechaAlta,
                            'FechaBaja', tt.FechaBaja,
                            'Observaciones', tt.Observaciones,
                            'Estado',tt.Estado
                        ),
                        "Precios",
                        JSON_OBJECT(
                            'IdPrecio', tps.IdPrecio,
                            'Precio', tps.Precio,
                            'FechaAlta', tps.FechaAlta
                        )
                    )
                )
        ) 
            

	FROM tmp_ResultadosFinal tt
    INNER JOIN tmp_ultimosPrecios tps ON (tps.Tipo = 'T' AND tt.IdTela = tps.IdReferencia)
	);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_Telas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

END $$
DELIMITER ;
