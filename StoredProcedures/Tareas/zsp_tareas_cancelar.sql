DROP PROCEDURE IF EXISTS zsp_tareas_cancelar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_cancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite cancelar una tarea.
        Pasa la tarea al estado: 'C' - Cancelada
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

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_cancelar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) NOT IN ('E','S','F') THEN
        SELECT f_generarRespuesta("ERROR_TAREA_CANCELAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaCancelacion = NOW(),
            Estado = 'C'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
