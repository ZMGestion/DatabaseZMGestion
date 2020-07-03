DROP PROCEDURE IF EXISTS`zsp_tela_listar_precios`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_listar_precios`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar el historico de precios de una tela.
        Devuelve una lista de precios en respuesta o el error en error.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Tela de la cual se desea conocer el historico de precios
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_listar_precios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "Precios",
            JSON_OBJECT(
                'IdPrecio', IdPrecio,
                'Precio', Precio,
                'FechaAlta', FechaAlta
            )
        )
    ) 
    FROM Precios 
    WHERE Tipo = 'T' AND IdReferencia = pIdTela
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

