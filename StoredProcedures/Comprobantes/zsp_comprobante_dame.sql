DROP PROCEDURE IF EXISTS zsp_comprobante_dame;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instanciar un comprobante a partir de su Id.
        Devuelve el comprobante en 'respuesta' o el error en 'error'
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
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdComprobante = COALESCE(pComprobantes ->> "$.IdComprobante");

    IF NOT EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdComprobante = pIdComprobante) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

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
    
END $$
DELIMITER ;