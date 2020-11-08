DROP FUNCTION IF EXISTS `f_dameEstadoLineaVenta`;
DELIMITER $$
/*
    Permite determinar el estado de una linea de venta pudiendo devolver:
    P:Pendiente - C:Cancelada - R:Reservada - O:Produciendo - D:Pendiente de entrega - E:Entregada
*/
CREATE FUNCTION `f_dameEstadoLineaVenta`(pIdLineaVenta BIGINT) RETURNS CHAR(1)
    READS SQL DATA
BEGIN
    DECLARE pEstado CHAR(1);
    DECLARE pCantidadLineasRemito INT DEFAULT 0;
    DECLARE pCantidadLineasRemitoCanceladas INT DEFAULT 0;
    DECLARE pCantidadLineasRemitoPendientesDeEntrega INT DEFAULT 0;
    DECLARE pCantidadLineasRemitoEntregadas INT DEFAULT 0;

    DECLARE pCantidadLineasOrdenProduccionEnProceso INT DEFAULT 0;

    SET pEstado = (SELECT Estado FROM LineasProducto WHERE Tipo = 'V' AND IdLineaProducto = pIdLineaVenta);
    IF COALESCE(pEstado, 'C') = 'C' THEN
        RETURN pEstado;
    END IF;

    SELECT 
        COUNT(lr.IdLineaProducto), 
        COUNT(IF(lr.Estado = 'C', lr.Estado, NULL)),
        COUNT(IF(lr.Estado = 'P' AND r.FechaEntrega IS NULL, lr.Estado, NULL)),
        COUNT(IF(lr.Estado = 'P' AND r.FechaEntrega IS NOT NULL, lr.Estado, NULL))
        INTO pCantidadLineasRemito, pCantidadLineasRemitoCanceladas, pCantidadLineasRemitoPendientesDeEntrega, pCantidadLineasRemitoEntregadas
    FROM LineasProducto lv
    LEFT JOIN LineasProducto lr ON (lr.Tipo = 'R' AND lr.IdLineaProductoPadre = lv.IdLineaProducto)
    LEFT JOIN Remitos r ON (r.IdRemito = lr.IdReferencia)
    WHERE 
        lv.Tipo = 'V'
        AND lv.IdLineaProducto = pIdLineaVenta;

    SELECT
        COUNT(IF(lop.Estado = 'F', lop.Estado, NULL))
        INTO pCantidadLineasOrdenProduccionEnProceso
    FROM LineasProducto lv
    LEFT JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdLineaProductoPadre = lv.IdLineaProducto)
    WHERE 
        lv.Tipo = 'V'
        AND lv.IdLineaProducto = pIdLineaVenta;

    /*
        P:Pendiente: Se fija que no tenga lineas de remito hijas o si tiene que la lineas de remito hijas esten todas canceladas
    */
    IF pCantidadLineasRemito = pCantidadLineasRemitoCanceladas AND pCantidadLineasOrdenProduccionEnProceso = 0 THEN
        RETURN 'P';
    END IF;

    /*
        O:Produciendo: Se fija de tener una linea de orden de produccion hija que este en estado = "F"
    */
    IF pCantidadLineasOrdenProduccionEnProceso > 0 THEN
        RETURN 'O';
    END IF;

    /*
        D:PendienteDeEntrega: Se fija que tenga una linea de remito hija pendiente de entrega 
        y que el monto pagado sea suficiente para retirar.

        R:Reservada: Se fija que tenga una linea de remito hija pendiente de entrega
        y que el monto pagado no sea suficiente para retirar.
    */
    IF pCantidadLineasRemitoPendientesDeEntrega > 0 THEN
        IF f_puedeRetirar(pIdLineaVenta) = 'S' THEN
            RETURN 'D';
        ELSE
            RETURN 'R';
        END IF;
    END IF;

    /*
        E:Entregada: Se fija si tiene una linea remito hija entregada
    */
    IF pCantidadLineasRemitoEntregadas > 0 THEN
        RETURN 'E';
    END IF;

END $$
DELIMITER ;
