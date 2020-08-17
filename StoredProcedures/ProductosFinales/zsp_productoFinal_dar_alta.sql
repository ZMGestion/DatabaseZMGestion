DROP PROCEDURE IF EXISTS `zsp_productoFinal_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_dar_alta`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de alta un producto final que se encontraba en estado "Baja". Controla que el producto final exista
        Devuelve un json con el producto en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProductoFinal = pProductosFinales ->> "$.IdProductoFinal";

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTOFINAL_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE ProductosFinales
        SET Estado = 'A'
        WHERE IdProductoFinal = pIdProductoFinal;

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
    COMMIT;


END $$
DELIMITER ;

