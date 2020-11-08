DROP PROCEDURE IF EXISTS zsp_ventas_dame_multiple;
DELIMITER $$
CREATE PROCEDURE zsp_ventas_dame_multiple(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instancias mas de una venta a partir de sus Id.
        Devuelve las ventas con sus lineas de ventas en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    DECLARE pLongitud int unsigned;
    DECLARE pIndex int unsigned DEFAULT 0;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ventas_dame_multiple', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> "$.Ventas";
    SET pLongitud = JSON_LENGTH(pVentas);
    SET pRespuesta = JSON_ARRAY();

    WHILE pIndex < pLongitud DO
        SET pIdVenta = JSON_EXTRACT(pVentas, CONCAT("$[", pIndex, "]"));

        IF NOT EXISTS(SELECT pIdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET @pVenta = (
            SELECT JSON_OBJECT(
                "Ventas",  JSON_OBJECT(
                    'IdVenta', v.IdVenta,
                    'IdCliente', v.IdCliente,
                    'IdDomicilio', v.IdDomicilio,
                    'IdUbicacion', v.IdUbicacion,
                    'IdUsuario', v.IdUsuario,
                    'FechaAlta', v.FechaAlta,
                    'Observaciones', v.Observaciones,
                    'Estado', f_calcularEstadoVenta(v.IdVenta),
                    '_PrecioTotal', SUM(lp.Cantidad * lp.PrecioUnitario)
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
                            "Estado", f_dameEstadoLineaVenta(lp.IdLineaProducto)
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

        SET pRespuesta = JSON_ARRAY_INSERT(pRespuesta, CONCAT('$[', pIndex, ']'), CAST(@pVenta AS JSON));
        SET pIndex = pIndex + 1;
    END WHILE;
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
