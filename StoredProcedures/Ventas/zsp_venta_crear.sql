DROP PROCEDURE IF EXISTS zsp_venta_crear;
DELIMITER $$
CREATE PROCEDURE zsp_venta_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una venta para un cliente, especificando una direccion para el mismo. 
        Controla que exista el cliente y su direccion, y la ubicacion desde la cual se creo.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdCliente int;
    DECLARE pIdDomicilio int;
    DECLARE pObservaciones varchar(255);

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
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> '$.Ventas';
    SET pIdCliente = COALESCE(pVentas ->> '$.IdCliente', 0);
    SET pIdDomicilio = COALESCE(pVentas ->> '$.IdDomicilio', 0);
    SET pIdUbicacion = COALESCE(pVentas ->> '$.IdUbicacion', 0);
    SET pObservaciones = COALESCE(pVentas ->> '$.Observaciones', '');

    IF NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente AND Estado = 'A') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdDomicilio > 0 THEN
        IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion AND Estado = 'A') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Ventas (IdVenta, IdCliente, IdDomicilio, IdUbicacion, IdUsuario, FechaAlta, Observaciones, Estado) VALUES (0, pIdCliente, NULLIF(pIdDomicilio, 0), pIdUbicacion, pIdUsuarioEjecuta, NOW(), NULLIF(pObservaciones, ''), 'E');

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ventas",  JSON_OBJECT(
                        'IdVenta', v.IdVenta,
                        'IdCliente', v.IdCliente,
                        'IdDomicilio', v.IdDomicilio,
                        'IdUbicacion', v.IdUbicacion,
                        'IdUsuario', v.IdUsuario,
                        'FechaAlta', v.FechaAlta,
                        'Observaciones', v.Observaciones,
                        'Estado', v.Estado
                        ) 
                )
             AS JSON)
			FROM	Ventas v
			WHERE	v.IdVenta = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;    
END $$
DELIMITER ;
