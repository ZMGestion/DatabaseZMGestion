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
