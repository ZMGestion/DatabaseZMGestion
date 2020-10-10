DROP PROCEDURE IF EXISTS zsp_remito_pasar_a_creado;
DELIMITER $$
CREATE PROCEDURE zsp_remito_pasar_a_creado(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento quer permite pasar un remito a 'Creado'.
        Controla que este en estado 'En Creacion' y que tenga al menos una linea de remito.
        Devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_pasar_a_creado', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'E') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdReferencia = pIdRemito AND Tipo = 'R') THEN
        SELECT f_generarRespuesta("ERROR_SINLINEAS_REMITO", NULL) pOut;
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