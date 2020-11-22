DROP FUNCTION IF EXISTS `f_puedeRetirar`;
DELIMITER $$
/*
    Pemite saber si con todo lo que pago y todo lo que retiro le alcanza para llevarse una línea de venta.
    Devuelve: S:Si - N:No
*/
CREATE FUNCTION `f_puedeRetirar`(pIdLineaVenta BIGINT) RETURNS CHAR(1)
    READS SQL DATA
BEGIN
    DECLARE pPrecioTotal DECIMAL(12,2);
    DECLARE pIdVenta INT;

    SELECT 
        Cantidad*PrecioUnitario,
        IdVenta
        INTO pPrecioTotal, pIdVenta
    FROM LineasProducto lv
    INNER JOIN Ventas v ON v.IdVenta = lv.IdReferencia
    WHERE 
        lv.Tipo = 'V'
        AND lv.IdLineaProducto = pIdLineaVenta;

    IF f_dameCreditoAFavor(pIdVenta) >= pPrecioTotal THEN
        RETURN 'S';
    ELSE
        RETURN 'N';
    END IF;

END $$
DELIMITER ;
