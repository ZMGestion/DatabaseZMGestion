DROP PROCEDURE IF EXISTS `zsp_tela_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_modificar`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una tela. Control que no exista otra tela con el mismo nombre.
        Devuelve un json con la tela y el precio en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;
    DECLARE pTela varchar(60);
    DECLARE pObservaciones varchar(255);

    -- Precio de la tela
    DECLARE pPrecios JSON;
    DECLARE pIdPrecio int;
    DECLARE pPrecio decimal(10,2);

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";
    SET pTela = pTelas ->> "$.Tela";
    

    IF pTela IS NULL OR pTela = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTela FROM Telas WHERE Tela = pTela AND IdTela <> pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";

    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    IF pPrecio <> (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        -- Si modificó el precio revisamos que pueda hacerlo y lo modificamos
        CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_modificar_precio', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;

        INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'T', pIdTela, NOW());

        SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;
    END IF;

    UPDATE Telas
    SET Tela = pTela,
        Observaciones = NULLIF(pObservaciones, '')
    WHERE IdTela = pIdTela;

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

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
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela AND p.IdPrecio = pIdPrecio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;

