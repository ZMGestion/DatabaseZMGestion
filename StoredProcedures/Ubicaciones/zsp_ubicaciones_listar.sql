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
                ),
                'Ciudades', JSON_OBJECT(
                        'IdCiudad', c.IdCiudad,
                        'IdProvincia', c.IdProvincia,
                        'IdPais', c.IdPais,
                        'Ciudad', c.Ciudad
                    ),
                'Provincias', JSON_OBJECT(
                        'IdProvincia', pr.IdProvincia,
                        'IdPais', pr.IdPais,
                        'Provincia', pr.Provincia
                ),
                'Paises', JSON_OBJECT(
                        'IdPais', p.IdPais,
                        'Pais', p.Pais
                )
            )
        )  
    FROM	Ubicaciones u
    INNER JOIN Domicilios d ON u.IdDomicilio = d.IdDomicilio
    INNER JOIN Ciudades c ON d.IdCiudad = c.IdCiudad
    INNER JOIN Provincias pr ON pr.IdProvincia = c.IdProvincia
    INNER JOIN Paises p ON p.IdPais = pr.IdPais
    );    
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
END $$
DELIMITER ;
