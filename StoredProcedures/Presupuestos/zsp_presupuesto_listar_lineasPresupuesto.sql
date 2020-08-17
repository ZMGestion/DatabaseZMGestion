DROP PROCEDURE IF EXISTS `zsp_presupuesto_listar_lineasPresupuesto`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_listar_lineasPresupuesto`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar las lineas de presupuesto de un presupuesto. 
        Controla que exista el presupuesto.
        Devuelve el presupuesto con sus lineas de presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuesto
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;


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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_listar_lineasPresupuesto', pIdUsuarioEjecuta, pMensaje);
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

    SET pLineasPresupuesto = (
        SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'IdLineaProducto', lp.IdLineaProducto,
                    'IdLineaProductoPadre', lp.IdLineaProductoPadre,
                    'IdProductoFinal', lp.IdProductoFinal,
                    'IdUbicacion', lp.IdUbicacion,
                    'IdReferencia', lp.IdReferencia,
                    'Tipo', lp.Tipo,
                    'PrecioUnitario', lp.PrecioUnitario,
                    'Cantidad', lp.Cantidad,
                    'FechaAlta', lp.FechaAlta,
                    'FechaCancelacion', lp.FechaCancelacion,
                    'Estado', lp.Estado
                )   
            )
        FROM LineasProducto lp
        WHERE IdReferencia = pIdPresupuesto AND Tipo = 'P'    
    );

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
                    ),
                    "LineasProducto", pLineasPresupuesto 
                )
             AS JSON)
			FROM	Presupuestos p
			WHERE	p.IdPresupuesto = pIdPresupuesto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;


END $$
DELIMITER ;

{
    "UsuariosEjecuta":{
        "Token":"TOKEN"
    },
    "Presupuestos":{
        "IdPresupuesto":1
    }
}