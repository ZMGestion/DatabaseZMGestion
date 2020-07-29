DROP PROCEDURE IF EXISTS `zsp_cliente_listar_domicilios`;
DELIMITER $$
CREATE PROCEDURE `zsp_cliente_listar_domicilios`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite listar los domicilios de un cliente
        Devuelve un json con la lista de domicilios en respuesta o el codigo de error en error.
    */

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;
    
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    -- Extraigo los datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_CLIENTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

   SET pRespuesta  = (SELECT
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'Domicilios',
                    JSON_OBJECT(
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
                'Provincias', 
                    JSON_OBJECT(
                        'IdProvincia', pr.IdProvincia,
                        'IdPais', pr.IdPais,
                        'Provincia', pr.Provincia
                    ),
                'Paises', 
                    JSON_OBJECT(
                        'IdPais', p.IdPais,
                        'Pais', p.Pais
                    )
            )
        )  
    FROM	DomiciliosCliente dc
    INNER JOIN Domicilios d ON dc.IdDomicilio = d.IdDomicilio
    INNER JOIN Ciudades c ON d.IdCiudad = c.IdCiudad
    INNER JOIN Provincias pr ON pr.IdProvincia = c.IdProvincia
    INNER JOIN Paises p ON p.IdPais = pr.IdPais
    WHERE dc.IdCliente = pIdCliente
    );    
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;
