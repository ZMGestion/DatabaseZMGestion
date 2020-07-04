DROP PROCEDURE IF EXISTS `zsp_tela_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar una tela. Controla que no este siendo utilizada por un ProductoFinal.
        Devuelve null en respuesta o el error en error.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL_TELA", NULL);
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        -- Para poder borrar en la tabla precios
        SET SQL_SAFE_UPDATES = 0;
        DELETE FROM Telas WHERE IdTela = pIdTela;
        DELETE FROM Precios WHERE Tipo = 'T' AND  IdReferencia = pIdTela;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
        SET SQL_SAFE_UPDATES = 1;
    COMMIT;
    
END $$
DELIMITER ;
