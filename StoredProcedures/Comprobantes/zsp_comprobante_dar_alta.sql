DROP PROCEDURE IF EXISTS zsp_comprobante_dar_alta;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_dar_alta(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite dar de alta un comprobante. Controla que este en estado 'Baja'.
        Devuelve el comprobante en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE pComprobantes JSON;
    DECLARE pIdComprobante int;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->>"$.Comprobantes";
    SET pIdComprobante = COALESCE(pComprobantes->>"$.IdComprobante", 0);

    IF NOT EXISTS(SELECT c.IdComprobante FROM Comprobantes c INNER JOIN Ventas v ON v.IdVenta = c.IdVenta WHERE c.IdComprobante = pIdComprobante AND v.Estado  = 'C' AND c.Estado = 'B') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;
        UPDATE Comprobantes
        SET Estado = 'A'
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
