DROP PROCEDURE IF EXISTS `zsp_permisos_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_permisos_listar`(pIn JSON)

SALIR:BEGIN
	/*
		Lista todos los permisos existentes y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;
    DECLARE pRespuesta TEXT;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_permisos_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

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

    DROP TEMPORARY TABLE IF EXISTS tmp_resultados;

    CREATE TEMPORARY TABLE tmp_resultados AS
    SELECT * FROM Permisos 
    ORDER BY Permiso
    LIMIT pOffset, pLongitudPagina; 

    -- Para devolver el total en paginaciones
    SET pCantidadTotal = (SELECT COUNT(*) FROM Permisos);

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_OBJECT(
                "Paginaciones", JSON_OBJECT(
                    "Pagina", pPagina,
                    "LongitudPagina", pLongitudPagina,
                    "CantidadTotal", pCantidadTotal
                ),
                "resultado", JSON_ARRAYAGG(
                JSON_OBJECT('Permisos',
                    JSON_OBJECT(
                        'IdPermiso', IdPermiso, 
                        'Permiso', Permiso,
                        'Procedimiento', Procedimiento,
                        'Descripcion', Descripcion
                    )
                )
            )
            )
        ,'')
	FROM tmp_resultados 
    ORDER BY Permiso);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultados;

END $$
DELIMITER ;

