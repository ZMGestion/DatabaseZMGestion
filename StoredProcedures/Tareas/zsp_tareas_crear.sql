DROP PROCEDURE IF EXISTS zsp_tareas_crear;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una tarea para una linea de orden de producción
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pTarea VARCHAR(255);
    DECLARE pIdLineaProducto BIGINT;
    DECLARE pIdTareaSiguiente BIGINT;
    DECLARE pIdUsuarioFabricante SMALLINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_crear', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTarea = pIn->>'$.Tareas.Tarea';
    SET pIdLineaProducto = pIn->>'$.Tareas.IdLineaProducto';
    SET pIdTareaSiguiente = pIn->>'$.Tareas.IdTareaSiguiente';
    SET pIdUsuarioFabricante = pIn->>'$.Tareas.IdUsuarioFabricante';

    IF COALESCE(pTarea, '') = '' THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTareaSiguiente IS NOT NULL AND NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTareaSiguiente) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (
        SELECT IdRol 
        FROM Usuarios 
        WHERE 
            IdUsuario = pIdUsuarioFabricante 
            AND IdRol = (SELECT Valor FROM Empresa WHERE Parametro = 'IDROLFABRICANTE')
    ) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_USUARIO_FABRICANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Tareas (IdTarea, IdLineaProducto, IdTareaSiguiente, IdUsuarioFabricante, Tarea, FechaAlta, Estado)
        VALUES (DEFAULT, pIdLineaProducto, pIdTareaSiguiente, pIdUsuarioFabricante, pTarea, NOW(), 'P');
        
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
            WHERE IdTarea = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;