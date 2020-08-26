DROP PROCEDURE IF EXISTS `zsp_productoFinal_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un producto final. Llama a zsp_productoFinal_crear_interno.
        Devuelve el producto final, junto al producto, tela y lustre en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Producto Final
    DECLARE pIdProductoFinal int;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pError varchar(255);


     -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
    IF pError IS NULL THEN
        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "ProductosFinales",  JSON_OBJECT(
                        'IdProductoFinal', pf.IdProductoFinal,
                        'IdProducto', pf.IdProducto,
                        'IdLustre', pf.IdLustre,
                        'IdTela', pf.IdTela,
                        'FechaAlta', pf.FechaAlta,
                        'FechaBaja', pf.FechaBaja,
                        'Estado', pf.Estado
                    )
                )
             AS JSON)
			FROM	ProductosFinales pf
			WHERE	pf.IdProductoFinal = pIdProductoFinal
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    ELSE
        SELECT f_generarRespuesta(NULL, pError) AS pOut;
    END IF;

    

    
END $$
DELIMITER ;
