DROP FUNCTION IF EXISTS `f_dameEstadoLineaOrdenProduccion`;
DELIMITER $$
/*
    Permite determinar el estado de una linea de orden de producción pudiendo devolver:
    W:Pendiente de producción - I:En producción - V:Verificada
*/
CREATE FUNCTION `f_dameEstadoLineaOrdenProduccion`(pIdLineaOrdenProduccion BIGINT) RETURNS CHAR(1)
    READS SQL DATA
BEGIN
    DECLARE pEstado CHAR(1);
    DECLARE pCantidadTareas INT DEFAULT 0;
    DECLARE pCantidadTareasPendientes INT DEFAULT 0;

    SET pEstado = COALESCE((SELECT Estado FROM LineasProducto WHERE Tipo = 'O' AND IdLineaProducto = pIdLineaOrdenProduccion), '');

    IF pEstado = 'V' THEN
        RETURN 'V';
    END IF;

    IF pEstado = 'F' THEN
        SELECT 
            COUNT(IdTarea), 
            COUNT(IF(Estado = 'P', Estado, NULL))
            INTO pCantidadTareas, pCantidadTareasPendientes
        FROM Tareas
        WHERE IdLineaProducto = pIdLineaOrdenProduccion;

        IF pCantidadTareas = 0 OR pCantidadTareas = pCantidadTareasPendientes THEN
            RETURN 'W';
        END IF;
        
        RETURN 'I';
    END IF;

    RETURN '';

END $$
DELIMITER ;
