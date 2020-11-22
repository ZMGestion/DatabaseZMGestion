DROP FUNCTION IF EXISTS `f_calcularStockProducto`;
DELIMITER $$
CREATE FUNCTION `f_calcularStockProducto`(pIdProductoFinal int, pIdUbicacion tinyint) RETURNS INT
    DETERMINISTIC
BEGIN
    /*
        Funcion que a calcula el producto stock de un producto final para una ubicacion especifica.
    */
    
    RETURN (
        SELECT COALESCE(SUM(IF(r.Tipo IN ('E', 'Y'), lp.Cantidad, -1 * lp.Cantidad)), 0)
        FROM Remitos r
        INNER JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = 'R'
        WHERE
            IF(r.Tipo IN ('E', 'Y'), r.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0, lp.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
            AND lp.IdProductoFinal = pIdProductoFinal
            AND f_calcularEstadoRemito(r.IdRemito) = 'N' AND lp.Estado != 'C');
END $$
DELIMITER ;
