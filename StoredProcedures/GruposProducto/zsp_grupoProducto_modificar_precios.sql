DROP PROCEDURE IF EXISTS `zsp_grupoProducto_modificar_precios`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_modificar_precios` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar los precios de los productos pertenecientes a un determinado grupo en un porcentaje especificado.
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Grupo de productos
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pPorcentaje decimal(6,3);
    
    -- Precios
    DECLARE pPrecioActual decimal(10,2);
    DECLARE pPrecioNuevo decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Para el loop de productos
    DECLARE pIdProducto INT;
    DECLARE fin INTEGER DEFAULT 0;
    DECLARE productos_cursor CURSOR FOR
        SELECT IdProducto 
        FROM Productos p
        INNER JOIN GruposProducto gp ON p.IdGrupoProducto = gp.IdGrupoProducto
        WHERE gp.IdGrupoProducto = pIdGrupoProducto;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_modificar_precios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";
    SET pPorcentaje = pGruposProducto ->> "$.Porcentaje";

    IF pPorcentaje <= 0 OR pPorcentaje IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PORCENTAJE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdGrupoProducto IS NULL OR NOT EXISTS(SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    OPEN productos_cursor;
    get_producto: LOOP
        FETCH productos_cursor INTO pIdProducto;
        IF fin = 1 THEN
            LEAVE get_producto;
        END IF;

        SET pPrecioActual = (SELECT Precio FROM Precios WHERE IdPrecio = f_dameUltimoPrecio("P", pIdProducto));
        SET pPrecioNuevo = (SELECT pPrecioActual * pPorcentaje);

        INSERT INTO Precios (IdPrecio, Tipo, IdReferencia, Precio, FechaAlta) 
        VALUES (DEFAULT, "P", pIdProducto, pPrecioNuevo, NOW());
    END LOOP get_producto;
    CLOSE productos_cursor;

    SELECT f_generarRespuesta(NULL, NULL) AS pOut;

    COMMIT;

END $$
DELIMITER ;
