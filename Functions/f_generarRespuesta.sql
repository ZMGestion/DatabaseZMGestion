DROP FUNCTION IF EXISTS `f_generarRespuesta`;
DELIMITER $$
CREATE FUNCTION `f_generarRespuesta`(pCodigoError varchar(255), pRespuesta JSON, pEsLista CHAR(1)) RETURNS JSON
    DETERMINISTIC
BEGIN
    IF pEsLista = 'S' THEN
	    RETURN JSON_OBJECT("error", pCodigoError, "respuesta", CONCAT('[',pRespuesta,']'));
    ELSE
        RETURN JSON_OBJECT("error", pCodigoError, "respuesta", pRespuesta);
END $$
DELIMITER ;
