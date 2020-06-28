DROP PROCEDURE IF EXISTS `zsp_cliente_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_cliente_dar_alta`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Cliente a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve el cliene en 'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;
    
    -- Respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";


    IF pIdCliente IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_CLIENTE', NULL)pOut;
        LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Clientes WHERE IdCliente = pIdCliente);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_CLIENTE', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (@pEstado = 'A') THEN
		SELECT f_generarRespuesta('ERROR_CLIENTE_ESTA_ALTA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Clientes
        SET Estado = 'A'
        WHERE IdCliente = pIdCliente;

        SET pRespuesta = (
            SELECT CAST(
                    COALESCE(
                        JSON_OBJECT(
                            'IdCliente', IdCliente,
                            'IdPais', IdPais,
                            'IdTipoDocumento', IdTipoDocumento,
                            'Documento', Documento,
                            'Tipo', Tipo,
                            'Nombres', Nombres,
                            'Apellidos', Apellidos,
                            'RazonSocial', RazonSocial,
                            'Telefono', Telefono,
                            'Email', Email,
                            'FechaAlta', FechaAlta,
                            'FechaBaja', FechaBaja,
                            'Estado', Estado
                        )
                    ,'') AS JSON)
            FROM	Clientes
            WHERE	IdCliente = pIdCliente
        );
        SELECT f_generarRespuesta(NULL, JSON_OBJECT("Clientes", pRespuesta)) AS pOut;
    COMMIT;

END $$
DELIMITER ;

