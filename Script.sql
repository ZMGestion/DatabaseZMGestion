DROP FUNCTION IF EXISTS `f_dameUltimoPrecio`;
DELIMITER $$
CREATE FUNCTION `f_dameUltimoPrecio`(pTipo char(1), pIdReferencia int) RETURNS int
    READS SQL DATA
BEGIN
    DECLARE pIdPrecio int;

    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTela;
    
    CREATE TEMPORARY TABLE tmp_preciosTela AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = pTipo GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPrecios AS
    SELECT pr.* 
    FROM tmp_preciosTela tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pIdPrecio = (SELECT tmp.IdPrecio FROM tmp_ultimosPrecios tmp WHERE tmp.IdReferencia = pIdReferencia);

    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTela;

    RETURN pIdPrecio;
END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_generarRespuesta`;
DELIMITER $$
CREATE FUNCTION `f_generarRespuesta`(pCodigoError varchar(255), pRespuesta JSON) RETURNS JSON
    DETERMINISTIC
BEGIN
    RETURN JSON_OBJECT("error", pCodigoError, "respuesta", pRespuesta);
END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_split`;
DELIMITER $$
CREATE FUNCTION `f_split`(pCadena longtext, pDelimitador varchar(10), pIndice int) RETURNS text CHARSET utf8
    DETERMINISTIC
BEGIN
	
	RETURN	REPLACE(
				SUBSTR(
					SUBSTRING_INDEX(pCadena, pDelimitador, pIndice),
					CHAR_LENGTH(SUBSTRING_INDEX(pCadena, pDelimitador, pIndice -1)) + 1
				),
				pDelimitador, ''
			);
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ciudades_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ciudades_listar` (pIn JSON)
SALIR: BEGIN
    /*
        Permite listar todas las ciudades de una provincia y un pais particular.
    */

    DECLARE pProvincias JSON;
    DECLARE pIdPais char(2);
    DECLARE pIdProvincia int;
    DECLARE pRespuesta JSON;

    SET pProvincias = pIn ->> "$.Provincias";
    SET pIdPais = pProvincias ->> "$.IdPais";
    SET pIdProvincia = pProvincias ->> "$.IdProvincia";

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            "Ciudades",
            JSON_OBJECT(
                'IdCiudad', c.IdCiudad,
                'Ciudad', c.Ciudad
            )
        )
    ) 
    FROM Ciudades c
    WHERE IdPais = pIdPais AND IdProvincia = pIdProvincia
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_domicilio_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_domicilio_borrar` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite borrar un domicilio controlando que o hay sido utilizado en una venta, remito ni en una ubicacion. 
        Devuelve un json con NULL en respuesta o el codigo de error en error.
    */
    
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pDomicilios JSON;
    DECLARE pIdDomicilio int;
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_domicilio_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;


    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdDomicilio = pDomicilios ->> "$.IdDomicilio";

    IF NOT EXISTS (SELECT IdDomicilio FROM Domicilios  WHERE IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Ventas v USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Remitos r USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Ubicaciones u USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;
    


    START TRANSACTION;
        IF pIdCliente IS NULL THEN
            IF ( NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio)) THEN
                DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
            END IF;
        ELSE
            IF NOT EXISTS(SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente <> pIdCliente) THEN
                DELETE FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente ;
                DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
            ELSE
                DELETE FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente ;
            END IF;
            
            
        END IF;
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_domicilio_crear`;
DELIMITER $$
CREATE PROCEDURE  `zsp_domicilio_crear` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite crear un domicilio.
        Llama al procedimiento zsp_domicilio_crear_comun
        Devuelve un json con el domicilio creado en respuesta o el codigo de error en error.
    */

    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    -- Para llamar al procedimiento zsp_domicilio_crear_comun
    DECLARE pRespuesta JSON;
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

    CALL zsp_domicilio_crear_comun(pIn, pIdDomicilio, pRespuesta);

    IF pIdDomicilio IS NULL THEN
        SELECT pRespuesta pOut;
        LEAVE SALIR;
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

END $$
DELIMITER ;

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
DROP PROCEDURE IF EXISTS `zsp_grupoProducto_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_borrar`(pIn JSON)
SALIR: BEGIN
	/*
        Permite borrar un grupo de producto. Controla que no exista ningun producto que pertenezca al grupo de productos.
        Devuelve NULL'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de prodcuto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    
    -- Respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProducto FROM Productos WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTO_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;


    DELETE FROM GruposProducto
    WHERE IdGrupoProducto = pIdGrupoProducto;

    SELECT f_generarRespuesta(NULL, NULL) AS pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_grupoProducto_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_dar_alta`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Grupo de productos a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve el grupo de productos en 'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de prodcuto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    
    -- Respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_GRUPOPRODUCTO_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;

        UPDATE GruposProducto
        SET Estado = 'A'
        WHERE IdGrupoProducto = pIdGrupoProducto;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE IdGrupoProducto = pIdGrupoProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_grupoProducto_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_dar_baja`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Grupo de productos a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve el grupo de productos en 'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de prodcuto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    
    -- Respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_GRUPOPRODUCTO_ESTA_BAJA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;

        UPDATE GruposProducto
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdGrupoProducto = pIdGrupoProducto;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE IdGrupoProducto = pIdGrupoProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_grupoProducto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_modificar` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un grupo de productos. Controla que no exista un Grupo de Productos con el mismo nombre.
        Devuelve el grupo de productos en 'respuesta' o el codigo de error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de producto a modificar
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pGrupo varchar(40);
    DECLARE pDescripcion varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";
    SET pGrupo = pGruposProducto ->> "$.Grupo";
    SET pDescripcion = pGruposProducto ->> "$.Descripcion";

    IF pIdGrupoProducto IS NULL OR NOT EXISTS(SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pGrupo = '' OR pGrupo IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE Grupo = pGrupo AND IdGrupoProducto <> pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    UPDATE GruposProducto
    SET Grupo = pGrupo,
        Descripcion = pDescripcion
    WHERE IdGrupoProducto = pIdGrupoProducto;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE IdGrupoProducto = pIdGrupoProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_gruposProducto_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_gruposProducto_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar grupos producto por su nombre y Estado (A:Activo - B:Baja - T:Todos)
        Devuelve un JSON con la lista de grupos producto en respuesta o el error en error.        
    */

-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- GruposProducto
    DECLARE pGruposProducto JSON;
    DECLARE pGrupo varchar(40);
    DECLARE pEstado char(1);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_gruposProducto_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pGrupo = pGruposProducto ->> "$.Grupo";
    SET pEstado = pGruposProducto ->> "$.Estado";

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    SET pGrupo = COALESCE(pGrupo,'');



    SET pRespuesta = (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "GruposProducto",
                    JSON_OBJECT(
						'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
					)
                )
            )
	FROM GruposProducto 
	WHERE	
        Grupo LIKE CONCAT(pGrupo, '%') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY Grupo);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_grupoProducto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_crear` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un grupo de productos. Controla que no exista un Grupo de Productos con el mismo nombre.
        Devuelve el Grupo en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de producto a crear
    DECLARE pGruposProducto JSON;
    DECLARE pGrupo varchar(40);
    DECLARE pDescripcion varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pGrupo = pGruposProducto ->> "$.Grupo";
    SET pDescripcion = pGruposProducto ->> "$.Descripcion";

    IF pGrupo = '' OR pGrupo IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE Grupo = pGrupo) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    INSERT INTO GruposProducto (IdGrupoProducto, Grupo, FechaAlta, FechaBaja, Descripcion, Estado) VALUES (0, pGrupo, NOW(), NULL, NULLIF(pDescripcion, ''), 'A');

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE	Grupo = pGrupo
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_paises_listar`;

