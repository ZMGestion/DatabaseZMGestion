DROP PROCEDURE IF EXISTS zsp_venta_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_venta_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una venta.
        Controla que se encuentre en estado E.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdCliente int;
    DECLARE pIdDomicilio int;
    DECLARE pObservaciones varchar(255);

    -- Respuesta
    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> '$.Ventas';
    SET pIdVenta = COALESCE(pVentas ->> '$.IdVenta', 0);
    SET pIdCliente = COALESCE(pVentas ->> '$.IdCliente', 0);
    SET pIdUbicacion = COALESCE(pVentas ->> '$.IdUbicacion', 0);
    SET pIdDomicilio = COALESCE(pVentas ->> '$.IdDomicilio', 0);
    SET pObservaciones = COALESCE(pVentas ->> '$.Observaciones', '');

    IF pIdVenta != 0 THEN
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
            SELECT f_generarRespuesta("ERROR_MODIFICAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdCliente FROM Clientes c INNER JOIN Ventas v ON v.IdCliente = c.IdCliente WHERE c.IdCliente = pIdCliente AND v.IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdDomicilio > 0 THEN
        IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Ventas
        SET
            IdCliente = pIdCliente,
            IdDomicilio = NULLIF(pIdDomicilio, 0),
            IdUbicacion = pIdUbicacion,
            Observaciones = NULLIF(pObservaciones, '')
        WHERE IdVenta = pIdVenta;

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
			WHERE	v.IdVenta = pIdVenta
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;