DROP PROCEDURE IF EXISTS `zsp_provincias_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_provincias_listar`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que devuelve una lista de provincias de un pais.
        Devuelve un JSON con las provincias
    
    */

    DECLARE pRespuesta JSON;
    DECLARE pPaises JSON;
    DECLARE pIdPais char(2);

    SET pPaises = pIn ->>"$.Paises";
    SET pIdPais = pPaises ->>"$.IdPais";


    SET pRespuesta = (SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            "Provincias",
            JSON_OBJECT(
                'IdProvincia', IdProvincia,
                'Provincia', Provincia
            )
        )
    ) 
    FROM Provincias 
    WHERE IdPais = pIdPais
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
