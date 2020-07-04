DROP PROCEDURE IF EXISTS `zsp_ubicaciones_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_ubicaciones_listar`()
SALIR: BEGIN

    /*
        Devuele un json con el listado de las ubicaciones
    */
    DECLARE pRespuesta JSON;

    SET pRespuesta  = (SELECT
        JSON_ARRAYAGG(
            JSON_OBJECT(
                "Ubicaciones",  JSON_OBJECT(
                    'IdUbicacion', u.IdUbicacion,
                    'IdDomicilio', u.IdDomicilio,
                    'Ubicacion', u.Ubicacion,
                    'FechaAlta', u.FechaAlta,
                    'FechaBaja', u.FechaBaja,
                    'Observaciones', u.Observaciones,
                    'Estado', u.Estado
                    ),
                "Domicilios", JSON_OBJECT(
                    'IdDomicilio', d.IdDomicilio,
                    'IdCiudad', d.IdCiudad,
                    'IdProvincia', d.IdProvincia,
                    'IdPais', d.IdPais,
                    'Domicilio', d.Domicilio,
                    'CodigoPostal', d.CodigoPostal,
                    'FechaAlta', d.FechaAlta,
                    'Observaciones', d.Observaciones
                ) 
            )
        )  
    FROM	Ubicaciones u
    INNER JOIN Domicilios d USING(IdDomicilio)
    );    
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
END $$
DELIMITER ;
