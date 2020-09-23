DROP FUNCTION IF EXISTS `f_calcularEstadoVenta`;
DELIMITER $$
CREATE FUNCTION `f_calcularEstadoVenta`(pIdVenta int) RETURNS CHAR(1)
    DETERMINISTIC
BEGIN
    /*
        Funcion que a partir calcula el estado de la venta.
        Las posibles respuestas son:
            - E: En creación
            - R: En revisión
            - A: Cancelada
            - N: Entregada
            - C: Pendiente
    */
    SET @pEstado = (SELECT Estado FROM Ventas WHERE IdVenta = pIdVenta);

    IF @pEstado IN ('E', 'R') THEN
        RETURN @pEstado;
    END IF;

    IF @pEstado = 'C' THEN
        -- La venta esta cancelada si todas las lineas de venta estan canceladas. 
        IF
            NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'V' AND IdReferencia = pIdVenta AND Estado != 'C')
        THEN
            RETURN 'A';
        END IF;

        -- La venta esta entregada, si todas las lineas de venta no canceladas estan entregadas.
        IF 
            (
                SELECT COUNT(lp.IdLineaProducto) 
                FROM LineasProducto lp 
                INNER JOIN LineasProducto lpp ON lpp.IdLineaProductoPadre = lp.IdLineaProducto 
                INNER JOIN Remitos r ON lpp.IdReferencia = r.IdRemito
                WHERE lpp.Tipo = 'R' AND lp.Estado = 'P' AND r.FechaEntrega IS NOT NULL
            ) = 
            (
                (
                    SELECT COUNT(IdLineaProducto)
                    FROM LineasProducto 
                    WHERE 
                        Tipo = 'V' 
                        AND IdReferencia = pIdVenta
                ) - 
                (
                    SELECT COUNT(IdLineaProducto)
                    FROM LineasProducto 
                    WHERE 
                        Tipo = 'V' 
                        AND IdReferencia = pIdVenta 
                        AND Estado = 'C'
                )
            )
        THEN
            RETURN 'N';
        END IF;

        RETURN 'C';
    END IF;
END $$
DELIMITER ;
