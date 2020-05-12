DROP PROCEDURE IF EXISTS `zsp_usuario_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame`(pIn JSON)

SALIR: BEGIN
    DECLARE pUsuarios, pUsuariosEjecuta JSON;
    DECLARE pIdUsuario smallint;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pRespuesta JSON;
    DECLARE pToken varchar(256);
    /*
        Procedimiento que sirve para instanciar un usuario por id desde la base de datos.
    */

    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dame', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;

    SET pIdUsuario = pUsuarios ->> '$.IdUsuario';

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
        WHERE	IdUsuario = pIdUsuario
    );

    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) pOut;

END $$
DELIMITER ;

