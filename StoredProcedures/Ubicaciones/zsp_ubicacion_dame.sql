DROP PROCEDURE IF EXISTS `zsp_ubicacion_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_dame` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que devuelve una ubicacion y su domicilio a partir del IdUbicacion.
        Devuelve la Ubicacio y la direccion en 'respuesta' o error en 'error'.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_dame', pIdUsuarioEjecuta, pMensaje);
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

    IF (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) IS NULL THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;


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
                    ),
                    "Ciudades", JSON_OBJECT(
                        'IdCiudad', c.IdCiudad,
                        'IdProvincia', c.IdProvincia,
                        'IdPais', c.IdPais,
                        'Ciudad', c.Ciudad
                    ),
                    "Provincias", JSON_OBJECT(
                        'IdProvincia', pr.IdProvincia,
                        'IdPais', pr.IdPais,
                        'Provincia', pr.Provincia
                    ),
                    "Paises", JSON_OBJECT(
                        'IdPais', p.IdPais,
                        'Pais', p.Pais
                    )
                )
             AS JSON)
			FROM	Ubicaciones u
            INNER JOIN Domicilios d USING(IdDomicilio)
            INNER JOIN Ciudades c ON d.IdCiudad = c.IdCiudad
            INNER JOIN Provincias pr ON pr.IdProvincia = c.IdProvincia
            INNER JOIN Paises p ON p.IdPais = pr.IdPais
			WHERE	u.IdUbicacion = pIdUbicacion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;
