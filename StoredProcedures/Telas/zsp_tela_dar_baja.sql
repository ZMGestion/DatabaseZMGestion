DROP PROCEDURE IF EXISTS `zsp_tela_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_dar_baja`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de baja una tela que se encontraba en estado "Alta". Controla que la tela exista
        Devuelve un json con la tela en respuesta o el error en error.
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
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Telas WHERE IdTela = pIdTela) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_TELA_ESTA_BAJA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Telas
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdTela = pIdTela;

            SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        )
                )
             AS JSON)
			FROM	Telas t
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;

END $$
DELIMITER ;

