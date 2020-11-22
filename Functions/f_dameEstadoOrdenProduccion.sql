DROP FUNCTION IF EXISTS `f_dameEstadoOrdenProduccion`;
DELIMITER $$
/*
    Permite determinar el estado de una orden de producción pudiendo devolver:
    E:En Creación - P:Pendiente - C:Cancelada - R:En Producción - V:Verificada
*/
CREATE FUNCTION `f_dameEstadoOrdenProduccion`(pIdOrdenProduccion INT) RETURNS CHAR(1)
    READS SQL DATA
BEGIN
    DECLARE pEstado CHAR(1);
    DECLARE pCantidadTotal INT DEFAULT 0;
    DECLARE pCantidadCancelada INT DEFAULT 0;
    DECLARE pCantidadVerificada INT DEFAULT 0;
    DECLARE pCantidadTareas INT DEFAULT 0;

    SET pEstado = (SELECT Estado FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion);
    
    IF COALESCE(pEstado, 'E') = 'E' THEN
        RETURN pEstado;
    END IF;

    /*
        Pendiente: Si todas las lineas de orden de produccion asociadas que no se encuentren en estado "Cancelada" o "Verificadas" 
        se encuentran en estado "Pendiente de produccion".
    */
    SELECT 
        COUNT(*), 
        COUNT(IF(lop.Estado = 'C', lop.Estado, NULL)), 
        COUNT(IF(lop.Estado = 'V', lop.Estado, NULL)) 
        INTO pCantidadTotal, pCantidadCancelada, pCantidadVerificada
    FROM OrdenesProduccion op
    INNER JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdReferencia = op.IdOrdenProduccion)
    WHERE op.IdOrdenProduccion = pIdOrdenProduccion;

    IF pCantidadTotal = pCantidadCancelada THEN
        RETURN 'C';
    END IF;

    IF pCantidadTotal = pCantidadCancelada + pCantidadVerificada THEN
        RETURN 'V';
    END IF;

    IF NOT EXISTS(
        SELECT lp.IdLineaProducto, COUNT(t.IdTarea) CantidadTareas
        FROM OrdenesProduccion op
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'O' AND lp.IdReferencia = op.IdOrdenProduccion)
        LEFT JOIN Tareas t ON t.IdLineaProducto = lp.IdLineaProducto
        WHERE 
            IdOrdenProduccion = pIdOrdenProduccion
            AND (lp.Estado = 'F' AND t.Estado != 'P')
        GROUP BY lp.IdLineaProducto
        HAVING CantidadTareas > 0
    ) THEN
        RETURN 'P';
    END IF;

    RETURN 'R';
END $$
DELIMITER ;
