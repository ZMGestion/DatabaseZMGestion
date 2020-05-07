DROP FUNCTION IF EXISTS `f_generarRespuestaLista`;
DELIMITER $$
CREATE FUNCTION `f_generarRespuestaLista`(pCodigoError varchar(255), pRespuesta TEXT) RETURNS JSON
    DETERMINISTIC
BEGIN
    RETURN JSON_OBJECT("error", pCodigoError, "respuesta", CONCAT('[',pRespuesta,']'));
END $$
DELIMITER ;
