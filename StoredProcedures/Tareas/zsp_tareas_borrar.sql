DROP PROCEDURE IF EXISTS zsp_tareas_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una tarea.
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_borrar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) NOT IN ('P','C') THEN
        SELECT f_generarRespuesta("ERROR_TAREA_BORRAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTarea FROM Tareas WHERE IdTareaSiguiente = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_TAREA_BORRAR_TAREA_SIGUIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE FROM Tareas 
        WHERE IdTarea = pIdTarea;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT; 
END $$
DELIMITER ;
