DROP PROCEDURE IF EXISTS zsp_comprobante_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar un comprobante.
        Controla que la venta este en estado 'C'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdComprobante int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdComprobante = COALESCE(pIn ->>'$.Comprobantes.IdComprobante');

    IF NOT EXISTS(SELECT c.IdComprobante FROM Comprobantes c INNER JOIN Ventas v ON v.IdVenta = c.IdVenta WHERE c.IdComprobante = pIdComprobante AND v.Estado = 'C') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM Comprobantes
        WHERE IdComprobante = pIdComprobante;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
    
END $$
DELIMITER ;