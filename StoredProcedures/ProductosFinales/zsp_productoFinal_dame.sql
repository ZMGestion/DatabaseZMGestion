DROP PROCEDURE IF EXISTS `zsp_productoFinal_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite instanciar un producto final a partir de su Id.
        Devuelve el producto final en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pTelas JSON;
    DECLARE pLustres JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProductoFinal = pProductosFinales ->> "$.IdProductoFinal";
    -- SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    -- SET pIdTela = pProductosFinales ->> "$.IdTela";
    -- SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT IdProducto, IdTela, IdLustre INTO pIdProducto, pIdTela, pIdLustre FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal;

    IF pIdTela IS NOT NULL THEN
        SET pTelas = ( 
            SELECT CAST(
                JSON_OBJECT(
                    'IdTela', t.IdTela,
                    'Tela', t.Tela,
                    'FechaAlta', t.FechaAlta,
                    'FechaBaja', t.FechaBaja,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ) AS JSON)
            FROM Telas t 
            WHERE t.IdTela = pIdTela
        );
    END IF;

    IF pIdLustre IS NOT NULL THEN
        SET pLustres = ( 
            SELECT CAST(
                JSON_OBJECT(
                    'IdLustre', IdLustre,
                    'Lustre', Lustre,
                    'Observaciones', Observaciones
                ) AS JSON)
            FROM Lustres l 
            WHERE t.IdLustre = pIdLustre
        );
    END IF;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "ProductosFinales",  JSON_OBJECT(
                        'IdProductoFinal', pf.IdProductoFinal,
                        'IdProducto', pf.IdProducto,
                        'IdLustre', pf.IdLustre,
                        'IdTela', pf.IdTela,
                        'FechaAlta', pf.FechaAlta,
                        'FechaBaja', pf.FechaBaja,
                        'Estado', pf.Estado
                    ),
                    "Productos",  JSON_OBJECT(
                        'IdProducto', p.IdProducto,
                        'IdCategoriaProducto', p.IdCategoriaProducto,
                        'IdGrupoProducto', p.IdGrupoProducto,
                        'IdTipoProducto', p.IdTipoProducto,
                        'Producto', p.Producto,
                        'LongitudTela', p.LongitudTela,
                        'FechaAlta', p.FechaAlta,
                        'FechaBaja', p.FechaBaja,
                        'Observaciones', p.Observaciones,
                        'Estado', p.Estado
                    ),
                    "Telas",  pTelas,
                    "Lustres",  pLustres
                )
             AS JSON)
			FROM	ProductosFinales pf
            INNER JOIN Productos p ON (pf.IdProducto = p.IdProducto)
            LEFT JOIN Telas t ON (pf.IdTela = t.IdTela)
            LEFT JOIN Lustres l ON (pf.IdLustre = l.IdLustre)
			WHERE	pf.IdProductoFinal = pIdProductoFinal
        );
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;

