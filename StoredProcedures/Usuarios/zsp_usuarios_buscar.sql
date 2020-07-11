DROP PROCEDURE IF EXISTS `zsp_usuarios_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuarios_buscar`(pIn JSON)
SALIR: BEGIN
	/*
		Permite buscar los usuarios por una cadena, o bien, por sus nombres y apellidos, nombre de usuario, email, documento, telefono,
        estado civil (C:Casado - S:Soltero - D:Divorciado - T:Todos), estado (A:Activo - B:Baja - T:Todos), rol (0:Todos los roles),
        ubicacion en la que trabaja (0:Todas las ubicaciones) y si tiene hijos o no (S:Si - N:No - T:Todos).
	*/

    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;

    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuario smallint;
    DECLARE pToken varchar(256);
    DECLARE pIdRol tinyint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pNombres varchar(60);
    DECLARE pApellidos varchar(60);
    DECLARE pEstadoCivil char(1);
    DECLARE pTelefono varchar(15);
    DECLARE pEmail varchar(120);
    DECLARE pCantidadHijos tinyint;
    DECLARE pUsuario varchar(40);
    DECLARE pPassword varchar(255);
    DECLARE pFechaNacimiento date;
    DECLARE pFechaInicio date;
    DECLARE pNombresApellidos varchar(120);
    DECLARE pEstado char(1);
    DECLARE pTieneHijos char(1);

    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pOffset int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuarios_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pIdUbicacion = pUsuarios ->> "$.IdUbicacion";
    SET pIdTipoDocumento = pUsuarios ->> "$.IdTipoDocumento";
    SET pDocumento = pUsuarios ->> "$.Documento";
    SET pNombres = pUsuarios ->> "$.Nombres";
    SET pApellidos = pUsuarios ->> "$.Apellidos";
    SET pEstadoCivil = pUsuarios ->> "$.EstadoCivil";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pTelefono = pUsuarios ->> "$.Telefono";
    SET pEmail = pUsuarios ->> "$.Email";
    SET pCantidadHijos = pUsuarios ->> "$.CantidadHijos";
    SET pPassword = pUsuarios ->> "$.Password";
    SET pUsuario = pUsuarios ->> "$.Usuario";
    SET pFechaNacimiento = pUsuarios ->> "$.FechaNacimiento";
    SET pFechaInicio = pUsuarios ->> "$.FechaInicio";
    SET pEstado = pUsuarios ->> "$.Estado";
    SET pNombresApellidos = CONCAT(pNombres, pApellidos);

    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";


    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pEstadoCivil IS NULL OR pEstadoCivil = '' OR pEstadoCivil NOT IN ('C','S','D') THEN
		SET pEstadoCivil = 'T';
	END IF;

    -- IF pTieneHijos IS NULL OR pTieneHijos = '' OR pTieneHijos NOT IN ('S','N') THEN
		SET pTieneHijos = 'T';
	-- END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;
    
    SET pNombresApellidos = COALESCE(pNombresApellidos,'');
    SET pUsuario = COALESCE(pUsuario,'');
    SET pEmail = COALESCE(pEmail,'');
    SET pDocumento = COALESCE(pDocumento,'');
    SET pTelefono = COALESCE(pTelefono,'');
    SET pIdRol = COALESCE(pIdRol,0);
    SET pIdUbicacion = COALESCE(pIdUbicacion,0);
    
	SET pRespuesta = (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Usuarios",
                    JSON_OBJECT(
						'IdUsuario', IdUsuario,
                        'IdRol', IdRol,
                        'IdUbicacion', IdUbicacion,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'EstadoCivil', EstadoCivil,
                        'Telefono', Telefono,
                        'Email', Email,
                        'CantidadHijos', CantidadHijos,
                        'Usuario', Usuario,
                        'FechaUltIntento', FechaUltIntento,
                        'FechaNacimiento', FechaNacimiento,
                        'FechaInicio', FechaInicio,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Estado', u.Estado
					),
                    "Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol,
                        'Rol', Rol
					),
                    "Ubicaciones",
                    JSON_OBJECT(
                        'IdUbicacion', IdUbicacion,
                        'Ubicacion', Ubicacion
					)
                )
            )

	FROM		Usuarios u
	INNER JOIN	Roles r USING (IdRol)
    INNER JOIN	Ubicaciones USING (IdUbicacion)
	WHERE		IdRol IS NOT NULL AND 
				(
                    CONCAT(Apellidos,',',Nombres) LIKE CONCAT('%', pNombresApellidos, '%') AND
                    Usuario LIKE CONCAT(pUsuario, '%') AND
                    Email LIKE CONCAT(pEmail, '%') AND
                    Documento LIKE CONCAT(pDocumento, '%') AND
                    Telefono LIKE CONCAT(pTelefono, '%')
				) AND 
                (IdRol = pIdRol OR pIdRol = 0) AND
                (IdUbicacion = pIdUbicacion OR pIdUbicacion = 0) AND
                (u.Estado = pEstado OR pEstado = 'T') AND
                (u.EstadoCivil = pEstadoCivil OR pEstadoCivil = 'T') AND
                IF(pTieneHijos = 'S', u.CantidadHijos > 0, IF(pTieneHijos = 'N', u.CantidadHijos = 0, pTieneHijos = 'T'))
	ORDER BY	CONCAT(Apellidos, ' ', Nombres), Usuario
    LIMIT pOffset, pLongitudPagina
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;

