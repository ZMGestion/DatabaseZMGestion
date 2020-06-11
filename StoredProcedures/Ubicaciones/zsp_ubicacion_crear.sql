DROP PROCEDURE IF EXISTS `zsp_ubicacion_crear`;
DELIMITER $$
CREATE PROCEDURE  `zsp_ubicacion_crear` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite crear una ubicación, crea el domicilio primero. 
        Llama al zsp_domicilio_crear
        Devuelve un json con la ubicación y el domicilio creados en respuesta o el codigo de error en error.
    */
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    -- Domicilio creado
    DECLARE pIdDomicilio int;
    -- Ubicacion a crear
    DECLARE pUbicaciones JSON;
    DECLARE pUbicacion varchar(40);
    DECLARE pObservacionesUbicacion varchar(255);

    -- 
    DECLARE pRespuestaSP JSON;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo el domicilio del JSON
    -- SET pDomicilios = pIn ->> "$.Domicilios";
    -- SET pIdCiudad = pDomicilios ->> "$.IdCiudad";
    -- SET pIdProvincia = pDomicilios ->> "$.IdProvincia";
    -- SET pIdPais = pDomicilios ->> "$.IdPais";
    -- SET pDomicilio = pDomicilios ->> "$.Domicilio";
    -- SET pCodigoPostal = pDomicilios ->> "$.CodigoPostal";
    -- SET pObservacionesDomicilio = pDomicilios ->> "$.Observaciones";

    -- Extraigo la ubicacion del JSON
    SET pUbicaciones = pIn ->> "$.Ubicaciones";
    SET pUbicacion = pUbicaciones ->> "$.Ubicacion";
    SET pObservacionesUbicacion = pUbicaciones ->> "$.Observaciones";

    IF pUbicacion IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE Ubicacion = pUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF; 


    START TRANSACTION;
        
        CALL zsp_domicilio_crear_comun(pIn, pIdDomicilio, pRespuestaSP);

        IF pIdDomicilio IS NULL THEN
            SELECT pRespuestaSP pOut;
            LEAVE SALIR;
        END IF;

        INSERT INTO Ubicaciones (IdUbicacion, IdDomicilio, Ubicacion, FechaAlta, FechaBaja, Observaciones, Estado) VALUES (0, pIdDomicilio, pUbicacion, NOW(), NULL, NULLIF(pObservacionesUbicacion, ''), 'A');

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', u.IdUbicacion,
                        'IdDomicilio', u.IdDomicilio,
                        'Ubicacion', u.Ubicacion,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Observaciones', u.Observaciones,
                        'Estado', u.Estado
                        ),
                    "Domicilios", JSON_OBJECT(
                        'IdDomicilio', d.IdDomicilio,
                        'IdCiudad', d.IdCiudad,
                        'IdProvincia', d.IdProvincia,
                        'IdPais', d.IdPais,
                        'Domicilio', d.Domicilio,
                        'CodigoPostal', d.CodigoPostal,
                        'FechaAlta', d.FechaAlta,
                        'Observaciones', d.Observaciones
                    ) 
                )
             AS JSON)
			FROM	Ubicaciones u
            INNER JOIN Domicilios d USING(IdDomicilio)
			WHERE	u.IdDomicilio = pIdDomicilio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
