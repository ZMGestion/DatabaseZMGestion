DROP PROCEDURE IF EXISTS `zsp_tiposDocumento_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_tiposDocumento_listar`()
BEGIN
	/*
		Lista todos los tipos de documento existentes y devuelve la lista de tipos documento en 'respuesta' o el codigo de error en 'error'.
	*/

    DECLARE pRespuesta TEXT;

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT('TiposDocumento',
                    JSON_OBJECT(
                        'IdTipoDocumento', IdTipoDocumento, 
                        'TipoDocumento', TipoDocumento,
                        'Descripcion', Descripcion
                    )
                )
            )
        ,'')
	FROM TiposDocumento
    ORDER BY TipoDocumento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
