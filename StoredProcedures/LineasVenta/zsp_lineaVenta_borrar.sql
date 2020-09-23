DROP PROCEDURE IF EXISTS zsp_lineaVenta_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una linea de venta.
        Controla que se encuentre en estado 'P'.
        Devuelve NULL en respuesta o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = COALESCE(pLineasProducto ->> "$.IdLineaProducto", 0);

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Estado = 'P') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM LineasProducto
        WHERE IdLineaProducto = pIdLineaProducto;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;
