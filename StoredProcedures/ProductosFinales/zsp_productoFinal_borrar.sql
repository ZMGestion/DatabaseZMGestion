DROP PROCEDURE IF EXISTS `zsp_productoFinal_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar un producto final. Controla que no este siendo utilizado en un presupuesto, venta, órden de producción o remito.
        Devuelve NULL 'respuesta' o el error en 'error'.
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
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_borrar', pIdUsuarioEjecuta, pMensaje);
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

    IF EXISTS (SELECT pf.IdProductoFinal FROM ProductosFinales pf INNER JOIN LineasProducto lp ON pf.IdProductoFinal = lp.IdProductoFinal WHERE pf.IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE FROM ProductosFinales pf WHERE pf.IdProductoFinal = pIdProductoFinal;
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;

END $$
DELIMITER ;

{
    "UsuariosEjecuta":{
        "Token":"TOKEN"
    },
    "ProductosFinales":{
        "IdProductoFinal":13
    }
}