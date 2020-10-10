DROP PROCEDURE IF EXISTS zsp_remito_crear;
DELIMITER $$
CREATE PROCEDURE zsp_remito_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite dar de alta un nuevo remito. Se crea en estado 'En Creacion'.
        Devuelve el remito creado en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdDomicilio int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pTipo char(1);
    DECLARE pObservaciones varchar(255);

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
  
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdDomicilio = COALESCE(pIn->>'$.Remitos.IdDomicilio', 0);
    SET pIdUbicacion = COALESCE(pIn->>'$.Remitos.IdUbicacion', 0);
    SET pIdUsuario = COALESCE(pIn->>'$.Remitos.IdUsuario', 0);
    SET pTipo = COALESCE(pIn->>'$.Remitos.Tipo', '');
    SET pObservaciones = pIn->>'$.Domicilios.Observaciones';

    IF pIdUbicacion = 0 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdDomicilio != 0  THEN
        IF NOT EXISTS(SELECT IdDomicilio FROM Domicilios WHERE IdDomicilio = pIdDomicilio) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF pTipo = '' OR NOT IN('E','S','X', 'Y') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Remitos (IdRemito, IdDomicilio, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, pIdDomicilio, pIdUbicacion, pIdUsuarioEjecuta, pTipo, NULL, NOW(), NULLIF(pObservaciones, ''), 'E');

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
			WHERE	IdRemito = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;