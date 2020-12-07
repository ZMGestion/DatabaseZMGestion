DROP PROCEDURE IF EXISTS zsp_venta_modificar_domicilio;
DELIMITER $$
CREATE PROCEDURE zsp_venta_modificar_domicilio(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el domicilio de una venta.
        En caso que este en estado Pendiente, solamente modificara el domicilio si aún no tiene uno seteado.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdVenta int;
    DECLARE pIdDomicilio int;
    
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_modificar_domicilio', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pIdVenta = COALESCE(pIn->>"$.Ventas.IdVenta", 0);
    SET pIdDomicilio = COALESCE(pIn->>"$.Ventas.IdDomicilio", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdDomicilio FROM Ventas WHERE IdVenta = pIdVenta) IS NOT NULL THEN
        IF (SELECT Estado FROM Ventas WHERE IdVenta = pIdVenta) != 'E' THEN
            SELECT f_generarRespuesta("ERROR_MODIFICAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        IF f_calcularEstadoVenta(pIdVenta) NOT IN('E', 'R', 'C') THEN
            SELECT f_generarRespuesta("ERROR_MODIFICAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF NOT EXISTS(SELECT dc.IdDomicilio FROM Ventas v INNER JOIN Clientes c ON c.IdCliente = v.IdCliente INNER JOIN DomiciliosCliente dc ON dc.IdCliente = c.IdCliente WHERE v.IdVenta = pIdVenta AND dc.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_DOMICILIO_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;

        UPDATE Ventas
        SET IdDomicilio = pIdDomicilio
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
