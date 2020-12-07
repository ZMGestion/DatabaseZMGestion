DROP PROCEDURE IF EXISTS zsp_venta_dame;
DELIMITER $$
CREATE PROCEDURE zsp_venta_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite pasar instanciar una venta a partir de su Id. 
        Devuelve la venta con sus lineas de venta en 'respuesta' o el error en 'error'.

    */-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Ventas
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pLineasPresupuesto JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la venta
    SET pVentas = pIn ->> "$.Ventas";
    SET pIdVenta = COALESCE(pVentas ->> "$.IdVenta", 0);

    CALL zsp_usuario_tiene_permiso(pToken, 'dame_venta_ajena', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND IdUsuario = @pIdUsuarioEjecuta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SET @pFacturado = (
        SELECT SUM(IF(Tipo IN ('A', 'B'), Monto, -1 * Monto)) 
        FROM Comprobantes 
        WHERE IdVenta = pIdVenta AND Estado = 'A' AND Tipo IN ('A', 'B', 'M', 'N')
    );

    SET @pPagado = (
        SELECT SUM(Monto) 
        FROM Comprobantes 
        WHERE IdVenta = pIdVenta AND Estado = 'A' AND Tipo = 'R'
    );

    SET pRespuesta = (
        SELECT DISTINCT JSON_OBJECT(
            "Ventas",  JSON_OBJECT(
                'IdVenta', v.IdVenta,
                'IdCliente', v.IdCliente,
                'IdDomicilio', v.IdDomicilio,
                'IdUbicacion', v.IdUbicacion,
                'IdUsuario', v.IdUsuario,
                'FechaAlta', v.FechaAlta,
                'Observaciones', v.Observaciones,
                'Estado', f_calcularEstadoVenta(v.IdVenta),
                '_PrecioTotal', SUM(IF(lp.Estado != 'C', lp.Cantidad * lp.PrecioUnitario, 0)),
                '_Facturado', COALESCE(@pFacturado, 0),
                '_Pagado', COALESCE(@pPagado, 0)
            ),
            "Clientes", JSON_OBJECT(
                'Nombres', c.Nombres,
                'Apellidos', c.Apellidos,
                'RazonSocial', c.RazonSocial
            ),
            "Domicilios", JSON_OBJECT(
                'Domicilio', d.Domicilio
            ),
            "Usuarios", JSON_OBJECT(
                "Nombres", u.Nombres,
                "Apellidos", u.Apellidos
            ),
            "Ubicaciones", JSON_OBJECT(
                "Ubicacion", ub.Ubicacion
            ),
            "LineasVenta", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario,
                        "Estado", f_dameEstadoLineaVenta(lp.IdLineaProducto),
                        "_IdRemito", (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProductoPadre = lp.IdLineaProducto AND Tipo = 'R'),
                        "_IdOrdenProduccion", (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProductoPadre = lp.IdLineaProducto AND Tipo = 'O')
                    ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "IdTipoProducto", pr.IdTipoProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            ), JSON_ARRAY())
        )
        FROM Ventas v
        INNER JOIN Usuarios u ON u.IdUsuario = v.IdUsuario
        INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
        LEFT JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
        INNER JOIN Ubicaciones ub ON ub.IdUbicacion = v.IdUbicacion
        LEFT JOIN LineasProducto lp ON v.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	v.IdVenta = pIdVenta
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
