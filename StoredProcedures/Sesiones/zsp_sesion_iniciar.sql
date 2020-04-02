DROP PROCEDURE IF EXISTS `zsp_sesion_iniciar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_iniciar`(pCredencial varchar(120), pPass varchar(255), pToken varchar(256))

SALIR: BEGIN
	/*
		Procedimiento que permite a un usuario iniciar sesion en ZMGestion.
        Devuelve 'OK'+Id o el mensaje de error en  Mensaje.
	*/
    DECLARE pIdUsuario smallint;
    DECLARE pTIEMPOINTENTOS, pMAXINTPASS, pIntentos int;
    DECLARE pFechaUltIntento datetime;

    IF pToken IS NULL OR pToken = '' THEN
        SELECT 'ERR_TRANSACCION' Mensaje;
        LEAVE SALIR;
    END IF;

    SET pTIEMPOINTENTOS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='TIEMPOINTENTOS');
    SET pMAXINTPASS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='MAXINTPASS');

    
    IF pCredencial IS NULL OR pCredencial = '' THEN
        SELECT 'ERR_INGRESE_USUARIOEMAIL' Mensaje;
        LEAVE SALIR;
    END IF;

    IF LOCATE('@', pCredencial) != 0 THEN
        IF(NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Email = pCredencial)) THEN
            SELECT 'ERR_LOGIN_INCORRECTO' Mensaje;
            LEAVE SALIR;
		ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pCredencial);
        END IF;
    ELSE
        IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Usuario = pCredencial) THEN
            SELECT 'ERR_LOGIN_INCORRECTO' Mensaje;
            LEAVE SALIR;
        ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Usuario = pCredencial);
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
        SELECT 'ERR_LOGIN_BLOQUEADO' Mensaje;
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
                SELECT 'ERR_LOGIN_BLOQUEADO' Mensaje;
            ELSE
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW()
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT 'ERR_LOGIN_INCORRECTO' Mensaje;
            END IF;
            LEAVE SALIR;
        ELSE
            UPDATE Usuarios
            SET Token = pToken,
                FechaUltIntento = NOW(),
                Intentos = 0
            WHERE IdUsuario = pIdUsuario;
            SELECT CONCAT('OK',pIdUsuario) Mensaje;
        END IF;        
    COMMIT;

END $$
DELIMITER ;

