DROP FUNCTION IF EXISTS `f_calcularPrecioProductoFinal`;
DELIMITER $$
/*
    Funcion que permite calcular el precio unitario final de un producto final determinado.
*/
CREATE FUNCTION `f_calcularPrecioProductoFinal`(pIdProductoFinal int) RETURNS decimal(10,2)
    READS SQL DATA
BEGIN
    DECLARE pIdTela smallint;
    DECLARE pIdProducto int;
    DECLARE pIdPrecioProducto int;
    DECLARE pIdPrecioTela int;
    DECLARE pPrecioTela decimal(10,2);
    DECLARE pPrecioProducto decimal(10,2);
    DECLARE pLongitudTela decimal(5,2);
    DECLARE pPrecio decimal(10,2);

    SELECT IdProducto, IdTela INTO pIdProducto, pIdTela FROM ProductosFinales pf WHERE pf.IdProductoFinal = pIdProductoFinal; 
    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecioProducto;
    IF pIdTela IS NOT NULL THEN
        SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecioTela;
        SELECT LongitudTela INTO pLongitudTela FROM Productos WHERE IdProducto = pIdProducto;
    END IF;


    SELECT Precio INTO pPrecioProducto FROM Precios WHERE Tipo = 'P' AND IdPrecio = pIdPrecioProducto;
    IF pIdPrecioTela IS NOT NULL AND (pLongitudTela IS NOT NULL AND pLongitudTela > 0) THEN
        SELECT Precio INTO pPrecioTela FROM Precios WHERE Tipo = 'T' AND IdPrecio = pIdPrecioTela;
        SET pPrecioTela = pLongitudTela * pPrecioTela;
        SET pPrecio = pPrecioTela + pPrecioProducto;
    ELSE 
        SET pPrecio = pPrecioProducto;
    END IF;
    RETURN pPrecio;

END $$
DELIMITER ;
