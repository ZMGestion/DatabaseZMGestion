DROP PROCEDURE IF EXISTS `zsp_ciudades_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ciudades_listar` (pIn JSON)
SALIR: BEGIN
    /*
        Permite listar todas las ciudades de una provincia y un pais particular.
    */

    DECLARE pPaises JSON;
    DECLARE pIdPais char(2);
    DECLARE pProvincia JSON;
    DECLARE pIdProvincia int;
    DECLARE pRespuesta JSON;

    SET pPaises = pIn ->> "$.Paises";
    SET pIdPais = pPaises ->> "$.IdPais";
    SET pProvincia = pIn ->> "$.Provincias";
    SET pIdProvincia = pProvincia ->> "$.IdProvincia";

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            "Ciudades",
            JSON_OBJECT(
                'IdCiudad', c.IdCiudad,
                'Ciudad', c.Ciudad
            )
        )
    ) 
    FROM Ciudades c
    WHERE IdPais = pIdPais AND IdProvincia = pIdProvincia
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;



END $$
DELIMITER ;