DROP PROCEDURE IF EXISTS zsp_remito_entregar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_entregar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite entregar un remito. Controla que tenga lineas y setea la fecha de entrega en caso de recibirla.
        Devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;
    DECLARE pFechaEntrega datetime;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_entregar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);
    SET pFechaEntrega = COALESCE(pIn->>'$.Remitos.FechaEntrega', NOW());

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdReferencia = pIdRemito AND Tipo = 'R') THEN
        SELECT f_generarRespuesta("ERROR_SINLINEAS_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'C' AND FechaEntrega IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_NOCREADO_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Remitos
        SET FechaEntrega = pFechaEntrega
        WHERE IdRemito = pIdRemito;

        SET pRespuesta = (
			SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    'IdRemito', IdRemito,
                    'IdDomicilio', IdDomicilio,
                    'IdUbicacion', IdUbicacion,
                    'IdUsuario', IdUsuario,
                    'Tipo', Tipo,
                    'FechaEntrega', FechaEntrega,
                    'FechaAlta', FechaAlta,
                    'Observaciones', Observaciones,
                    'Estado', Estado
                ) 
            )
			FROM	Remitos
			WHERE	IdRemito = pIdRemito;
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;  
END $$
DELIMITER ;