DROP PROCEDURE IF EXISTS zsp_venta_cancelar;
DELIMITER $$
CREATE PROCEDURE zsp_venta_cancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite cancelar una venta.
        Cancela todas las lineas de venta.
        Devuelve la venta en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    DECLARE pIdLineaProducto bigint;
    DECLARE fin int;

    DECLARE pRespuesta JSON;

    DECLARE lineasVenta_cursor CURSOR FOR
        SELECT IdLineaProducto 
        FROM Ventas v
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'V' AND lp.IdReferencia = v.IdVenta)
        WHERE v.IdVenta = pIdVenta;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
        SET SQL_SAFE_UPDATES = 1;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_cancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> "$.Ventas";
    SET pIdVenta = COALESCE(pVentas ->> "$.IdVenta", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Ventas WHERE IdVenta = pIdVenta) NOT IN ('C', 'R') THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'V' AND IdReferencia = pIdVenta AND Estado NOT IN ('P', 'C')) THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'A') THEN
        IF (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'A') != (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'N') THEN
            SELECT f_generarRespuesta("ERROR_NOTACREDITOA_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'B') THEN
        IF (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'B') != (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'M') THEN
            SELECT f_generarRespuesta("ERROR_NOTACREDITOB_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    START TRANSACTION;
        SET SQL_SAFE_UPDATES = 0;
        OPEN lineasVenta_cursor;
            get_lineaVenta: LOOP
                FETCH lineasVenta_cursor INTO pIdLineaProducto;
                IF fin = 1 THEN
                    LEAVE get_lineaVenta;
                END IF;

                IF (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R') THEN
                    SELECT IdLineaProducto, IdReferencia INTO @pIdLineaRemito, @pIdRemito FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R';
                    
                    UPDATE LineasProducto
                    SET Estado = 'C'
                    WHERE IdLineaProducto = @pIdLineaRemito AND Tipo = 'R';

                    IF (SELECT Estado FROM Remitos WHERE IdRemito = @pIdRemito) = 'C' THEN
                        UPDATE Remitos
                        SET Estado = 'B'
                        WHERE IdRemito = @pIdRemito;
                    END IF;
                END IF;

                SET @pIdLineaPresupuesto = (SELECT IdLineaProductoPadre FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto);
                IF @pIdLineaPresupuesto IS NOT NULL THEN
                    UPDATE LineasProducto
                    SET Estado = 'P'
                    WHERE IdLineaProducto = @pIdLineaPresupuesto;
                END IF;
            END LOOP get_lineaVenta;
        CLOSE lineasVenta_cursor;

        UPDATE LineasProducto
        SET Estado = 'C'
        WHERE IdReferencia = pIdVenta AND Tipo = 'V';

        UPDATE Presupuestos
        SET Estado = 'C',
            IdVenta = NULL
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
        SET SQL_SAFE_UPDATES = 1;
    COMMIT;
END $$
DELIMITER ;
