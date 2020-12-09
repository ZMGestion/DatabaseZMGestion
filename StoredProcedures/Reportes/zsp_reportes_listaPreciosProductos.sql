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

     SET pRespuesta = (
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                "Productos",  JSON_OBJECT(
                    'IdProducto', IdProducto,
                    'Producto', Producto
                    ),
                "Precios", JSON_OBJECT(
                    'Precio', COALESCE((SELECT Precio FROM Precios WHERE IdPrecio = f_dameUltimoPrecio('P', IdProducto)),0)
                ) 
            )
        )
        FROM	Productos
        WHERE Estado = 'A'
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
END $$
DELIMITER ;
