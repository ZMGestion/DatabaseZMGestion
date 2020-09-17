DROP PROCEDURE IF EXISTS zsp_comprobante_crear;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear un nuevo comprobante.
        No puede repetirse el Numero y Tipo de Comprobante.
        Devuelve el comprobante en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pComprobantes JSON;
    DECLARE pIdVenta int;
    DECLARE pTipo char(1);
    DECLARE pNumeroComprobante int;
    DECLARE pMonto decimal(10,2);
    DECLARE pObservaciones varchar(255);

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdVenta = COALESCE(pComprobantes ->> "$.IdVenta", 0);
    SET pTipo = COALESCE(pComprobantes ->> "$.Tipo", '');
    SET pNumeroComprobante = COALESCE(pComprobantes ->> "$.NumeroComprobante", 0);
    SET pMonto = COALESCE(pComprobantes ->> "$.Monto", 0.00);
    SET pObservaciones = pComprobantes ->> "$.Observaciones";

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'C') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN('A', 'B', 'N', 'M', 'R') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE NumeroComprobante = pNumeroComprobante AND Tipo = pTipo) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF pMonto <= 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_MONTO", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
        INSERT INTO Comprobantes (IdComprobante, IdVenta, IdUsuario, Tipo, NumeroComprobante, Monto, FechaAlta, FechaBaja, Observaciones, Estado) VALUES(0, pIdVenta, pIdUsuarioEjecuta, pTipo, pNumeroComprobante, pMonto, NOW(), NULL, pObservaciones, 'A');

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
            WHERE	IdComprobante = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;