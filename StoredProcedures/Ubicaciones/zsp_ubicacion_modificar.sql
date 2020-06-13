DROP PROCEDURE IF EXISTS `zsp_ubicacion_modificar`;
DELIMITER $$
CREATE PROCEDURE  `zsp_ubicacion_modificar` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite modificar una ubicación y su domicilio. 
        Debe existir el la ciudad, provincia y pais. Controla que no exista el mismo domicilio en la misma ciudad.
        Devuelve un json con la ubicación y el domicilio modificado en respuesta o el codigo de error en error.
    */
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;

    -- Domicilio a modificar
    DECLARE pDomicilios JSON;
    DECLARE pIdDomicilio int;
    DECLARE pIdCiudad int;
    DECLARE pIdProvincia int;
    DECLARE pIdPais char(2);
    DECLARE pDomicilio varchar(120);
    DECLARE pCodigoPostal varchar(10);
    DECLARE pFechaAlta datetime;
    DECLARE pObservacionesDomicilio varchar(255);

    -- Ubicacion a modificar
    DECLARE pUbicaciones JSON;
    DECLARE pIdUbicacion tinyint;
    DECLARE pUbicacion varchar(40);
    DECLARE pObservacionesUbicacion varchar(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo el domicilio del JSON
    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdDomicilio = pDomicilios ->> "$.IdDomicilio";
    SET pIdCiudad = pDomicilios ->> "$.IdCiudad";
    SET pIdProvincia = pDomicilios ->> "$.IdProvincia";
    SET pIdPais = pDomicilios ->> "$.IdPais";
    SET pDomicilio = pDomicilios ->> "$.Domicilio";
    SET pCodigoPostal = pDomicilios ->> "$.CodigoPostal";
    SET pObservacionesDomicilio = pDomicilios ->> "$.Observaciones";

    -- Extraigo la ubicacion del JSON
    SET pUbicaciones = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicaciones ->> "$.IdUbicacion";
    SET pUbicacion = pUbicaciones ->> "$.Ubicacion";
    SET pObservacionesUbicacion = pUbicaciones ->> "$.Observaciones";

    IF NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pUbicacion IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE Ubicacion = pUbicacion AND IdUbicacion <> pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF (pIdPais IS NULL OR NOT EXISTS (SELECT IdPais FROM Paises WHERE IdPais = pIdPais)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PAIS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdProvincia IS NULL OR NOT EXISTS (SELECT IdProvincia FROM Provincias WHERE IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PROVINCIA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdCiudad IS NULL OR NOT EXISTS (SELECT IdCiudad FROM Ciudades WHERE IdCiudad = pIdCiudad AND IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CIUDAD", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pCodigoPostal IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_CP", NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF EXISTS (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad AND IdDomicilio <> pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_UBICACION_CIUDAD", NULL) pOut;
    END IF;



    START TRANSACTION;

        
        UPDATE Ubicaciones
        SET Ubicacion = pUbicacion,
            Observaciones = pObservacionesUbicacion
        WHERE IdUbicacion = pIdUbicacion;

        UPDATE Domicilios
        SET IdCiudad = pIdCiudad,
            IdProvincia = pIdProvincia,
            IdPais = pIdPais,
            Domicilio = pDomicilio,
            CodigoPostal = pCodigoPostal,
            Observaciones = pObservacionesDomicilio
        WHERE IdDomicilio = pIdDomicilio;

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
			WHERE	u.IdUbicacion = pIdUbicacion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
