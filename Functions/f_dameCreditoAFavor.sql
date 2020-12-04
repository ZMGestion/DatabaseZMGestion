DROP FUNCTION IF EXISTS `f_dameCreditoAFavor`;
DELIMITER $$
/*
    Permite conocer cuanto credito a favor tiene disponible el cliente para retirar productos.
    
    CreditoAFavor = TotalPagado - TotalRetirado

    TotalPagado: Realiza la suma del monto de todos los comprobantes del tipo "Recibo" 
    y resta el monto de los comprobantes del tipo "NotasCredito". 
    Devuelve 0 cuando ha pagado la venta por completo.

    TotalRetirado: Suma de los precios de los productos ya entregados.
*/
CREATE FUNCTION `f_dameCreditoAFavor`(pIdVenta INT) RETURNS DECIMAL(12,2)
    READS SQL DATA
BEGIN
    DECLARE pTotalPagado DECIMAL(12,2) DEFAULT 0;
    DECLARE pTotalRetirado DECIMAL(12,2) DEFAULT 0;

    SET pTotalPagado = COALESCE((
        SELECT SUM(Monto) 
        FROM Comprobantes 
        WHERE 
            IdVenta = pIdVenta 
            AND Tipo = 'R'
            AND Estado = 'A'
    ), 0);

    SET pTotalRetirado = COALESCE((
        SELECT SUM(IF(lr.IdLineaProducto IS NOT NULL, lv.PrecioUnitario * lv.Cantidad, 0)) 
        FROM LineasProducto lv
        LEFT JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lv.IdLineaProducto
        INNER JOIN Remitos r ON (r.IdRemito = lr.IdReferencia AND lr.Tipo = 'R')
        WHERE 
            lv.IdReferencia = pIdVenta 
            AND lv.Tipo = 'V'
            AND lr.Estado = 'P'
            AND r.FechaEntrega IS NOT NULL
    ), 0);
    

    RETURN (pTotalPagado - pTotalRetirado);

END $$
DELIMITER ;
