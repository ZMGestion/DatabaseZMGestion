DROP PROCEDURE IF EXISTS zsp_remito_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar un remito que esta en estado 'En Creacion'
        Devuelve NULL en 'respuesta' o el error en 'error'
    */
    DECLARE pIdRemito int;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET @pEstado = (SELECT Estado FROM Remitos WHERE IdRemito = pIdRemito)

    IF (SELECT FechaEntrega FROM Remitos WHERE IdRemito = pIdRemito) IS NOT NULL OR @pEstado = 'B' THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdReferencia = pIdRemito AND Tipo = 'R') THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM Remitos
        WHERE IdRemito = pIdRemito;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;

END $$
DELIMITER ;
