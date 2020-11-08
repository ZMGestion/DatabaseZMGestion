DROP PROCEDURE IF EXISTS zsp_remito_descancelar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_descancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite descancelar un remito. Controla que se encuentre cancelado.
        En caso de exito devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_descancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'B') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Remitos
        SET Estado = 'C'
        WHERE IdRemito = pIdRemito;

        SET pRespuesta = (
			SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    'IdRemito', IdRemito,
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
			WHERE	IdRemito = pIdRemito
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
