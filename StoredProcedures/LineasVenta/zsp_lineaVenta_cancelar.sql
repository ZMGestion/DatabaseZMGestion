DROP PROCEDURE IF EXISTS zsp_lineaVenta_cancelar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_cancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite cancelar una linea de venta.
        Controla que se encuentre en Estado 'P'.
        Devuelve la Linea de Venta en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de venta
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    
    DECLARE pIdVenta int;

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_cancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = COALESCE(pLineasProducto ->> "$.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'V') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) != 'P' THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT v.Estado FROM Ventas v INNER JOIN LineasProducto lp ON lp.IdReferencia = v.IdVenta WHERE lp.IdLineaProducto = pIdLineaProducto) != 'C' THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT IdReferencia, Cantidad, PrecioUnitario INTO pIdVenta, @pCantidad, @pPrecioUnitario FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto;
    SET @pMontoCancelado = (SELECT SUM(PrecioUnitario * Cantidad) FROM LineasProducto WHERE IdReferencia = pIdVenta AND Tipo = 'V' AND Estado = 'C');

    -- Compruebo si existe una Factura A. En caso que haya deben existir notas de credito cuya suma total sea igual a las lineas de venta canceladas.
    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'A' AND Estado = 'A') THEN
        IF (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'N' AND ESTADO = 'A') !=  @pMontoCancelado + (@pCantidad * @pPrecioUnitario) THEN
            SELECT f_generarRespuesta("ERROR_NOTACREDITOA_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'B' AND Estado = 'A') THEN
        IF (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'M' AND Estado = 'A') != @pMontoCancelado + (@pCantidad * @pPrecioUnitario) THEN
            SELECT f_generarRespuesta("ERROR_NOTACREDITOB_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    START TRANSACTION;
        IF EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R') THEN
            SET @pIdLineaRemito = (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R');
            UPDATE LineasProducto
            SET Estado = 'C',
                FechaCancelacion = NOW()
            WHERE IdLineaProducto = @pIdLineaRemito;
        END IF;

        UPDATE LineasProducto
        SET Estado = 'C',
            FechaCancelacion = NOW()
        WHERE IdLineaProducto = pIdLineaProducto;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "LineasProducto", JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad,
                    "PrecioUnitario", lp.PrecioUnitario
                )
            )
        FROM LineasProducto lp
        WHERE	lp.IdLineaProducto = pIdLineaProducto
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;