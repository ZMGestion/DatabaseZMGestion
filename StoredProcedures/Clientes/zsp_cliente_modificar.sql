DROP PROCEDURE IF EXISTS `zsp_cliente_modificar`;
DELIMITER $$
CREATE PROCEDURE `zsp_cliente_modificar`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modificar un cliente existente controlando que no exista un cliente con el mismo email y tipo y número de documento. 
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
    

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo los datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";
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

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_CLIENTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

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

    IF EXISTS (SELECT IdCliente FROM Clientes WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento AND IdCliente <> pIdCliente) THEN
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

    IF EXISTS (SELECT Email FROM Clientes WHERE Email = pEmail AND IdCliente <> pIdCliente) THEN
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
        
        UPDATE Clientes
        SET IdPais = pIdPais,
            IdTipoDocumento = pIdTipoDocumento,
            Documento = pDocumento,
            Tipo = pTipo,
            FechaNacimiento = pFechaNacimiento,
            Nombres = pNombres,
            Apellidos = pApellidos,
            RazonSocial = pRazonSocial,
            Email = pEmail,
            Telefono = pTelefono
        WHERE IdCliente = pIdCliente;

        SET pClientes = (
            SELECT CAST(
                JSON_OBJECT(
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
                ) AS JSON)
        FROM	Clientes c
        WHERE	IdCliente = pIdCliente
    );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Clientes", pClientes)) AS pOut;
    COMMIT;
END $$
DELIMITER ;
