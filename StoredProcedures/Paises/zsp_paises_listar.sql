DROP PROCEDURE IF EXISTS `zsp_paises_listar`;

DELIMITER $$
CREATE PROCEDURE  `zsp_paises_listar` ()

SALIR:BEGIN
    /*
        Procedimiento que permite listar todos los paises . 
        Devuelve un json todos los paises.
    */
    

    DECLARE pRespuesta JSON;



    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Paises",
                    JSON_OBJECT(
						'IdPais', IdPais,
                        'Pais', Pais
					)
                )
            )
	FROM Paises);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut; 

END $$
DELIMITER ;

