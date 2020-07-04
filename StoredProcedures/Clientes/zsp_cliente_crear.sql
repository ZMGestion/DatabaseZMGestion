DROP PROCEDURE IF EXISTS `zsp_cliente_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_cliente_crear`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario crear un cliente controlando que no exista un cliente con el mismo email y tipo y número de documento, tambien crea un Domicilio para dicho cliente. 
        Debe existir el  TipoDocumento y el pais de Nacionalidad.
        Tipo puede ser: F:Fisica o J:Jurídica
        En caso de ser una persona fisica tendra DNI, Pasaporte o Libreta Civica , nombre y apellido, 
        En caso de una persona jurídica tendra CUIT y RazonSocial
        Devuelve un json con el cliente creado en respuesta o el codigo de error en error.
    */
    
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;
    DECLARE pIdPais char(2);
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pTipo char(1);
    DECLARE pFechaNacimiento date;
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pRazonSocial varchar(60);
    DECLARE pEmail varchar(120);
    DECLARE pTelefono varchar(15);
    
    -- Domicilio
    DECLARE pDomicilios JSON;
    DECLARE pIdDomicilio int;

    -- Para la creacion del domicilio
    DECLARE pRespuesta JSON;
    DECLARE pInInterno JSON;



    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo los datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdPais = pClientes ->> "$.IdPais";
    SET pIdTipoDocumento = pClientes ->> "$.IdTipoDocumento";
    SET pDocumento = pClientes ->> "$.Documento";
    SET pTipo = pClientes ->> "$.Tipo";
    SET pFechaNacimiento = pClientes ->> "$.FechaNacimiento";
    SET pNombres = pClientes ->> "$.Nombres";
    SET pApellidos = pClientes ->> "$.Apellidos";
    SET pRazonSocial = pClientes ->> "$.RazonSocial";
    SET pTelefono = pClientes ->> "$.Telefono";
    SET pEmail = pClientes ->> "$.Email";

    SET pDomicilios = pIn ->> "$.Domicilios";
    
    IF (pIdPais IS NULL OR NOT EXISTS (SELECT IdPais FROM Paises WHERE IdPais = pIdPais)) THEN
        SElECT f_generarRespuesta("ERROR_NOEXISTE_PAIS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TIPODOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN ('F', 'J') THEN
        SELECT f_generarRespuesta('ERROR_INVALIDO_TIPOPERSONA', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'J' AND pIdTipoDocumento <> (SELECT Valor FROM Empresa WHERE Parametro = 'IDTIPODOCUMENTOCUIT') THEN
        SELECT f_generarRespuesta("ERROR_TIPODOCUMENTO_JURIDICA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'J' AND ( pRazonSocial = '' OR pRazonSocial IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_RAZONSOCIAL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_DOCUMENTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdCliente FROM Clientes WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_CLIENTE_TIPODOC_DOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pFechaNacimiento IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_FECHANACIMIENTO', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pTipo = 'F' AND (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_NOMBRE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'F' AND (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_APELLIDO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELEFONO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Clientes WHERE Email = pEmail) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'F' AND (pRazonSocial IS NOT NULL OR pRazonSocial = '') THEN
            SET pRazonSocial = NULL;
    END IF;

    IF pTipo = 'J' AND (pNombres IS NOT NULL OR pApellidos IS NOT NULL)   THEN
            SET pNombres = NULL;
            SET pApellidos = NULL;
    END IF;

    START TRANSACTION;
        
        INSERT INTO Clientes (IdCliente,IdPais,IdTipoDocumento,Documento,Tipo,FechaNacimiento,Nombres,Apellidos,RazonSocial,Email,Telefono,FechaAlta,FechaBaja,Estado) VALUES (0, pIdPais, pIdTipoDocumento, pDocumento, pTipo, pFechaNacimiento, pNombres, pApellidos, pRazonSocial, pEmail, pTelefono, NOW(), NULL, 'A');
        SET pIdCliente = (SELECT IdCliente FROM Clientes WHERE Email = pEmail);
        
        SET pInInterno = JSON_OBJECT("Domicilios", pDomicilios, "Clientes", JSON_OBJECT("IdCliente", pIdCliente));
        -- Armar el JSON para crear el domicilio para el cliente recien creado.
        CALL zsp_domicilio_crear_comun(pInInterno, pIdDomicilio, pRespuesta);

        IF pIdDomicilio IS NULL THEN
            SELECT pRespuesta pOut;
            LEAVE SALIR;
        END IF;
        SET pDomicilios = (
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

        SET pRespuesta = (
            SELECT CAST(
                    JSON_OBJECT(
                        "Clientes", JSON_OBJECT(
                            'IdCliente', c.IdCliente,
                            'IdPais', c.IdPais,
                            'IdTipoDocumento', c.IdTipoDocumento,
                            'Documento', c.Documento,
                            'Tipo', c.Tipo,
                            'FechaNacimiento', c.FechaNacimiento,
                            'Nombres', c.Nombres,
                            'Apellidos', c.Apellidos,
                            'RazonSocial', c.RazonSocial,
                            'Email', c.Email,
                            'Telefono', c.Telefono,
                            'FechaAlta', c.FechaAlta,
                            'FechaBaja', c.FechaBaja,
                            'Estado', c.Apellidos
                            ),
                        "Domicilios", pDomicilios) 
                AS JSON)
        FROM	Clientes c
        WHERE	IdCliente = pIdCliente
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
