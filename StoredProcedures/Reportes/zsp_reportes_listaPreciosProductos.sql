DROP PROCEDURE IF EXISTS zsp_reportes_listaPreciosProductos;
DELIMITER $$
CREATE PROCEDURE zsp_reportes_listaPreciosProductos(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que devuelve los productos junto a su precio
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_reportes_listaPreciosProductos', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    SET pRespuesta = (
        SELECT CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
                "Productos",  JSON_OBJECT(
                    'IdProducto', IdProducto,
                    'Producto', Producto
                    ),
                "Precios", JSON_OBJECT(
                    'Precio', COALESCE((SELECT Precio FROM Precios WHERE IdPrecio = f_dameUltimoPrecio('P', IdProducto)),0)
                ) 
        ) ORDER BY Producto ASC),''), ']') AS JSON
        FROM	Productos
        WHERE Estado = 'A'
    );

    SET SESSION GROUP_CONCAT_MAX_LEN=15000;
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
END $$
DELIMITER ;
