DROP PROCEDURE IF EXISTS `zsp_cliente_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_cliente_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar un cliente.
        Debe controlar que no tenga presupuestos, ventas, y domicilios asociados 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;

    -- Respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes->> "$.IdCliente";


    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_CLIENTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT c.IdCliente FROM Clientes c INNER JOIN Presupuestos p USING(IdCliente) WHERE c.IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_CLIENTE_PRESUPUESTO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT c.IdCliente FROM Clientes c INNER JOIN Ventas v USING(IdCliente) WHERE c.IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_CLIENTE_VENTA' , NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT dc.IdCliente FROM DomiciliosCliente dc WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_CLIENTE_DOMICILIO' , NULL) pOut;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Clientes WHERE IdCliente = pIdCliente;
    SELECT f_generarRespuesta(NULL, NULL) pOut;
END $$
DELIMITER ;

