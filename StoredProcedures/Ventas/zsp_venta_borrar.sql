DROP PROCEDURE IF EXISTS zsp_venta_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_venta_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una venta.
        Controla que se encuentre en estado 'E'
        Devuelve NULL en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pVentas = pIn ->> '$.Ventas';
    SET pIdVenta = COALESCE(pVentas ->> '$.IdVenta', 0);

    IF pIdVenta != 0 THEN
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
            SELECT f_generarRespuesta("ERROR_BORRAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM Ventas
        WHERE IdVenta = pIdVenta;

        SELECT f_generarRespuesta(NULL, NULL)pOut;
    COMMIT;
END $$
DELIMITER ;
