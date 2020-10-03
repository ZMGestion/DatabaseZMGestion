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

    START TRANSACTION;
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
    COMMIT;
END $$
DELIMITER ;

