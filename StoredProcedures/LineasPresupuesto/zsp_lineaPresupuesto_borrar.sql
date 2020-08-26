DROP PROCEDURE IF EXISTS `zsp_lineaPresupuesto_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaPresupuesto_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar una linea de presupuesto. 
        Controla que la linea de presupuesto este en estado 'Pendiente'.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaPresupuesto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = pLineasProducto ->> "$.IdLineaProducto";

    IF pIdLineaProducto IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAPRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) <> 'P' THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_LINEAPRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;

        DELETE
        FROM LineasProducto 
        WHERE IdLineaProducto = pIdLineaProducto;
        
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;
END $$
DELIMITER ;
