DROP PROCEDURE IF EXISTS zsp_lineaRemito_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaRemito_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite una linea de remito. Controla que la linea de remito este pendiente de entrega.
        En caso de exito devuelve NULL en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdLineaRemito bigint;

    DECLARE pIdRemito int;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaRemito_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdLineaRemito = COALESCE(pIn->>'$.LineasProducto.IdLineaProducto', 0);

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito);

    -- Significa que no esta pendiente de entrega
    IF (SELECT FechaEntrega FROM Remitos WHERE IdRemito = pIdRemito) IS NOT NULL OR (SELECT Estado FROM Remitos WHERE IdRemito = pIdRemito) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM LineasProducto
        WHERE IdLineaProducto = pIdLineaRemito;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;
