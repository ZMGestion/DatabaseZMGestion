DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_listar_tareas`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_listar_tareas`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar las tareas de una linea de orden de producción. 
        Controla que exista la linea de orden de producción.
        Devuelve las tareas en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Presupuesto
    DECLARE pIdLineaOrdenProduccion BIGINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pLineasPresupuesto JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_listar_tareas', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pIdLineaOrdenProduccion = pIn ->> "$.LineasProducto.IdLineaProducto";

    IF pIdLineaOrdenProduccion IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
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
            )
        FROM Tareas t
        INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
        LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
        WHERE IdLineaProducto = pIdLineaOrdenProduccion
    );
	
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;
