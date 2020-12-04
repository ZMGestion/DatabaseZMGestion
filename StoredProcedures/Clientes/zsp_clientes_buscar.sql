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

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

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

    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

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

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    
    SET pNombresApellidos = COALESCE(pNombresApellidos,'');
    SET pRazonSocial = COALESCE(pRazonSocial,'');
    SET pEmail = COALESCE(pEmail,'');
    SET pDocumento = COALESCE(pDocumento,'');
    SET pTelefono = COALESCE(pTelefono,'');
    SET pTipo = COALESCE(pTipo,'');

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    CREATE TEMPORARY TABLE tmp_ResultadosTotal
    SELECT *
    FROM Clientes 
    WHERE 
        Email LIKE CONCAT(pEmail, '%') AND
        Documento LIKE CONCAT(pDocumento, '%') AND
        Telefono LIKE CONCAT(pTelefono, '%') AND
        IF (RazonSocial IS NULL, CONCAT(Apellidos,',',Nombres) LIKE CONCAT('%', pNombresApellidos, '%'), RazonSocial LIKE CONCAT(pRazonSocial, '%')) AND 
        (IdPais = pIdPais OR pIdPais = '**') AND
        (Tipo = pTipo OR pTipo = 'T') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY CONCAT(Apellidos, ' ', Nombres), RazonSocial;

    -- Para devolver el total en paginaciones
    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_ResultadosTotal);

    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * FROM tmp_ResultadosTotal
    LIMIT pOffset, pLongitudPagina;

    
	SET pRespuesta = (SELECT
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", JSON_ARRAYAGG(
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
        )
	FROM tmp_ResultadosFinal);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

END $$
DELIMITER ;

