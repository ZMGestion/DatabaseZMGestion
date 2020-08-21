DROP PROCEDURE IF EXISTS `zsp_presupuesto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_modificar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un presupuesto existente. 
        Controla que el presupuesto no se encuentre en Estado 'Vendido' exista el cliente para el cual se le esta creando, la ubicación donde se esta realizando y el usuario que lo está modificando.
        Devuelve el presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuesto a crear
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;
    DECLARE pIdCliente int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pPeriodoValidez tinyint;
    DECLARE pObservaciones varchar(255);


    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdPresupuesto = pPresupuestos ->> "$.IdPresupuesto";
    SET pIdCliente = pPresupuestos ->> "$.IdCliente";
    SET pIdUbicacion = pProductos ->> "$.IdUbicacion";
    SET pObservaciones = pProductos ->> "$.Observaciones";

    IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) <> 'E' THEN
        SELECT f_generarRespuesta("ERROR_MODIFICAR_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;


    START TRANSACTION;

    UPDATE Presupuestos
    SET IdCliente = pIdCliente,
        IdUbicacion = pIdUbicacion,
        Observaciones = NULLIF(pObservaciones, '')
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
