DROP PROCEDURE IF EXISTS `zsp_usuario_modificar_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar_pass`(pToken varchar(256), pIdUsuario smallint ,pPasswordActual varchar(255), pPasswordNueva varchar(255))

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar su contraseña comprobando que la contraseña actual ingresada sea correcta.
        Devuelve 'OK' o el mensaje de error en Mensaje
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pIdUsuarioAux smallint;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT 'ERR_NOEXISTE_USUARIO' Mensaje;
        LEAVE SALIR;
    END IF;

    SET pIdUsuarioAux = (SELECT IdUsuario FROM Usuarios WHERE Token = pToken);

    IF (pIdUsuarioAux != pIdUsuario) THEN 
        CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar_pass', pIdUsuarioEjecuta, pMensaje);
            IF pMensaje != 'OK' THEN
                SELECT pMensaje Mensaje;
                LEAVE SALIR;
            END IF;
    END IF;

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario AND Password = pPasswordActual) THEN
        SELECT 'ERR_PASSWORD_INCORRECTA' Mensaje;
        LEAVE SALIR;
    END IF;

    IF (pPasswordActual = pPasswordNueva) THEN
        SELECT 'ERR_PASSOWRDS_IGUALES' Mensaje;
        LEAVE SALIR;
    END IF;


    IF(pPasswordNueva IS NULL OR pPasswordNueva = '') THEN
        SELECT 'ERR_INGRESAR_PASSWORD' Mensaje;
        LEAVE SALIR;
    END IF;
    
    UPDATE  Usuarios 
    SET Password = pPasswordNueva
    WHERE IdUsuario = pIdUsuario;
    SELECT 'OK ' Mensaje;
END $$
DELIMITER ;