DELIMITER $$
CREATE PROCEDURE  `zsp_paises_listar`()

SALIR:BEGIN
    /*
        Procedimiento que permite listar todos los paises . 
        Devuelve un json todos los paises.
    */

    DECLARE pRespuesta JSON;

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Paises",
                    JSON_OBJECT(
						'IdPais', IdPais,
                        'Pais', Pais
					)
                )
            )
	FROM Paises);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut; 

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_permisos_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_permisos_listar`()

BEGIN
	/*
		Lista todos los permisos existentes y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/

    DECLARE pRespuesta TEXT;

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT('Permisos',
                    JSON_OBJECT(
                        'IdPermiso', IdPermiso, 
                        'Permiso', Permiso,
                        'Procedimiento', Procedimiento,
                        'Descripcion', Descripcion
                    )
                )
            )
        ,'')
	FROM Permisos p 
    ORDER BY Procedimiento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_provincias_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_provincias_listar`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que devuelve una lista de provincias de un pais.
        Devuelve un JSON con las provincias
    
    */

    DECLARE pRespuesta JSON;
    DECLARE pPaises JSON;
    DECLARE pIdPais char(2);

    SET pPaises = pIn ->>"$.Paises";
    SET pIdPais = pPaises ->>"$.IdPais";


    SET pRespuesta = (SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            "Provincias",
            JSON_OBJECT(
                'IdProvincia', IdProvincia,
                'Provincia', Provincia
            )
        )
    ) 
    FROM Provincias 
    WHERE IdPais = pIdPais
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_rol_asignar_permisos`;
DELIMITER $$
CREATE  PROCEDURE `zsp_rol_asignar_permisos`(pIn JSON)

SALIR: BEGIN
	/*
		Dado el rol y una cadena formada por la lista de los IdPermisos separados por comas, asigna los permisos seleccionados como dados y quita los no dados.
		Cambia el token de los usuarios del rol así deban reiniciar sesión y retomar permisos.
		Devuelve null en 'respuesta' o el codigo de error en 'error'.
	*/	
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pNumero varchar(11);
	DECLARE pMensaje text;
	DECLARE pRoles, pPermisos, pUsuariosEjecuta JSON;
	DECLARE pIdRol int;
	DECLARE pToken varchar(256);

	/*Para el While*/
	DECLARE i INT DEFAULT 0;
	DECLARE pPermiso JSON;
	DECLARE pIdPermiso smallint;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SHOW ERRORS;
		SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> '$.Roles';
	SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
	SET pPermisos = pIn ->> '$.Permisos';

    SET pIdRol = pRoles ->> '$.IdRol';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
	
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_asignar_permisos', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje != 'OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol)THEN
		SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
		DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
        CREATE TEMPORARY TABLE tmp_permisosrol ENGINE = MEMORY AS
        SELECT * FROM PermisosRol WHERE IdRol = pIdRol;
		
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;

		WHILE i < JSON_LENGTH(pPermisos) DO
			SELECT JSON_EXTRACT(pPermisos,CONCAT('$[',i,']')) INTO pPermiso;
			SET pIdPermiso = pPermiso ->> '$.IdPermiso';
			IF NOT EXISTS(SELECT IdPermiso FROM Permisos WHERE IdPermiso = pIdPermiso)THEN
				SELECT f_generarRespuesta('ERROR_NOEXISTE_PERMISO_LISTA', NULL) pOut;
                ROLLBACK;
                LEAVE SALIR;
            END IF;
            INSERT INTO PermisosRol VALUES(pIdPermiso, pIdRol);
			SELECT i + 1 INTO i;
		END WHILE;

        IF EXISTS(SELECT IdPermiso
			FROM
			(SELECT IdPermiso
			FROM tmp_permisosrol
			UNION ALL
			SELECT IdPermiso
			FROM PermisosRol
			WHERE IdRol = pIdRol) p
			GROUP BY IdPermiso
			HAVING COUNT(IdPermiso) = 1) THEN /*Si existen cambios, es decir existe un nuevo tipo de permiso respecto a la tabla original (tmp_permisosrol) => Reseteamos token.*/
                UPDATE Usuarios SET Token = md5(CONCAT(CONVERT(IdUsuario,char(10)),UNIX_TIMESTAMP())) WHERE IdRol = pIdRol;
		END IF;
		SELECT f_generarRespuesta(NULL, NULL) pOut;
        DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
	COMMIT;    
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_borrar`(pIn JSON)

