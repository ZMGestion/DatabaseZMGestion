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

