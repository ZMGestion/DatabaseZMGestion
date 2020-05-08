DROP PROCEDURE IF EXISTS `zsp_sesion_iniciar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_iniciar`(pIn JSON)

SALIR: BEGIN
	/*
		Procedimiento que permite a un usuario iniciar sesion en ZMGestion.
        Devuelve el usuario que ha iniciado sesion en pOut o el codigo de error en caso de error.
	*/
    DECLARE pIdUsuario smallint;
    DECLARE pTIEMPOINTENTOS, pMAXINTPASS, pIntentos int;
    DECLARE pFechaUltIntento datetime;
    DECLARE pUsuarios JSON;
    DECLARE pPass VARCHAR(255);
    DECLARE pUsuario VARCHAR(40);
    DECLARE pEmail VARCHAR(120);
    DECLARE pToken VARCHAR(120);

    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pToken = pUsuarios ->> '$.Token'; 

    IF pToken IS NULL OR pToken = '' THEN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pUsuario = pUsuarios ->> '$.Usuario';
    SET pEmail = pUsuarios ->> '$.Email';
    SET pPass = pUsuarios ->> '$.Password'; 


    SET pTIEMPOINTENTOS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='TIEMPOINTENTOS');
    SET pMAXINTPASS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='MAXINTPASS');

    
    IF (pUsuario IS NULL OR pUsuario = '') AND (pEmail IS NULL OR pEmail = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Control porque no se puede enviar usuario y correo electronico. Debe ser uno de los dos
    IF (pUsuario IS NOT NULL AND pUsuario <> '') AND (pEmail IS NOT NULL AND pEmail <> '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pEmail IS NOT NULL AND pEmail <> '' THEN
        IF(NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail)) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
		ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        END IF;
    ELSE
        IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
        ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario);
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
        SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pIntentos = (SELECT Intentos FROM Usuarios WHERE IdUsuario = pIdUsuario);
        SET pFechaUltIntento = (SELECT FechaUltIntento FROM Usuarios WHERE IdUsuario = pIdUsuario);

        IF DATE_ADD(pFechaUltIntento, INTERVAL pTIEMPOINTENTOS MINUTE) < NOW() THEN
            SET pIntentos = 0;
            SELECT pTIEMPOINTENTOS Mensaje;
        END IF;

        IF NOT EXISTS (SELECT Estado FROM Usuarios WHERE `Password` = pPass AND ESTADO = 'A' AND IdUsuario = pIdUsuario) THEN
            IF (pIntentos + 1) >= pMAXINTPASS THEN
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW(),
                    Estado = 'B'
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
            ELSE
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW()
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            END IF;
            LEAVE SALIR;
        ELSE
            UPDATE Usuarios
            SET Token = pToken,
                FechaUltIntento = NOW(),
                Intentos = 0
            WHERE IdUsuario = pIdUsuario;

            SET pUsuarios = (
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
                                'Token', Token,
                                'FechaNacimiento', FechaNacimiento,
                                'FechaInicio', FechaInicio,
                                'FechaAlta', FechaAlta,
                                'Estado', Estado
                            )
                        ,'') AS JSON)
                FROM	Usuarios
                WHERE	IdUsuario = pIdUsuario
            );

            SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pUsuarios)) pOut; 
        END IF;        
    COMMIT;

END $$
DELIMITER ;