SALIR: BEGIN
    /*
        Permite borrar un rol controlando que no exista un usuario asociado.
        Devuelve null en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pRoles JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdRol int;
    DECLARE pToken varchar(256);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pIdRol IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INDICAR_ROL', NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
	IF EXISTS(SELECT IdRol FROM Usuarios WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_ROL_USUARIO', NULL) pOut;
		LEAVE SALIR;
	END IF;
	
    START TRANSACTION;
	
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;
        DELETE FROM Roles WHERE IdRol = pIdRol;
        SELECT f_generarRespuesta(NULL, NULL) pOut;

	COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_crear`(pIn JSON)

SALIR: BEGIN
	/*
		Permite crear un rol controlando que el nombre no exista ya. 
		Devuelve el rol creado en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pRoles JSON;
	DECLARE pUsuarioEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
	DECLARE pIdRol tinyint;
	DECLARE pToken varchar(256);
	DECLARE pRol varchar(40);
	DECLARE pDescripcion varchar(255);
	DECLARE pRespuesta JSON;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> "$.Roles";
	SET pUsuarioEjecuta = pIn ->> "$.UsuariosEjecuta";
	SET pToken = pUsuarioEjecuta ->> "$.Token";
	SET pRol = pRoles ->> "$.Rol";
	SET pDescripcion = pRoles ->> "$.Descripcion";
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBREROL', NULL) pOut;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_NOMBREROL', NULL) pOut;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;
		
        INSERT INTO Roles VALUES (DEFAULT, pRol, NOW(), NULLIF(pDescripcion,''));
		SET pIdRol = (SELECT IdRol FROM Roles WHERE Rol = pRol);
		SET pRespuesta = (SELECT (CAST(
			COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
						)
					,'')
			AS JSON)) FROM Roles WHERE Rol = pRol);
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) AS pOut;
	COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_rol_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_dame`(pIn JSON)

SALIR: BEGIN
    /*
        Procedimiento que sirve para instanciar un rol desde la base de datos. Devuelve el objeto en 'respuesta' o un error en 'error'.
    */
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

	SET pRespuesta = (
        SELECT CAST(
				COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
					)
				,'') AS JSON)
        FROM	Roles
        WHERE	IdRol = pIdRol
    );

    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_listar_permisos`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_listar_permisos`(pIn JSON)

