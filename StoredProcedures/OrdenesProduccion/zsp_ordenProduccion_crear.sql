DROP PROCEDURE IF EXISTS zsp_ordenProduccion_crear;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una nueva orden de producción en estado En Creación.
        Devuelve la orden de producción en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE pObservaciones VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pToken = pIn->>"$.UsuariosEjecuta.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_crear', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pObservaciones = COALESCE(pIn->>"$.UsuariosEjecuta.Observaciones", "");

    START TRANSACTION;
        INSERT INTO OrdenesProduccion (IdOrdenProduccion, IdUsuario, FechaAlta, Observaciones, Estado) VALUES (0, pIdUsuarioEjecuta, NOW(), pObservaciones, 'E');

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', IdOrdenProduccion,
                        'IdUsuario', IdUsuario,
                        'FechaAlta', FechaAlta,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM    OrdenesProduccion
            WHERE   IdOrdenProduccion = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;
