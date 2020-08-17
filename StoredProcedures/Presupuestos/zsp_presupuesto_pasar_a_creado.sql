DROP PROCEDURE IF EXISTS `zsp_presupuesto_pasar_a_creado`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_pasar_a_creado`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite pasar un presupuesto a creado. 
        Controla que exista presupuesto tenga al menos una linea de presupuesto asociada.
        Cambia el Estado a 'C'.
        Devuelve el presupuesto con sus lineas de presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuesto a crear
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;
    DECLARE pPeriodoValidez tinyint;


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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_pasar_a_creado', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdPresupuesto = pPresupuestos ->> "$.IdPresupuesto";

    IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT Valor INTO pPeriodoValidez FROM Empresa WHERE Parametro = 'PERIODOVALIDEZ'; 

    IF NOW() >= (SELECT DATE_ADD(FechaAlta, INTERVAL pPeriodoValidez DAY) FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_PRESUPUESTO_EXPIRADO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'P' AND IdReferencia = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_PRESUPUESTO_SINLINEAS", NULL) pOut;
        LEAVE SALIR;
    END IF;


    START TRANSACTION;

    UPDATE Presupuestos
    SET Estado = 'C'
    WHERE IdPresupuesto = pIdPresupuesto;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Presupuestos",  JSON_OBJECT(
                        'IdPresupuesto', p.IdPresupuesto,
                        'IdCliente', p.IdCliente,
                        'IdVenta', p.IdVenta,
                        'IdUbicacion', p.IdUbicacion,
                        'IdUsuario', p.IdUsuario,
                        'PeriodoValidez', p.PeriodoValidez,
                        'FechaAlta', p.FechaAlta,
                        'Observaciones', p.Observaciones,
                        'Estado', p.Estado
                        ) 
                )
             AS JSON)
			FROM	Presupuestos p
			WHERE	p.IdPresupuesto = pIdPresupuesto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;

