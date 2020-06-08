DROP PROCEDURE IF EXISTS `zsp_domicilio_crear`;
DELIMITER $$
CREATE PROCEDURE  `zsp_domicilio_crear` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite crear un domicilio y asociarlo a un cliente en caso de ser necesario. 
        Debe existir el la ciudad, provincia y pais.
        El cliente es opcional.
        Devuelve un json con el domicilio creado en respuesta o el codigo de error en error.
    */
    
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;
    DECLARE pDomicilios JSON;
    DECLARE pIdCiudad int;
    DECLARE pIdProvincia int;
    DECLARE pIdPais char(2);
    DECLARE pDomicilio varchar(120);
    DECLARE pCodigoPostal varchar(10);
    DECLARE pFechaAlta datetime;
    DECLARE pObservaciones varchar(255);
    DECLARE pIdDomicilio int;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_domicilio_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo el cliente
    SET pClientes = pIn ->> "$.Clientes";
    IF (pClientes IS NOT NULL) THEN
        SET pIdCliente = pClientes ->> "$.IdCliente";
        IF (pIdCliente IS NOT NULL AND NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente)) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;
    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdCiudad = pDomicilios ->> "$.IdCiudad";
    SET pIdProvincia = pDomicilios ->> "$.IdProvincia";
    SET pIdPais = pDomicilios ->> "$.IdPais";
    SET pDomicilio = pDomicilios ->> "$.Domicilio";
    SET pCodigoPostal = pDomicilios ->> "$.CodigoPostal";
    SET pFechaAlta = pDomicilios ->> "$.FechaAlta";
    SET pObservaciones = pDomicilios ->> "$.Observaciones";

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


    START TRANSACTION;
        SET pIdDomicilio = (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad);
        IF (pIdDomicilio IS NOT NULL) THEN
            IF (pIdCliente IS NOT NULL) THEN
                IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
                    INSERT INTO DomiciliosCliente VALUES (pIdDomicilio, pIdCliente, NOW());
                END IF;       
            ELSE
                SELECT f_generarRespuesta("ERROR_EXISTE_DOMICILIO", NULL) pOut;
                LEAVE SALIR;
                 
            END IF;
        ELSE
            INSERT INTO Domicilios (IdDomicilio,IdCiudad,IdProvincia,IdPais,Domicilio,CodigoPostal,FechaAlta,Observaciones) VALUES (0, pIdCiudad, pIdProvincia, pIdPais, pDomicilio, pCodigoPostal, NOW(), pObservaciones);
            SET pIdDomicilio = (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad);
            IF (pIdCliente IS NOT NULL) THEN
                INSERT INTO DomiciliosCliente VALUES (pIdDomicilio, pIdCliente, NOW());
            END IF;
        END IF;

        
        SET pRespuesta = (
        SELECT CAST(
				COALESCE(
					JSON_OBJECT(
						'IdDomicilio', IdDomicilio,
                        'IdCiudad', IdCiudad,
                        'IdProvincia', IdProvincia,
                        'IdPais', IdPais,
                        'Domicilio', Domicilio,
                        'CodigoPostal', CodigoPostal,
                        'FechaAlta', FechaAlta,
                        'Observaciones', Observaciones
					)
				,'') AS JSON)
        FROM	Domicilios
        WHERE	IdDomicilio = pIdDomicilio
    );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Domicilios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;

