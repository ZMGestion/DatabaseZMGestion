DROP FUNCTION IF EXISTS `f_generarRespuestaLista`;
DELIMITER $$
CREATE FUNCTION `f_generarRespuestaLista`(pCodigoError varchar(255), pRespuesta JSON) RETURNS JSON
    DETERMINISTIC
BEGIN
    RETURN JSON_OBJECT("error", pCodigoError, "respuesta", IF(pRespuesta IS NOT NULL,pRespuesta, NULL));
END $$
DELIMITER ;
