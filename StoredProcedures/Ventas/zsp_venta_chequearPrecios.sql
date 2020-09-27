DROP PROCEDURE IF EXISTS zsp_venta_chequearPrecios;
DELIMITER $$
CREATE PROCEDURE zsp_venta_chequearPrecios(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que chequea los precios de una venta.
        En caso que los precios de las lineas de venta sean los actuales pone la venta en estado Pendiente 'C'
        caso contrario pone la venta en estado EnRevision 'R'
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
    DECLARE pEstado char(1) DEFAULT 'C';

    -- Lineas Venta
    DECLARE pIdLineaProducto bigint;

    DECLARE fin tinyint;

    DECLARE pRespuesta JSON;
    
    DECLARE lineasVenta_cursor CURSOR FOR
        SELECT IdLineaProducto 
        FROM Ventas v
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'V' AND lp.IdReferencia = v.IdVenta)
        WHERE v.IdVenta = pIdVenta AND lp.Estado = 'P';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_chequearPrecios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> "$.Ventas";
    SET pIdVenta = COALESCE(pVentas ->> "$.IdVenta", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    OPEN lineasVenta_cursor;
        get_lineaVenta: LOOP
            FETCH lineasVenta_cursor INTO pIdLineaProducto;
            IF fin = 1 THEN
                LEAVE get_lineaVenta;
            END IF;

            SET @pIdProductoFinal = (SELECT IdProductoFinal FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto);

            IF (SELECT PrecioUnitario FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) != f_calcularPrecioProductoFinal(@pIdProductoFinal) THEN
                SET pEstado = 'R';
            END IF;
        END LOOP get_lineaVenta;
    CLOSE lineasVenta_cursor;

    START TRANSACTION;
        UPDATE Ventas
        SET Estado = pEstado
        WHERE IdVenta = pIdVenta;

        SET pRespuesta = (
        SELECT JSON_OBJECT(
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
        FROM Ventas v
        WHERE	v.IdVenta = pIdVenta
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;