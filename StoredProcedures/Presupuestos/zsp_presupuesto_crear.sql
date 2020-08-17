DROP PROCEDURE IF EXISTS `zsp_presupuesto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un presupuesto. 
        Controla que exista el cliente para el cual se le esta creando, la ubicación donde se esta realizando y el usuario que lo está creando.
        Crea al Presupuesto en Estado 'E'.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdCliente = pPresupuestos ->> "$.IdCliente";
    SET pIdUbicacion = pProductos ->> "$.IdUbicacion";
    SET pObservaciones = pProductos ->> "$.Observaciones";

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT Valor INTO pPeriodoValidez FROM Empresa WHERE Parametro = 'PERIODOVALIDEZ'; 


    START TRANSACTION;

    INSERT INTO Presupuestos (IdPresupuesto, IdCliente, IdVenta, IdUbicacion, IdUsuario, PeriodoValidez, FechaAlta, Observaciones, Estado) VALUES(0, pIdCliente, NULL, pIdUbicacion, pIdUsuarioEjecuta, pPeriodoValidez, NOW(), NULLIF(pObservaciones, ''), 'E');

    SELECT MAX(IdPresupuesto) INTO pIdPresupuesto FROM Presupuestos;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Productos",  JSON_OBJECT(
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
