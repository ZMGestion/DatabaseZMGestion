DROP FUNCTION IF EXISTS `f_generarRespuesta`;
DELIMITER $$
CREATE FUNCTION `f_generarRespuesta`(pCodigoError varchar(255), pRespuesta JSON) RETURNS JSON
    DETERMINISTIC
BEGIN
	RETURN JSON_OBJECT("error", pCodigoError, "respuesta", pRespuesta);
END $$
DELIMITER ;
