DROP PROCEDURE IF EXISTS `zsp_productoFinal_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un producto final. Controla que exista el producto, tela y lustre, y que no se repita la combinacion Producto, Tela y Lustre.
        Devuelve el producto final, junto al producto, tela y lustre en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;

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

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela IS NOT NULL AND pIdTela <> 0 THEN
        IF NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF pIdLustre IS NOT NULL AND NOT EXISTS (SELECT IdLustre FROM Lustres WHERE IdLustre = pIdLustre) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LUSTRE", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    -- Controlo que no se repita la combinacion Producto-Tela-Lustre o Producto-Lustre o Producto-Tela
    IF pIdLustre IS NOT NULL THEN
        IF pIdTela IS NOT NULL AND pIdTela <> 0 THEN
            IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdTela = pIdTela AND IdLustre = pIdLustre) THEN
                SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL", NULL) pOut;
                LEAVE SALIR;
            END IF;
        ELSE
            IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdLustre = pIdLustre) THEN
                SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL", NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
    ELSE
        IF pIdTela IS NOT NULL AND pIdTela <> 0 THEN
            IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdTela = pIdTela) THEN
                SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL", NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
    END IF;


    START TRANSACTION;
        INSERT INTO ProductosFinales (IdProductoFinal, IdProducto, IdLustre, IdTela, FechaAlta, FechaBaja, Estado) VALUES(0, pIdProducto, pIdLustre, IF(pIdTela = 0, NULL, pIdTela), NOW(), NULL, 'A');
        SET pIdProductoFinal = (SELECT MAX(IdProductoFinal) FROM ProductosFinales);

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
