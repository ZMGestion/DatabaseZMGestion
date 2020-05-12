DROP PROCEDURE IF EXISTS `zsp_usuario_dame_por_token`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame_por_token`(pIn JSON)

SALIR: BEGIN

    /*
        Procedimiento que sirve para instanciar un usuario por token desde la base de datos.
    */	

    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuario int;
    DECLARE pRespuesta JSON;
    DECLARE pToken varchar(256);
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pIdUsuario = pUsuariosEjecuta ->> '$.IdUsuario';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    
    SET pRespuesta = (
        SELECT CAST(
				COALESCE(
					JSON_OBJECT(
						'IdUsuario', IdUsuario,
                        'IdRol', IdRol,
                        'IdUbicacion', IdUbicacion,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'EstadoCivil', EstadoCivil,
                        'Telefono', Telefono,
                        'Email', Email,
                        'CantidadHijos', CantidadHijos,
                        'Usuario', Usuario,
                        'FechaUltIntento', FechaUltIntento,
                        'FechaNacimiento', FechaNacimiento,
                        'FechaInicio', FechaInicio,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
				,'') AS JSON)
        FROM	Usuarios
        WHERE	Token = pToken
    );

    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) pOut;
END $$
DELIMITER ;

