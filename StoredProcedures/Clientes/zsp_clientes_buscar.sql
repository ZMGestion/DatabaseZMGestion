DROP PROCEDURE IF EXISTS `zsp_clientes_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_clientes_buscar` (pIn JSON)
SALIR: BEGIN
	/*
		Permite buscar los clientes por una cadena, o bien, nombres y apellidos, razon social, email, documento, telefono,
        Tipo de persona (F:Fisica - J:Juridica - T:Todos), estado (A:Activo - B:Baja - T:Todos), pais (**: Todos), 
	*/

   -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdPais char(2);
    DECLARE pDocumento varchar(15);
    DECLARE pTipo char(1);
    DECLARE pEstado char(1);
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pRazonSocial varchar(60);
    DECLARE pEmail varchar(120);
    DECLARE pTelefono varchar(15);
    DECLARE pNombresApellidos varchar(90);

    DECLARE pRespuesta JSON;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_clientes_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pClientes = pIn ->> "$.Clientes";
    SET pIdPais = pClientes ->> "$.IdPais";
    SET pDocumento = pClientes ->> "$.Documento";
    SET pTipo = pClientes ->> "$.Tipo";
    SET pEstado = pClientes ->> "$.Estado";
    SET pNombres = pClientes ->> "$.Nombres";
    SET pApellidos = pClientes ->> "$.Apellidos";
    SET pRazonSocial = pClientes ->> "$.RazonSocial";
    SET pTelefono = pClientes ->> "$.Telefono";
    SET pEmail = pClientes ->> "$.Email";

    SET pNombres = COALESCE(pNombres,'');
    SET pApellidos = COALESCE(pApellidos,'');
    SET pNombresApellidos = CONCAT(pNombres, pApellidos);


    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pTipo IS NULL OR pTipo = '' OR pTipo NOT IN ('F','J') THEN
		SET pTipo = 'T';
	END IF;

    IF pIdPais IS NULL OR pIdPais = '' THEN
        SET pIdPais = '**';
    END IF;

    
    SET pNombresApellidos = COALESCE(pNombresApellidos,'');
    SET pRazonSocial = COALESCE(pRazonSocial,'');
    SET pEmail = COALESCE(pEmail,'');
    SET pDocumento = COALESCE(pDocumento,'');
    SET pTelefono = COALESCE(pTelefono,'');
    SET pTipo = COALESCE(pTipo,'');
    
	SET pRespuesta = (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Clientes",
                    JSON_OBJECT(
						'IdCliente', IdCliente,
                        'IdPais', IdPais,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Tipo', Tipo,
                        'FechaNacimiento', FechaNacimiento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'RazonSocial', RazonSocial,
                        'Email', Email,
                        'Telefono', Telefono,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
                )
            )

	FROM Clientes 
	WHERE	
        IF (Nombres IS NULL AND Apellidos IS NULL, TRUE, CONCAT(Apellidos,',',Nombres) LIKE CONCAT('%', pNombresApellidos, '%')) AND
        Email LIKE CONCAT(pEmail, '%') AND
        Documento LIKE CONCAT(pDocumento, '%') AND
        Telefono LIKE CONCAT(pTelefono, '%') AND
        IF (RazonSocial IS NULL, TRUE, RazonSocial LIKE CONCAT(pRazonSocial, '%')) AND 
        (IdPais = pIdPais OR pIdPais = '**') AND
        (Tipo = pTipo OR pTipo = 'T') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY CONCAT(Apellidos, ' ', Nombres), RazonSocial);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;



END $$
DELIMITER ;

