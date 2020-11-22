DROP PROCEDURE IF EXISTS `zsp_productoFinal_crear_interno`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_crear_interno`(pIn JSON, out pIdProductoFinal int, out pError varchar(255))
SALIR:BEGIN
    /*
        Procedimiento que permite crear un producto final. Controla que exista el producto, tela y lustre, y que no se repita la combinacion Producto, Tela y Lustre.
        Devuelve el producto final, junto al producto, tela y lustre en 'respuesta' o el error en 'error'.
    */

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

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT "ERROR_NOEXISTE_PRODUCTO" INTO pError;
        LEAVE SALIR;
    END IF;

    IF ((SELECT tp.IdTipoProducto FROM TiposProducto tp INNER JOIN Productos p ON p.IdTipoProducto = tp.IdTipoProducto WHERE IdProducto = pIdProducto) != (SELECT Valor FROM Empresa WHERE Parametro = 'IDTIPOPRODUCTOFABRICABLE')) AND (pIdTela IS NOT NULL OR pIdLustre IS NOT NULL) THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTO_INVALIDO", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF pIdTela IS NOT NULL AND pIdTela != 0 THEN
        IF (SELECT LongitudTela FROM Productos WHERE IdProducto = pIdProducto) <=0 THEN
            SELECT f_generarRespuesta("ERROR_PRODUCTO_INVALIDO", NULL) pOut;
            LEAVE SALIR;
        END IF;
        IF NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
            SELECT "ERROR_NOEXISTE_TELA" INTO pError;
            LEAVE SALIR;
        END IF;
    END IF;

    IF pIdLustre IS NOT NULL AND pIdLustre != 0 THEN
        IF NOT EXISTS (SELECT IdLustre FROM Lustres WHERE IdLustre = pIdLustre) THEN
            SELECT "ERROR_NOEXISTE_LUSTRE" INTO pError;
            LEAVE SALIR;
        END IF;
    END IF;
    
    -- Controlo que no se repita la combinacion Producto-Tela-Lustre o Producto-Lustre o Producto-Tela
    IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
        SELECT "ERROR_EXISTE_PRODUCTOFINAL" INTO pError;
        LEAVE SALIR;
    END IF;

    INSERT INTO ProductosFinales (IdProductoFinal, IdProducto, IdLustre, IdTela, FechaAlta, FechaBaja, Estado) VALUES(0, pIdProducto, pIdLustre, IF(pIdTela = 0, NULL, pIdTela), NOW(), NULL, 'A');
    SET pIdProductoFinal = LAST_INSERT_ID();
    SET pError = NULL;

END $$
DELIMITER ;
