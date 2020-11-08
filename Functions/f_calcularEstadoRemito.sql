DROP FUNCTION IF EXISTS `f_calcularEstadoRemito`;
DELIMITER $$
CREATE FUNCTION `f_calcularEstadoRemito`(pIdRemito int) RETURNS CHAR(1)
    DETERMINISTIC
BEGIN
    /*
        Funcion que a partir calcula el estado del remito.
        Las posibles respuestas son:
            - E: En creación
            - C: Creado
            - B: Cancelado
            - N: Entregado
    */
    SET @pEstado = (SELECT Estado FROM Remitos WHERE IdRemito = pIdRemito);

    IF @pEstado IN ('E', 'B') THEN
        RETURN @pEstado;
    END IF;

    IF @pEstado = 'C' THEN
        -- El remito esta entregado sin tiene fecha de entrega y es igual o anterior a ya. 
        IF EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND FechaEntrega IS NOT NULL AND FechaEntrega <= NOW())THEN
            RETURN 'N';
        ELSE
            RETURN @pEstado;
        END IF;
    END IF;
END $$
DELIMITER ;
