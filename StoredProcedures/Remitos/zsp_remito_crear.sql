DROP PROCEDURE IF EXISTS zsp_remito_crear;
DELIMITER $$
CREATE PROCEDURE zsp_remito_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite dar de alta un nuevo remito. Se crea en estado 'En Creacion'.
        Devuelve el remito creado en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdUbicacion tinyint;
    DECLARE pTipo char(1);
    DECLARE pObservaciones varchar(255);

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
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdUbicacion = COALESCE(pIn->>'$.Remitos.IdUbicacion', 0);
    SET pTipo = COALESCE(pIn->>'$.Remitos.Tipo', '');
    SET pObservaciones = pIn->>'$.Domicilios.Observaciones';

    IF pTipo IN ('E', 'X') AND NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN('E','S','X', 'Y') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, NULLIF(pIdUbicacion, 0), pIdUsuarioEjecuta, pTipo, NULL, NOW(), NULLIF(pObservaciones, ''), 'E');

        SET pRespuesta = (
			SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    'IdRemito', r.IdRemito,
                    'IdUbicacion', r.IdUbicacion,
                    'IdUsuario', r.IdUsuario,
                    'Tipo', r.Tipo,
                    'FechaEntrega', r.FechaEntrega,
                    'FechaAlta', r.FechaAlta,
                    'Observaciones', r.Observaciones,
                    'Estado', r.Estado
                ),
                'Ubicaciones', IF(r.IdUbicacion IS NOT NULL,
                 JSON_OBJECT(
                    'IdUbicacion', u.IdUbicacion,
                    'Ubicacion', u.Ubicacion
                 ), 
                 NULL)
            )
			FROM	Remitos r
            LEFT JOIN Ubicaciones u ON u.IdUbicacion = r.IdUbicacion
			WHERE	IdRemito = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
