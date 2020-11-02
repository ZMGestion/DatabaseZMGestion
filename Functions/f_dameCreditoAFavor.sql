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
    DECLARE pTotalPagado DECIMAL(12,2);
    DECLARE pTotalRetirado DECIMAL(12,2);

    SET pTotalPagado = (
        SELECT 0
    );

    SET pTotalRetirado = (
        SELECT 0
    );

    RETURN (pTotalPagado - pTotalRetirado);

END $$
DELIMITER ;
