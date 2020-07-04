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
