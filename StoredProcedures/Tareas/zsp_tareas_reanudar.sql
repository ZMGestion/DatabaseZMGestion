DROP PROCEDURE IF EXISTS zsp_tareas_reanudar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_reanudar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite reanudar la ejecución de una tarea.
        Pasa la tarea al estado: 'E' - En proceso
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

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_reanudar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COAESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) NOT IN ('S','F','V','C') THEN
        SELECT f_generarRespuesta("ERROR_TAREA_REANUDAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaInicio = NOW(),
            Estado = 'E'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Tareas", JSON_OBJECT(
                        'IdTarea', IdTarea,
                        'IdLineaProducto', IdLineaProducto,
                        'IdTareaSiguiente', IdTareaSiguiente,
                        'IdUsuarioFabricante', IdUsuarioFabricante,
                        'Tarea', Tarea,
                        'FechaInicio', FechaInicio,
                        'FechaPausa', FechaPausa,
                        'FechaFinalizacion', FechaFinalizacion,
                        'FechaRevision', FechaRevision,
                        'FechaAlta', FechaAlta,
                        'FechaCancelacion', FechaCancelacion,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    )
                )
             AS JSON)
			FROM Tareas
			WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;