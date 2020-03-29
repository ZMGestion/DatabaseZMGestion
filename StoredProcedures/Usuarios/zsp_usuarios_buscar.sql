DROP PROCEDURE IF EXISTS `zsp_usuarios_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuarios_buscar`(
    pNombresApellidos varchar(80),
    pUsuario varchar(40),
    pEmail varchar(120),
    pDocumento varchar(15),
    pTelefono varchar(15),
    pEstadoCivil char(1),
    pTieneHijos char(1),
    pEstado char(1),
    pIdRol tinyint,
    pIdUbicacion tinyint)
BEGIN
	/*
		Permite buscar los usuarios por una cadena, o bien, por sus nombres y apellidos, nombre de usuario, email, documento, telefono,
        estado civil (C:Casado - S:Soltero - D:Divorciado - T:Todos), estado (A:Activo - B:Baja - T:Todos), rol (0:Todos los roles),
        ubicacion en la que trabaja (0:Todas las ubicaciones) y si tiene hijos o no (S:Si - N:No - T:Todos).
	*/

    DECLARE pIdUsuarioEjecuta smallint;

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuarios_buscar', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT pMensaje Mensaje;
		LEAVE SALIR;
	END IF;

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pEstadoCivil IS NULL OR pEstadoCivil = '' OR pEstadoCivil NOT IN ('C','S','D') THEN
		SET pEstado = 'T';
	END IF;

    IF pTieneHijos IS NULL OR pTieneHijos = '' OR pTieneHijos NOT IN ('S','N') THEN
		SET pTieneHijos = 'T';
	END IF;
    
    SET pNombresApellidos = COALESCE(pNombresApellidos,'');
    SET pUsuario = COALESCE(pUsuario,'');
    SET pEmail = COALESCE(pEmail,'');
    SET pDocumento = COALESCE(pDocumento,'');
    SET pTelefono = COALESCE(pTelefono,'');
    SET pIdRol = COALESCE(pIdRol,0);
    SET pIdUbicacion = COALESCE(pIdUbicacion,0);
    
	SELECT		u.*, Rol, Ubicacion,
				IF(u.Estado = 'B','S','N') OpcionDarAlta, IF(u.Estado = 'A','S','N') OpcionDarBaja
	FROM		Usuarios u
	INNER JOIN	Roles USING (IdRol)
    INNER JOIN	Ubicaciones USING (IdUbicacion)
	WHERE		IdRol IS NOT NULL AND 
				(
                    CONCAT(Apellidos,',',Nombres) LIKE CONCAT('%', pNombresApellidos, '%') OR
                    Usuario LIKE CONCAT(pUsuario, '%') OR
                    Email LIKE CONCAT(pEmail, '%') OR
                    Documento LIKE CONCAT(pDocumento, '%') OR
                    Telefono LIKE CONCAT(pTelefono, '%')
				) AND 
                (IdRol = pIdRol OR pIdRol = 0) AND
                (IdUbicacion = pIdUbicacion OR pIdUbicacion = 0) AND
                (u.Estado = pEstado OR pEstado = 'T') AND
                (u.EstadoCivil = pEstadoCivil OR pEstadoCivil = 'T') AND
                IF(pTieneHijos = 'S', u.CantidadHijos > 0, IF(pTieneHijos = 'N', u.CantidadHijos = 0, pTieneHijos = 'T'))
	ORDER BY	CONCAT(Apellidos, ' ', Nombres), Usuario;
END $$
DELIMITER ;

