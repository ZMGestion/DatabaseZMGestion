DROP PROCEDURE IF EXISTS `zsp_domicilio_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_domicilio_borrar` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite borrar un domicilio controlando que o hay sido utilizado en una venta, remito ni en una ubicacion. 
        Devuelve un json con NULL en respuesta o el codigo de error en error.
    */
    
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pDomicilios JSON;
    DECLARE pIdDomicilio int;
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_domicilio_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;


    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdDomicilio = pDomicilios ->> "$.IdDomicilio";

    IF NOT EXISTS (SELECT IdDomicilio FROM Domicilios  WHERE IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Ventas v USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Remitos r USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Ubicaciones u USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;
    


    START TRANSACTION;
        IF pIdCliente IS NULL THEN
            IF ( NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio)) THEN
                DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
            END IF;
        ELSE
            IF NOT EXISTS(SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente <> pIdCliente) THEN
                DELETE FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente ;
                DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
            ELSE
                DELETE FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente ;
            END IF;
            
            
        END IF;
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;
END $$
DELIMITER ;
