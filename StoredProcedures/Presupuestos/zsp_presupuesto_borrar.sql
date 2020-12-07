DROP PROCEDURE IF EXISTS zsp_presupuesto_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_presupuesto_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar un presupuesto. Controla que se encuentre en Estado = 'E', en caso positivo borra sus lineas tambien.
        Devuelve NULL en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuestos
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pPresupuestos = pIn ->> '$.Presupuestos';
    SET pIdPresupuesto = pPresupuestos ->> '$.IdPresupuesto';

    IF NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto AND Estado IN('E', 'C')) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'P' AND IdReferencia = pIdPresupuesto AND Estado = 'P') THEN
            DELETE
            FROM LineasProducto
            WHERE Tipo = 'P' AND IdReferencia = pIdPresupuesto;
        END IF;

        DELETE
        FROM Presupuestos
        WHERE IdPresupuesto = pIdPresupuesto;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;
