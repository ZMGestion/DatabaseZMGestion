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

