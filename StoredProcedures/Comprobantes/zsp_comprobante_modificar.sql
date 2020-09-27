DROP PROCEDURE IF EXISTS zsp_comprobante_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el numero, tipo y monto de un comprobante.
        No puede repetirse el Numero y Tipo de Comprobante.
        Devuelve el comprobante en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pComprobantes JSON;
    DECLARE pIdComprobante int;
    DECLARE pIdVenta int;
    DECLARE pTipo char(1);
    DECLARE pNumeroComprobante int;
    DECLARE pMonto decimal(10,2);
    DECLARE pObservaciones varchar(255);

    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdComprobante = COALESCE(pComprobantes ->> "$.IdComprobante");
    SET pTipo = COALESCE(pComprobantes ->> "$.Tipo", '');
    SET pNumeroComprobante = COALESCE(pComprobantes ->> "$.NumeroComprobante", 0);
    SET pMonto = COALESCE(pComprobantes ->> "$.Monto", 0.00);
    SET pObservaciones = pComprobantes ->> "$.Observaciones";

    IF NOT EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdComprobante = pIdComprobante) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN('A', 'B', 'N', 'M', 'R') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE NumeroComprobante = pNumeroComprobante AND Tipo = pTipo AND IdComprobante != pIdComprobante) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF pMonto <= 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_MONTO", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
        UPDATE Comprobantes
        SET NumeroComprobante = pNumeroComprobante,
            Tipo = pTipo,
            Monto = pMonto
        WHERE IdComprobante = pIdComprobante;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "Comprobantes",  JSON_OBJECT(
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
            AS JSON)
            FROM	Comprobantes
            WHERE	IdComprobante = pIdComprobante
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;