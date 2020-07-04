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
