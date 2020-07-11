DROP PROCEDURE IF EXISTS `zsp_tiposProducto_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tiposProducto_listar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar los tipos de producto.
        Devuelve una lista de tipos de producto en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tiposProducto_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "TiposProducto",
            JSON_OBJECT(
                'IdTipoProducto', IdTipoProducto,
                'TipoProducto', TipoProducto,
                'Descripcion', Descripcion
            )
        )
    ) 
    FROM TiposProducto
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;
