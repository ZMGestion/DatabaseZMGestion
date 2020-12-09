DROP PROCEDURE IF EXISTS zsp_reportes_listaPreciosTelas;
DELIMITER $$
CREATE PROCEDURE zsp_reportes_listaPreciosTelas(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que genera la lista de precios de las telas
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_reportes_listaPreciosTelas', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    SET pRespuesta = (
        SELECT CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
            "Telas",  JSON_OBJECT(
                'IdTela', IdTela,
                'Tela', Tela
                ),
            "Precios", JSON_OBJECT(
                'Precio', COALESCE((SELECT Precio FROM Precios WHERE IdPrecio = f_dameUltimoPrecio('T', IdTela)),0)
            ) 
        ) ORDER BY Tela ASC),''), ']') AS JSON)
        FROM	Telas
        WHERE Estado = 'A'
    );

    SET SESSION GROUP_CONCAT_MAX_LEN=15000;

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;
