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
        SELECT JSON_OBJECT(
                    "Usuarios",
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
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Estado', u.Estado
                    ),
                    "Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol,
                        'Rol', Rol
                    ),
                    "Ubicaciones",
                    JSON_OBJECT(
                        'IdUbicacion', IdUbicacion,
                        'Ubicacion', Ubicacion
                    ))
        FROM	Usuarios u
        INNER JOIN	Roles r USING (IdRol)
        INNER JOIN	Ubicaciones USING (IdUbicacion)
        WHERE	Token = pToken
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;