BEGIN
	/*
		Lista todos los permisos existentes para un rol y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta TEXT;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT('Permisos',
                    JSON_OBJECT(
                        'IdPermiso', IdPermiso, 
                        'Permiso', Permiso,
                        'Procedimiento', Procedimiento,
                        'Descripcion', Descripcion
                    )
                )
            )
        ,'')
	FROM Permisos p 
    INNER JOIN PermisosRol pr USING(IdPermiso)
    WHERE pr.IdRol = pIdRol
    ORDER BY Procedimiento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_modificar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_modificar`(pIn JSON)

SALIR: BEGIN
	/*
		Permite modificar un rol controlando que el nombre no exista ya. 
		Devuelve el rol modifica en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pRoles JSON;
	DECLARE pUsuarioEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
	DECLARE pIdRol tinyint;
	DECLARE pToken varchar(256);
	DECLARE pRol varchar(40);
	DECLARE pDescripcion varchar(255);
	DECLARE pRespuesta JSON;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> "$.Roles";
	SET pUsuarioEjecuta = pIn ->> "$.UsuariosEjecuta";
	SET pToken = pUsuarioEjecuta ->> "$.Token";
    SET pIdRol = pRoles ->> "$.IdRol";
	SET pRol = pRoles ->> "$.Rol";
	SET pDescripcion = pRoles ->> "$.Descripcion";
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBREROL', NULL) pOut;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol AND IdRol != pIdRol) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_NOMBREROL', NULL) pOut;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;
		
        UPDATE Roles 
        SET Rol = pRol,
            Descripcion = NULLIF(pDescripcion,'')
        WHERE IdRol = pIdRol;
        
		SET pRespuesta = (SELECT (CAST(
			COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
						)
					,'')
			AS JSON)) FROM Roles WHERE IdRol = pIdRol);
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) AS pOut;
	COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_roles_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_roles_listar`()

BEGIN
	/*
		Lista todos los roles existentes. Ordena por Rol. Devuelve la lista de roles en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pOut JSON;
    DECLARE pRespuesta TEXT;


    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT("Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol, 
                        'Rol', Rol,
                        'FechaAlta', FechaAlta,
                        'Descripcion', Descripcion
                    )
                )
            ),'')
	FROM Roles
    ORDER BY Rol);
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_sesion_cerrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_cerrar`(pIn JSON)

SALIR: BEGIN
    /*
        Permite cerrar la sesion de un usuario a partir de su Id.
        Devuelve OK o el mensaje de error en Mensaje.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pIdUsuario smallint;
    DECLARE pUsuarios, pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    SET pIdUsuario = pUsuarios ->> '$.IdUsuario';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_sesion_cerrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pIdUsuario IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_USUARIO', NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL) pOut;
        LEAVE SALIR;
    END IF;
	
    START TRANSACTION;
        UPDATE Usuarios
        SET Token = ''
        WHERE IdUsuario = pIdusuario;
        SELECT f_generarRespuesta(NULL, NULL) pOut;
	COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_sesion_iniciar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_iniciar`(pIn JSON)

SALIR: BEGIN
	/*
		Procedimiento que permite a un usuario iniciar sesion en ZMGestion.
        Devuelve el usuario que ha iniciado sesion en pOut o el codigo de error en caso de error.
	*/
    DECLARE pIdUsuario smallint;
    DECLARE pTIEMPOINTENTOS, pMAXINTPASS, pIntentos int;
    DECLARE pFechaUltIntento datetime;
    DECLARE pUsuarios JSON;
    DECLARE pPass VARCHAR(255);
    DECLARE pUsuario VARCHAR(40);
    DECLARE pEmail VARCHAR(120);
    DECLARE pToken VARCHAR(256);

    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pToken = pUsuarios ->> '$.Token'; 

    IF pToken IS NULL OR pToken = '' THEN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pUsuario = pUsuarios ->> '$.Usuario';
    SET pEmail = pUsuarios ->> '$.Email';
    SET pPass = pUsuarios ->> '$.Password'; 


    SET pTIEMPOINTENTOS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='TIEMPOINTENTOS');
    SET pMAXINTPASS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='MAXINTPASS');

    
    IF (pUsuario IS NULL OR pUsuario = '') AND (pEmail IS NULL OR pEmail = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Control porque no se puede enviar usuario y correo electronico. Debe ser uno de los dos
    IF (pUsuario IS NOT NULL AND pUsuario <> '') AND (pEmail IS NOT NULL AND pEmail <> '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pEmail IS NOT NULL AND pEmail <> '' THEN
        IF(NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail)) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
		ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        END IF;
    ELSE
        IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
        ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario);
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
        SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pIntentos = (SELECT Intentos FROM Usuarios WHERE IdUsuario = pIdUsuario);
        SET pFechaUltIntento = (SELECT FechaUltIntento FROM Usuarios WHERE IdUsuario = pIdUsuario);

        IF DATE_ADD(pFechaUltIntento, INTERVAL pTIEMPOINTENTOS MINUTE) < NOW() THEN
            SET pIntentos = 0;
            SELECT pTIEMPOINTENTOS Mensaje;
        END IF;

        IF NOT EXISTS (SELECT Estado FROM Usuarios WHERE `Password` = pPass AND ESTADO = 'A' AND IdUsuario = pIdUsuario) THEN
            IF (pIntentos + 1) >= pMAXINTPASS THEN
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW(),
                    Estado = 'B'
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
            ELSE
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW()
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            END IF;
            LEAVE SALIR;
        ELSE
            UPDATE Usuarios
            SET Token = pToken,
                FechaUltIntento = NOW(),
                Intentos = 0
            WHERE IdUsuario = pIdUsuario;

            SET pUsuarios = (
                SELECT CAST(
                        COALESCE(
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
                                'Token', Token,
                                'FechaNacimiento', FechaNacimiento,
                                'FechaInicio', FechaInicio,
                                'FechaAlta', FechaAlta,
                                'Estado', Estado
                            )
                        ,'') AS JSON)
                FROM	Usuarios
                WHERE	IdUsuario = pIdUsuario
            );

            SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pUsuarios)) pOut; 
        END IF;        
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar una tela. Controla que no este siendo utilizada por un ProductoFinal.
        Devuelve null en respuesta o el error en error.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL_TELA", NULL);
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        -- Para poder borrar en la tabla precios
        SET SQL_SAFE_UPDATES = 0;
        DELETE FROM Telas WHERE IdTela = pIdTela;
        DELETE FROM Precios WHERE Tipo = 'T' AND  IdReferencia = pIdTela;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
        SET SQL_SAFE_UPDATES = 1;
    COMMIT;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_crear`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una tela. Control que no exista otra tela con el mismo nombre y que el precio sea mayor que cero.
        Devuelve un json con la tela y el precio en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;
    DECLARE pTela varchar(60);
    DECLARE pObservaciones varchar(255);

    -- Precio de la tela
    DECLARE pPrecios JSON;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pTela = pTelas ->> "$.Tela";
    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";

    IF pTela IS NULL OR pTela = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTela FROM Telas WHERE Tela = pTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Telas (IdTela, Tela, FechaAlta, FechaBaja, Observaciones, Estado) VALUES(0, pTela, NOW(), NULL, NULLIF(pObservaciones, ''), 'A');
    SET pIdTela = (SELECT IdTela FROM Telas WHERE Tela = pTela);
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'T', pIdTela, NOW());

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_dame` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que devuelve una tela y su precio a partir del IdTela.
        Devuelve la Tela y el ultimo precio en respuesta o error en error.
    */

    -- Tela
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Precio
    DECLARE pIdPrecio int;


    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela AND p.IdPrecio = pIdPrecio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_dar_alta`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de alta una tela que se encontraba en estado "Baja". Controla que la tela exista
        Devuelve un json con la tela en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Telas WHERE IdTela = pIdTela) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_TELA_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Telas
        SET Estado = 'A'
        WHERE IdTela = pIdTela;

            SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        )
                )
             AS JSON)
			FROM	Telas t
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_dar_baja`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de baja una tela que se encontraba en estado "Alta". Controla que la tela exista
        Devuelve un json con la tela en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Telas WHERE IdTela = pIdTela) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_TELA_ESTA_BAJA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Telas
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdTela = pIdTela;

            SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        )
                )
             AS JSON)
			FROM	Telas t
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS`zsp_tela_listar_precios`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_listar_precios`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar el historico de precios de una tela.
        Devuelve una lista de precios en respuesta o el error en error.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Tela de la cual se desea conocer el historico de precios
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_listar_precios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "Precios",
            JSON_OBJECT(
                'IdPrecio', IdPrecio,
                'Precio', Precio,
                'FechaAlta', FechaAlta
            )
        )
    ) 
    FROM Precios 
    WHERE Tipo = 'T' AND IdReferencia = pIdTela
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_tela_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_modificar`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una tela. Control que no exista otra tela con el mismo nombre.
        Devuelve un json con la tela y el precio en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;
    DECLARE pTela varchar(60);
    DECLARE pObservaciones varchar(255);

    -- Precio
    DECLARE pIdPrecio int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";
    SET pTela = pTelas ->> "$.Tela";

    IF pTela IS NULL OR pTela = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTela FROM Telas WHERE Tela = pTela AND IdTela <> pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    UPDATE Telas
    SET Tela = pTela,
        Observaciones = NULLIF(pObservaciones, '')
    WHERE IdTela = pIdTela;

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela AND p.IdPrecio = pIdPrecio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_tela_modificar_precio`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_modificar_precio`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el precio de una tela. Controla que el precio sea mayor que cero.
        Devuelve un json con la tela y el precio en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Precio de la tela
    DECLARE pPrecios JSON;
    DECLARE pIdPrecio int;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_modificar_precio', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";
    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";


    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    IF pPrecio = (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'T', pIdTela, NOW());

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela AND p.IdPrecio = pIdPrecio
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_telas_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_telas_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar telas por su nombre y Estado (A:Activo - B:Baja - T:Todos)
        Devuelve un JSON con la lista de telas en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Tela de la cual se desea conocer el historico de precios
    DECLARE pTelas JSON;
    DECLARE pTela varchar(60);
    DECLARE pEstado char(1);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_telas_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTelas = pIn ->> "$.Telas";
    SET pTela = pTelas ->> "$.Tela";
    SET pEstado = pTelas ->> "$.Estado";

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    SET pTela = COALESCE(pTela,'');



    SET pRespuesta = (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Telas",
                    JSON_OBJECT(
						'IdTela', IdTela,
                        'Tela', Tela,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
                )
            )

	FROM Telas 
	WHERE	
        Tela LIKE CONCAT(pTela, '%') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY Tela);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tiposDocumento_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_tiposDocumento_listar`()
BEGIN
	/*
		Lista todos los tipos de documento existentes y devuelve la lista de tipos documento en 'respuesta' o el codigo de error en 'error'.
	*/

    DECLARE pRespuesta TEXT;

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT('TiposDocumento',
                    JSON_OBJECT(
                        'IdTipoDocumento', IdTipoDocumento, 
                        'TipoDocumento', TipoDocumento,
                        'Descripcion', Descripcion
                    )
                )
            )
        ,'')
	FROM TiposDocumento
    ORDER BY TipoDocumento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ubicacion_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar una ubicación.
        Debe controlar que no haya sido utilizado en un presupuesto, venta, linea de producto, remito y que no tenga un Usuario. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    
    
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;

    -- Ubicacion a borrar
    DECLARE pUbicaciones JSON;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdDomicilio int;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicaciones = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicaciones ->> "$.IdUbicacion";

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT Ubicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Presupuestos p USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_PRESUPUESTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Ventas v USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_VENTA' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Remitos r USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_REMITO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Usuarios us USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_USUARIO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

START TRANSACTION;
    SET pIdDomicilio = (SELECT IdDomicilio FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion);
	DELETE FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion;
    DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
    SELECT f_generarRespuesta(NULL, NULL)pOut;
COMMIT ;
END $$
DELIMITER ;

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
DROP PROCEDURE IF EXISTS `zsp_ubicacion_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_dar_alta`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado de una Ubicacion a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve la ubicacion en 'respuesta' o el codigo de error en 'error'.
	*/
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    -- Ubicacion en cuestion
    DECLARE pUbicacion JSON;
    DECLARE pIdUbicacion tinyint;
    
    -- Respuesta generada
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicacion = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicacion ->> "$.IdUbicacion";


    IF pIdUbicacion IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_UBICACION', NULL)pOut;
        LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (@pEstado = 'A') THEN
		SELECT f_generarRespuesta('ERROR_UBICACION_ESTA_ALTA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Ubicaciones
        SET Estado = 'A',
            FechaAlta = NOW()
        WHERE IdUbicacion = pIdUbicacion;

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

DROP PROCEDURE IF EXISTS `zsp_ubicacion_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_dar_baja`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado de una Ubicacion a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve la ubicacion en 'respuesta' o el codigo de error en 'error'.
	*/
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    -- Ubicacion en cuestion
    DECLARE pUbicacion JSON;
    DECLARE pIdUbicacion tinyint;
    
    -- Respuesta generada
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicacion = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicacion ->> "$.IdUbicacion";


    IF pIdUbicacion IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_UBICACION', NULL)pOut;
        LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (@pEstado = 'B') THEN
		SELECT f_generarRespuesta('ERROR_UBICACION_ESTA_BAJA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Ubicaciones
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdUbicacion = pIdUbicacion;

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

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT Ubicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
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
DROP PROCEDURE IF EXISTS `zsp_ubicaciones_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_ubicaciones_listar`()
SALIR: BEGIN

    /*
        Devuele un json con el listado de las ubicaciones
    */
    DECLARE pRespuesta JSON;

    SET pRespuesta  = (SELECT
        JSON_ARRAYAGG(
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
        )  
    FROM	Ubicaciones u
    INNER JOIN Domicilios d USING(IdDomicilio)
    );    
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_usuario_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar un usuario.
        Debe controlar que no haya creado un presupuesto, venta, orden de produccion, remito, comprobante, o que no se le 
        haya asignado o haya revisado alguna tarea. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pUsuarios JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";

	IF pIdUsuario = 1 THEN
		SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_ADAM', NULL)pOut;
		LEAVE SALIR;
	END IF;

    IF NOT EXISTS (SELECT Usuario FROM Usuarios WHERE IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Presupuestos p USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_PRESUPUESTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Ventas v USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_VENTA' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN OrdenesProduccion op USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_OP' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Comprobantes c USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_COMPROBANTE' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Remitos r USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_REMITO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioFabricante WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_TAREA_F' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioRevisor WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_TAREA_R' , NULL)pOut;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Usuarios WHERE IdUsuario = pIdUsuario;
    SELECT f_generarRespuesta(NULL, NULL)pOut;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_crear`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario crear un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
        Debe existir el Rol, TipoDocumento y la Ubicacion.
        Almacena el hash de la contraseña.
        Todos los campos son obligatorios.
        Devuelve un json con el usuario creado en respuesta o el codigo de error en error.
    */
    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuario smallint;
    DECLARE pToken varchar(256);
    DECLARE pIdRol tinyint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pEstadoCivil char(1);
    DECLARE pTelefono varchar(15);
    DECLARE pEmail varchar(120);
    DECLARE pCantidadHijos tinyint;
    DECLARE pUsuario varchar(40);
    DECLARE pPassword varchar(255);
    DECLARE pFechaNacimiento date;
    DECLARE pFechaInicio date;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_crear', pIdUsuarioEjecuta, pMensaje);
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

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_ROL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TIPODOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_DOCUMENTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_USUARIO_TIPODOC_DOC", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_NOMBRE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_APELLIDO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_ESTADOCIVIL", NULL) pOut;
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

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_CANTIDADHIJOS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pUsuario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_USUARIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT f_generarRespuesta("ERROR_ESPACIO_USUARIO", NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_USUARIO", NULL) pOut;
		LEAVE SALIR;
	END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PASSWORD", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT f_generarRespuesta("ERROR_FECHANACIMIENTO_ANTERIOR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT f_generarRespuesta("ERROR_FECHAINICIO_ANTERIOR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Usuarios (IdUsuario,IdRol,IdUbicacion,IdTipoDocumento,Documento,Nombres,Apellidos,EstadoCivil,Telefono,Email,CantidadHijos,Usuario,Password,Token,FechaUltIntento,Intentos,FechaNacimiento,FechaInicio,FechaAlta,FechaBaja,Estado) VALUES (0, pIdRol, pIdUbicacion, pIdTipoDocumento, pDocumento, pNombres, pApellidos, pEstadoCivil, pTelefono, pEmail, pCantidadHijos, pUsuario, pPassword, NULL, NULL, 0 ,pFechaNacimiento, pFechaInicio, NOW(), NULL,'A');
        SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        SET pRespuesta = (
        SELECT CAST(
				COALESCE(
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
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
				,'') AS JSON)
        FROM	Usuarios
        WHERE	IdUsuario = pIdUsuario
    );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame`(pIn JSON)

SALIR: BEGIN
    DECLARE pUsuarios, pUsuariosEjecuta JSON;
    DECLARE pIdUsuario smallint;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pRespuesta JSON;
    DECLARE pToken varchar(256);
    /*
        Procedimiento que sirve para instanciar un usuario por id desde la base de datos.
    */

    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dame', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;

    SET pIdUsuario = pUsuarios ->> '$.IdUsuario';

	SET pRespuesta = (
        SELECT CAST(
				COALESCE(
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
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
				,'') AS JSON)
        FROM	Usuarios
        WHERE	IdUsuario = pIdUsuario
    );

    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dame_por_token`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame_por_token`(pIn JSON)

SALIR: BEGIN

    /*
        Procedimiento que sirve para instanciar un usuario por token desde la base de datos.
    */	

    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuario int;
    DECLARE pRespuesta JSON;
    DECLARE pToken varchar(256);
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pIdUsuario = pUsuariosEjecuta ->> '$.IdUsuario';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    
    SET pRespuesta = (
        SELECT CAST(
				COALESCE(
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
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
				,'') AS JSON)
        FROM	Usuarios
        WHERE	Token = pToken
    );

    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) pOut;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_alta`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Usuario a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve el usuario en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";


    IF pIdUsuario IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_USUARIO', NULL)pOut;
        LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (@pEstado = 'A') THEN
		SELECT f_generarRespuesta('ERROR_USUARIO_ESTA_ALTA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Usuarios
        SET Estado = 'A',
            Intentos = 0
        WHERE IdUsuario = pIdUsuario;

        SET pRespuesta = (
            SELECT CAST(
                    COALESCE(
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
                            'FechaAlta', FechaAlta,
                            'FechaBaja', FechaBaja,
                            'Estado', Estado
                        )
                    ,'') AS JSON)
            FROM	Usuarios
            WHERE	IdUsuario = pIdUsuario
        );
        SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dar_baja`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_baja`(pIn JSON)

SALIR: BEGIN
    /*
        Permite cambiar el estado del Usuario a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve el usuario en 'respuesta' o el codigo de error en 'error.
    */
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";

    SET @pEstado = (SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

     IF (@pEstado = 'B') THEN
        SELECT f_generarRespuesta('ERROR_USUARIO_ESTA_BAJA', NULL)pOut;
        LEAVE SALIR;
    END IF;
		
    START TRANSACTION;
        UPDATE Usuarios SET Estado = 'B' WHERE IdUsuario = pIdUsuario;
        SET pRespuesta = (
                SELECT CAST(
                        COALESCE(
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
                                'FechaAlta', FechaAlta,
                                'FechaBaja', FechaBaja,
                                'Estado', Estado
                            )
                        ,'') AS JSON)
                FROM	Usuarios
                WHERE	IdUsuario = pIdUsuario
            );
            SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
        Debe existir el Rol, TipoDocumento y la Ubicacion.
        Almacena el hash de la contraseña.
        Todos los campos son obligatorios.
        Devuelve 'OK' + IdUsuario o el mensaje de error en  Mensaje.
    */

    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuario smallint;
    DECLARE pToken varchar(256);
    DECLARE pIdRol tinyint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pEstadoCivil char(1);
    DECLARE pTelefono varchar(15);
    DECLARE pEmail varchar(120);
    DECLARE pCantidadHijos tinyint;
    DECLARE pUsuario varchar(40);
    DECLARE pPassword varchar(255);
    DECLARE pFechaNacimiento date;
    DECLARE pFechaInicio date;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;


    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pIdUbicacion = pUsuarios ->> "$.IdUbicacion";
    SET pIdTipoDocumento = pUsuarios ->> "$.IdTipoDocumento";
    SET pDocumento = pUsuarios ->> "$.Documento";
    SET pNombres = pUsuarios ->> "$.Nombres";
    SET pApellidos = pUsuarios ->> "$.Apellidos";
    SET pEstadoCivil = pUsuarios ->> "$.EstadoCivil";
    SET pTelefono = pUsuarios ->> "$.Telefono";
    SET pEmail = pUsuarios ->> "$.Email";
    SET pCantidadHijos = pUsuarios ->> "$.CantidadHijos";
    SET pPassword = pUsuarios ->> "$.Password";
    SET pUsuario = pUsuarios ->> "$.Usuario";
    SET pFechaNacimiento = pUsuarios ->> "$.FechaNacimiento";
    SET pFechaInicio = pUsuarios ->> "$.FechaInicio";


    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_TIPODOC', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_DOCUMENTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento AND IdUsuario != pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_EXISTE_USUARIO_TIPODOC_DOC', NULL)pOut;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBRE', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_APELLIDO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT f_generarRespuesta('ERROR_INVALIDO_ESTADOCIVIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_TELEFONO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT f_generarRespuesta('ERROR_INGRESAR_EMAIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail AND IdUsuario != pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_EXISTE_EMAIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_CANTIDADHIJOS', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF pUsuario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_USUARIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT f_generarRespuesta('ERROR_ESPACIO_USUARIO', NULL)pOut;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario AND IdUsuario != pIdUsuario) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_USUARIO', NULL)pOut;
		LEAVE SALIR;
	END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT f_generarRespuesta('ERROR_FECHANACIMIENTO_ANTERIOR', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT f_generarRespuesta('ERROR_FECHAINICIO_ANTERIOR', NULL)pOut;
        LEAVE SALIR;
    END IF;
    START TRANSACTION;  
    
        UPDATE  Usuarios 
        SET IdUsuario = pIdUsuario,
            IdRol = pIdRol,
            IdUbicacion = pIdUbicacion,
            IdTipoDocumento = pIdTipoDocumento,
            Documento = pDocumento,
            Nombres = pNombres, 
            Apellidos = pApellidos,
            EstadoCivil =  pEstadoCivil,
            Telefono = pTelefono,
            Email = pEmail,
            CantidadHijos = pCantidadHijos,
            Usuario = pUsuario,
            FechaNacimiento = pFechaNacimiento,
            FechaInicio = pFechaInicio
        WHERE IdUsuario = pIdUsuario;

        SET pRespuesta = (
            SELECT CAST(
                    COALESCE(
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
                            'FechaAlta', FechaAlta,
                            'FechaBaja', FechaBaja,
                            'Estado', Estado
                        )
                    ,'') AS JSON)
            FROM	Usuarios
            WHERE	IdUsuario = pIdUsuario
        );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;

END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_modificar_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar_pass`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar su contraseña comprobando que la contraseña actual ingresada sea correcta.
        Devuelve 'OK' o el mensaje de error en Mensaje
    */
    DECLARE pMensaje text;

    DECLARE pUsuariosEjecuta, pUsuariosActual, pUsuariosNuevo, pRespuesta JSON;

    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pPasswordActual varchar(255);
    DECLARE pPasswordNueva varchar(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar_pass', pIdUsuarioEjecuta, pMensaje);

    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuariosActual = pIn ->> "$.UsuariosActual";
    SET pPasswordActual = pUsuariosActual ->> "$.Password";

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuarioEjecuta AND Password = pPasswordActual) THEN
        SELECT f_generarRespuesta('ERROR_PASSWORD_INCORRECTA', NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuariosNuevo = pIn ->> "$.UsuariosNuevo";
    SET pPasswordNueva = pUsuariosNuevo ->> "$.Password";

    IF (pPasswordActual = pPasswordNueva) THEN
        SELECT f_generarRespuesta('ERROR_PASSWORDS_IGUALES', NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF(pPasswordNueva IS NULL OR pPasswordNueva = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_PASSWORD', NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;  
        UPDATE  Usuarios 
        SET Password = pPasswordNueva
        WHERE IdUsuario = pIdUsuarioEjecuta;

        SET pRespuesta = (
            SELECT CAST(
                    COALESCE(
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
                            'FechaAlta', FechaAlta,
                            'FechaBaja', FechaBaja,
                            'Estado', Estado
                        )
                    ,'') AS JSON)
            FROM	Usuarios
            WHERE	IdUsuario = pIdUsuarioEjecuta
        );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_restablecer_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_restablecer_pass`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario restablecer la contraseña de otro usuario. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pIdUsuario smallint;
    DECLARE pPassword varchar(255);
    DECLARE pToken varchar(256);
    DECLARE pUsuarios, pUsuariosEjecuta, pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_restablecer_pass', pIdUsuarioEjecuta, pMensaje);

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";
    SET pPassword = pUsuarios ->> "$.Password";
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_PASSWORD', NULL) pOut;
        LEAVE SALIR;
    END IF;

    UPDATE  Usuarios 
    SET Password = pPassword
    WHERE IdUsuario = pIdUsuario;
    
    SELECT f_generarRespuesta(NULL, NULL) pOut;

END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_tiene_permiso`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_tiene_permiso`(pToken varchar(256), pProcedimiento varchar(255), out pIdUsuario smallint, out pMensaje text)


BEGIN
    /*
        Permite determinar si un usuario, a traves de su Token, tiene los permisos necesarios para ejecutar cierto procedimiento.
    */

	SELECT  IdUsuario
    INTO    pIdUsuario
    FROM    Usuarios u
    INNER JOIN  PermisosRol pr USING(IdRol)
    INNER JOIN  Permisos p USING(IdPermiso)
    WHERE   u.Token = pToken AND u.Estado = 'A'
            AND p.Procedimiento = pProcedimiento;
    
    IF pIdUsuario IS NULL THEN
        SET pMensaje = 'ERROR_SIN_PERMISOS';
    ELSE
        SET pMensaje = 'OK';
    END IF;
END $$
DELIMITER ;

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


    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pEstadoCivil IS NULL OR pEstadoCivil = '' OR pEstadoCivil NOT IN ('C','S','D') THEN
		SET pEstadoCivil = 'T';
	END IF;

    -- IF pTieneHijos IS NULL OR pTieneHijos = '' OR pTieneHijos NOT IN ('S','N') THEN
		SET pTieneHijos = 'T';
	-- END IF;
    
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
	ORDER BY	CONCAT(Apellidos, ' ', Nombres), Usuario);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;

