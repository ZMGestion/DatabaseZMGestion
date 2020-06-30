DROP FUNCTION IF EXISTS `f_dameUltimoPrecio`;
DELIMITER $$
CREATE FUNCTION `f_dameUltimoPrecio`(pTipo char(1), pIdReferencia int) RETURNS int
    READS SQL DATA
BEGIN
    DECLARE pIdPrecio int;

    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTela;
    
    CREATE TEMPORARY TABLE tmp_preciosTela AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = pTipo GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPrecios AS
    SELECT pr.* 
    FROM tmp_preciosTela tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pIdPrecio = (SELECT tmp.IdPrecio FROM tmp_ultimosPrecios tmp WHERE tmp.IdReferencia = pIdReferencia);

    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTela;

    RETURN pIdPrecio;
END $$
DELIMITER ;
