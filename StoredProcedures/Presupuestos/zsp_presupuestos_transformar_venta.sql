DROP PROCEDURE IF EXISTS zsp_presupuestos_transformar_venta;
DELIMITER $$
CREATE PROCEDURE zsp_presupuestos_transformar_venta(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una venta a partir de un conjunto de lineas de presupuesto.
        Controla que todas las lineas pertenezcan a presupuestos del mismo cliente.
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
    DECLARE pEstado char(1) DEFAULT 'C';
    DECLARE pObservaciones varchar(255);

    -- LineasPresupuesto
    DECLARE pLineasPresupuesto JSON;
    DECLARE pIdLineaProducto bigint;
    DECLARE pIdProductoFinal int;
    DECLARE pTipo char(1);
    DECLARE pIdReferencia int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

    -- LineasVenta
    DECLARE pLineasVenta JSON;
    DECLARE pLineaVenta JSON;
 

    DECLARE pLongitud INT UNSIGNED;
    DECLARE pIndex INT UNSIGNED DEFAULT 0;

    DECLARE pIdLineaProductoPendiente bigint;
    DECLARE fin tinyint;

    DECLARE pError varchar(255);

    DECLARE pRespuesta JSON;

    DECLARE lineasPresupuestos_cursor CURSOR FOR
        SELECT lp.IdLineaProducto 
        FROM Presupuestos p
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'P' AND lp.IdReferencia = p.IdPresupuesto)
        WHERE lp.Estado = 'P' AND p.Estado = 'V' AND p.IdVenta = @pIdVenta;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuestos_transformar_venta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> '$.Ventas';
    SET pIdDomicilio = COALESCE(pVentas ->> '$.IdDomicilio', 0);
    SET pIdUbicacion = COALESCE(pVentas ->> '$.IdUbicacion', 0);
    SET pObservaciones = COALESCE(pVentas ->> '$.Observaciones', '');

    IF NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion AND Estado = 'A') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pLineasPresupuesto = COALESCE(pIn ->> "$.LineasPresupuesto", JSON_ARRAY());
        SET pLongitud = JSON_LENGTH(pLineasPresupuesto);

        WHILE pIndex < pLongitud DO
            SET pIdLineaProducto = JSON_EXTRACT(pLineasPresupuesto, CONCAT("$[", pIndex, "]"));
            -- SET pIdLineaProducto = pLineasPresupuesto -> CONCAT('$[', pIndex, ']');
            SELECT IdProductoFinal, IdReferencia, Tipo, PrecioUnitario, Cantidad 
            INTO pIdProductoFinal, pIdReferencia, pTipo, pPrecioUnitario, pCantidad 
            FROM LineasProducto 
            WHERE IdLineaProducto = pIdLineaProducto AND Estado = 'P';

            IF pTipo IS NULL OR pTipo != 'P' THEN
                SELECT f_generarRespuesta("ERROR_TIPO_INVALIDO", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pIndex = 0 THEN
                SET pIdCliente = (SELECT IdCliente FROM Presupuestos WHERE IdPresupuesto = pIdReferencia);
                IF pIdCliente > 0 AND pIdDomicilio > 0 THEN
                    IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
                        SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
                        LEAVE SALIR;
                    END IF;
                END IF;

                INSERT INTO Ventas (IdVenta, IdCliente, IdDomicilio, IdUbicacion, IdUsuario, FechaAlta, Observaciones, Estado)
                VALUES (0, pIdCliente, pIdDomicilio, pIdUbicacion, pIdUsuarioEjecuta, NOW(), pObservaciones, 'E');
                SET @pIdVenta = LAST_INSERT_ID();
            ELSE
                IF (SELECT IdCliente FROM Presupuestos WHERE IdPresupuesto = pIdReferencia) !=  pIdCliente THEN
                    SELECT f_generarRespuesta("ERROR_CLIENTE_INVALIDO", NULL) pOut;
                    LEAVE SALIR;
                END IF;
            END IF;

            UPDATE LineasProducto
            SET Estado = 'U'
            WHERE IdLineaProducto = pIdLineaProducto;

            UPDATE Presupuestos
            SET
                IdVenta = @pIdVenta,
                Estado = 'V'
            WHERE IdPresupuesto = pIdReferencia;

            INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado)
            VALUES (0, pIdLineaProducto, pIdProductoFinal, NULL, @pIdVenta, 'V', pPrecioUnitario, pCantidad, NOW(), NULL, 'P');

            SET pIndex := pIndex + 1;
        END WHILE;

        SET pIndex = 0;

        OPEN lineasPresupuestos_cursor;
            get_lineaPresupuesto: LOOP
                FETCH lineasPresupuestos_cursor INTO pIdLineaProductoPendiente;
                IF fin = 1 THEN
                    LEAVE get_lineaPresupuesto;
                END IF;

                UPDATE LineasProducto
                SET Estado = 'N'
                WHERE IdLineaProducto = pIdLineaProductoPendiente;
            END LOOP get_lineaPresupuesto;
        CLOSE lineasPresupuestos_cursor;

        SET pLineasVenta = COALESCE(pIn ->> "$.LineasVenta", JSON_ARRAY());
        SET pLongitud = JSON_LENGTH(pLineasVenta);

        WHILE pIndex < pLongitud DO
            SET pLineaVenta = JSON_EXTRACT(pLineasVenta, CONCAT("$[", pIndex, "]"));
            SET pLineaVenta = (SELECT JSON_SET(pLineaVenta, '$.LineasProducto.IdReferencia', @pIdVenta, '$.LineasProducto.Tipo', 'V'));
            CALL zsp_lineaVenta_crear_interno(pLineaVenta, pIdLineaProducto, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
            IF (SELECT PrecioUnitario FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'V') != f_calcularPrecioProductoFinal(pIdLineaProducto) THEN
                SET pEstado = 'R';
            END IF;

            SET pIndex = pIndex + 1;
        END WHILE;

        IF EXISTS(
            SELECT IdLineaProducto 
            FROM LineasProducto 
            WHERE 
                IdReferencia = @pIdVenta 
                AND Tipo = 'V'
                AND PrecioUnitario != f_calcularPrecioProductoFinal(IdProductoFinal) 
        ) THEN
            SET pEstado = 'R';
        END IF;

        UPDATE Ventas
        SET Estado = pEstado
        WHERE IdVenta = @pIdVenta;

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
                            "PrecioUnitario", lp.PrecioUnitario
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
            INNER JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
            INNER JOIN Ubicaciones ub ON ub.IdUbicacion = v.IdUbicacion
            LEFT JOIN LineasProducto lp ON v.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	v.IdVenta = @pIdVenta
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;