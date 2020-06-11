DROP PROCEDURE IF EXISTS `zsp_domicilio_crear_comun`;

DELIMITER $$
CREATE PROCEDURE `zsp_domicilio_crear_comun`(pIn JSON, OUT pIdDomicilio int, OUT pOut JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un domicilio y asociarlo a un cliente en caso de ser necesario. 
        Debe existir el la ciudad, provincia y pais. Controla que no exista el mismo domicilio en la misma ciudad.
        El cliente es opcional.
        Devuelve el Id del domicilio o el error en pOut.
    */
    
    -- Domicilio
    DECLARE pDomicilios JSON;
    DECLARE pIdCiudad int;
    DECLARE pIdProvincia int;
    DECLARE pIdPais char(2);
    DECLARE pDomicilio varchar(120);
    DECLARE pCodigoPostal varchar(10);
    DECLARE pObservaciones varchar(255);

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET pOut = f_generarRespuesta("ERROR_TRANSACCION", NULL);
        SET pIdDomicilio = NULL;
        ROLLBACK;
	END;

    -- Extraigo datos del Domicilio a crear
    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdCiudad = pDomicilios ->> "$.IdCiudad";
    SET pIdProvincia = pDomicilios ->> "$.IdProvincia";
    SET pIdPais = pDomicilios ->> "$.IdPais";
    SET pDomicilio = pDomicilios ->> "$.Domicilio";
    SET pCodigoPostal = pDomicilios ->> "$.CodigoPostal";
    SET pObservaciones = pDomicilios ->> "$.Observaciones";

    -- Extraigo datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";

    IF (pIdCliente IS NOT NULL AND NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pIdPais IS NULL OR NOT EXISTS (SELECT IdPais FROM Paises WHERE IdPais = pIdPais)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_PAIS", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pIdProvincia IS NULL OR NOT EXISTS (SELECT IdProvincia FROM Provincias WHERE IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_PROVINCIA", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pIdCiudad IS NULL OR NOT EXISTS (SELECT IdCiudad FROM Ciudades WHERE IdCiudad = pIdCiudad AND IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_CIUDAD", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pCodigoPostal IS NULL) THEN
        SET pOut = f_generarRespuesta("ERROR_INGRESAR_CP", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad) THEN
        SET pOut = f_generarRespuesta("ERROR_EXISTE_UBICACION_CIUDAD", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;


    START TRANSACTION;
        SET pIdDomicilio = (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad);
        -- En caso que el domicilio exista y el cliente no sea null, lo asocia al cliente con el domicilio
        IF (pIdDomicilio IS NOT NULL) THEN
            IF (pIdCliente IS NOT NULL) THEN
                IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
                    INSERT INTO DomiciliosCliente VALUES (pIdDomicilio, pIdCliente, NOW());
                    SET pOut = NULL;
                END IF;       
            ELSE
                SET pOut = f_generarRespuesta("ERROR_EXISTE_DOMICILIO", NULL);
                 
            END IF;
        -- Si el domicilio no existe lo crea y lo asocia al cliente en caso de ser necesario
        ELSE
            INSERT INTO Domicilios (IdDomicilio,IdCiudad,IdProvincia,IdPais,Domicilio,CodigoPostal,FechaAlta,Observaciones) VALUES (0, pIdCiudad, pIdProvincia, pIdPais, pDomicilio, pCodigoPostal, NOW(), pObservaciones);
            SET pIdDomicilio = (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad);
            IF (pIdCliente IS NOT NULL) THEN
                INSERT INTO DomiciliosCliente VALUES (pIdDomicilio, pIdCliente, NOW());
            END IF;
            SET pOut = NULL;
        END IF;

    COMMIT;

END $$
DELIMITER ;
