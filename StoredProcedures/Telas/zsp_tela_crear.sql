DROP PROCEDURE IF EXISTS `zsp_tela_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_crear`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una tela. Control que no exista otra tela con el mismo nombre y que el precio sea mayor que cero.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pTela = pTelas ->> "$.Tela";
    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";

    IF pTela IS NULL OR pTela = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTela FROM Telas WHERE Tela = pTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Telas (IdTela, Tela, FechaAlta, FechaBaja, Observaciones, Estado) VALUES(0, pTela, NOW(), NULL, NULLIF(pObservaciones, ''), 'A');
    SET pIdTela = (SELECT IdTela FROM Telas WHERE Tela = pTela);
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'T', pIdTela, NOW());

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
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
