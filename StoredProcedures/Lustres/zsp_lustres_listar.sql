DROP PROCEDURE IF EXISTS `zsp_lustres_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lustres_listar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar los lustres.
        Devuelve una lista de los lustres en 'respuesta' o el error en 'error'.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lustres_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "Lustres",
            JSON_OBJECT(
                'IdLustre', IdLustre,
                'Lustre', Lustre,
                'Observaciones', Observaciones
            )
        )
    ) 
    FROM Lustres
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;
