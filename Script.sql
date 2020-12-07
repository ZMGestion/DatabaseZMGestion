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
DROP FUNCTION IF EXISTS `f_calcularEstadoVenta`;
DELIMITER $$
CREATE FUNCTION `f_calcularEstadoVenta`(pIdVenta int) RETURNS CHAR(1)
    DETERMINISTIC
BEGIN
    /*
        Funcion que a partir calcula el estado de la venta.
        Las posibles respuestas son:
            - E: En creación
            - R: En revisión
            - A: Cancelada
            - N: Entregada
            - C: Pendiente
    */
    DECLARE pEstado CHAR(1);

    SET pEstado = (SELECT Estado FROM Ventas WHERE IdVenta = pIdVenta);

    IF pEstado IN ('E', 'R') THEN
        RETURN pEstado;
    END IF;

    IF pEstado = 'C' THEN
        -- La venta esta cancelada si todas las lineas de venta estan canceladas. 
        IF
            NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'V' AND IdReferencia = pIdVenta AND Estado != 'C')
        THEN
            RETURN 'A';
        END IF;

        -- La venta esta entregada, si todas las lineas de venta no canceladas estan entregadas.
        IF 
            (
                SELECT COUNT(lp.IdLineaProducto) 
                FROM LineasProducto lp 
                INNER JOIN LineasProducto lpp ON lpp.IdLineaProductoPadre = lp.IdLineaProducto 
                INNER JOIN Remitos r ON lpp.IdReferencia = r.IdRemito
                WHERE lpp.Tipo = 'R' AND lp.Estado = 'P' AND r.FechaEntrega IS NOT NULL AND lp.IdReferencia = pIdVenta AND lp.Tipo = 'V'
            ) = 
            (
                (
                    SELECT COUNT(IdLineaProducto)
                    FROM LineasProducto 
                    WHERE 
                        Tipo = 'V' 
                        AND IdReferencia = pIdVenta
                ) - 
                (
                    SELECT COUNT(IdLineaProducto)
                    FROM LineasProducto 
                    WHERE 
                        Tipo = 'V' 
                        AND IdReferencia = pIdVenta 
                        AND Estado = 'C'
                )
            )
        THEN
            RETURN 'N';
        END IF;

        RETURN 'C';
    END IF;
END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_calcularPrecioProductoFinal`;
DELIMITER $$
/*
    Funcion que permite calcular el precio unitario final de un producto final determinado.
*/
CREATE FUNCTION `f_calcularPrecioProductoFinal`(pIdProductoFinal int) RETURNS decimal(10,2)
    READS SQL DATA
BEGIN
    DECLARE pIdTela smallint;
    DECLARE pIdProducto int;
    DECLARE pIdPrecioProducto int;
    DECLARE pIdPrecioTela int;
    DECLARE pPrecioTela decimal(10,2);
    DECLARE pPrecioProducto decimal(10,2);
    DECLARE pLongitudTela decimal(5,2);
    DECLARE pPrecio decimal(10,2);

    SELECT IdProducto, IdTela INTO pIdProducto, pIdTela FROM ProductosFinales pf WHERE pf.IdProductoFinal = pIdProductoFinal; 
    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecioProducto;
    IF pIdTela IS NOT NULL THEN
        SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecioTela;
        SELECT LongitudTela INTO pLongitudTela FROM Productos WHERE IdProducto = pIdProducto;
    END IF;


    SELECT Precio INTO pPrecioProducto FROM Precios WHERE Tipo = 'P' AND IdPrecio = pIdPrecioProducto;
    IF pIdPrecioTela IS NOT NULL AND (pLongitudTela IS NOT NULL AND pLongitudTela > 0) THEN
        SELECT Precio INTO pPrecioTela FROM Precios WHERE Tipo = 'T' AND IdPrecio = pIdPrecioTela;
        SET pPrecioTela = pLongitudTela * pPrecioTela;
        SET pPrecio = pPrecioTela + pPrecioProducto;
    ELSE 
        SET pPrecio = pPrecioProducto;
    END IF;
    RETURN pPrecio;

END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_calcularStockProducto`;
DELIMITER $$
CREATE FUNCTION `f_calcularStockProducto`(pIdProductoFinal int, pIdUbicacion tinyint) RETURNS INT
    DETERMINISTIC
BEGIN
    /*
        Funcion que a calcula el producto stock de un producto final para una ubicacion especifica.
    */
    
    RETURN (
        SELECT COALESCE(SUM(IF(r.Tipo IN ('E', 'Y'), lp.Cantidad, -1 * lp.Cantidad)), 0)
        FROM Remitos r
        INNER JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = 'R'
        WHERE
            IF(r.Tipo IN ('E', 'Y'), r.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0, lp.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
            AND lp.IdProductoFinal = pIdProductoFinal
            AND f_calcularEstadoRemito(r.IdRemito) = 'N' AND lp.Estado != 'C');
END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_dameCreditoAFavor`;
DELIMITER $$
/*
    Permite conocer cuanto credito a favor tiene disponible el cliente para retirar productos.
    
    CreditoAFavor = TotalPagado - TotalRetirado

    TotalPagado: Realiza la suma del monto de todos los comprobantes del tipo "Recibo" 
    y resta el monto de los comprobantes del tipo "NotasCredito". 
    Devuelve 0 cuando ha pagado la venta por completo.

    TotalRetirado: Suma de los precios de los productos ya entregados.
*/
CREATE FUNCTION `f_dameCreditoAFavor`(pIdVenta INT) RETURNS DECIMAL(12,2)
    READS SQL DATA
BEGIN
    DECLARE pTotalPagado DECIMAL(12,2) DEFAULT 0;
    DECLARE pTotalRetirado DECIMAL(12,2) DEFAULT 0;

    SET pTotalPagado = COALESCE((
        SELECT SUM(Monto) 
        FROM Comprobantes 
        WHERE 
            IdVenta = pIdVenta 
            AND Tipo = 'R'
            AND Estado = 'A'
    ), 0);

    SET pTotalRetirado = COALESCE((
        SELECT SUM(IF(lr.IdLineaProducto IS NOT NULL, lv.PrecioUnitario * lv.Cantidad, 0)) 
        FROM LineasProducto lv
        LEFT JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lv.IdLineaProducto
        INNER JOIN Remitos r ON (r.IdRemito = lr.IdReferencia AND lr.Tipo = 'R')
        WHERE 
            lv.IdReferencia = pIdVenta 
            AND lv.Tipo = 'V'
            AND lr.Estado = 'P'
            AND r.FechaEntrega IS NOT NULL
    ), 0);
    

    RETURN (pTotalPagado - pTotalRetirado);

END $$
DELIMITER ;
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

    IF pEstado IN('V','C') THEN
        RETURN pEstado;
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
DROP FUNCTION IF EXISTS `f_dameEstadoLineaVenta`;
DELIMITER $$
/*
    Permite determinar el estado de una linea de venta pudiendo devolver:
    P:Pendiente - C:Cancelada - R:Reservada - O:Produciendo - D:Pendiente de entrega - E:Entregada
*/
CREATE FUNCTION `f_dameEstadoLineaVenta`(pIdLineaVenta BIGINT) RETURNS CHAR(1)
    READS SQL DATA
BEGIN
    DECLARE pEstado CHAR(1);
    DECLARE pCantidadLineasRemito INT DEFAULT 0;
    DECLARE pCantidadLineasRemitoCanceladas INT DEFAULT 0;
    DECLARE pCantidadLineasRemitoPendientesDeEntrega INT DEFAULT 0;
    DECLARE pCantidadLineasRemitoEntregadas INT DEFAULT 0;

    DECLARE pCantidadLineasOrdenProduccionEnProceso INT DEFAULT 0;

    SET pEstado = (SELECT Estado FROM LineasProducto WHERE Tipo = 'V' AND IdLineaProducto = pIdLineaVenta);
    IF COALESCE(pEstado, 'C') = 'C' THEN
        RETURN pEstado;
    END IF;

    SELECT 
        COUNT(lr.IdLineaProducto), 
        COUNT(IF(lr.Estado = 'C', lr.Estado, NULL)),
        COUNT(IF(lr.Estado = 'P' AND r.FechaEntrega IS NULL, lr.Estado, NULL)),
        COUNT(IF(lr.Estado = 'P' AND r.FechaEntrega IS NOT NULL, lr.Estado, NULL))
        INTO pCantidadLineasRemito, pCantidadLineasRemitoCanceladas, pCantidadLineasRemitoPendientesDeEntrega, pCantidadLineasRemitoEntregadas
    FROM LineasProducto lv
    LEFT JOIN LineasProducto lr ON (lr.Tipo = 'R' AND lr.IdLineaProductoPadre = lv.IdLineaProducto)
    LEFT JOIN Remitos r ON (r.IdRemito = lr.IdReferencia)
    WHERE 
        lv.Tipo = 'V'
        AND lv.IdLineaProducto = pIdLineaVenta;

    SELECT
        COUNT(IF(lop.Estado = 'F', lop.Estado, NULL))
        INTO pCantidadLineasOrdenProduccionEnProceso
    FROM LineasProducto lv
    LEFT JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdLineaProductoPadre = lv.IdLineaProducto)
    WHERE 
        lv.Tipo = 'V'
        AND lv.IdLineaProducto = pIdLineaVenta;

    /*
        P:Pendiente: Se fija que no tenga lineas de remito hijas o si tiene que la lineas de remito hijas esten todas canceladas
    */
    IF pCantidadLineasRemito = pCantidadLineasRemitoCanceladas AND pCantidadLineasOrdenProduccionEnProceso = 0 THEN
        RETURN 'P';
    END IF;

    /*
        O:Produciendo: Se fija de tener una linea de orden de produccion hija que este en estado = "F"
    */
    IF pCantidadLineasOrdenProduccionEnProceso > 0 THEN
        RETURN 'O';
    END IF;

    /*
        D:PendienteDeEntrega: Se fija que tenga una linea de remito hija pendiente de entrega 
        y que el monto pagado sea suficiente para retirar.

        R:Reservada: Se fija que tenga una linea de remito hija pendiente de entrega
        y que el monto pagado no sea suficiente para retirar.
    */
    IF pCantidadLineasRemitoPendientesDeEntrega > 0 THEN
        IF f_puedeRetirar(pIdLineaVenta) = 'S' THEN
            RETURN 'D';
        ELSE
            RETURN 'R';
        END IF;
    END IF;

    /*
        E:Entregada: Se fija si tiene una linea remito hija entregada
    */
    IF pCantidadLineasRemitoEntregadas > 0 THEN
        RETURN 'E';
    END IF;

END $$
DELIMITER ;
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
DROP FUNCTION IF EXISTS `f_dameUltimoPrecio`;
DELIMITER $$
CREATE FUNCTION `f_dameUltimoPrecio`(pTipo char(1), pIdReferencia int) RETURNS int
    READS SQL DATA
BEGIN
    DECLARE pIdPrecio int;

    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTela;
    
    CREATE TEMPORARY TABLE tmp_preciosTela AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = pTipo GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPrecios AS
    SELECT pr.* 
    FROM tmp_preciosTela tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pIdPrecio = (SELECT tmp.IdPrecio FROM tmp_ultimosPrecios tmp WHERE tmp.IdReferencia = pIdReferencia);

    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTela;

    RETURN pIdPrecio;
END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_generarRespuesta`;
DELIMITER $$
CREATE FUNCTION `f_generarRespuesta`(pCodigoError varchar(255), pRespuesta JSON) RETURNS JSON
    DETERMINISTIC
BEGIN
    RETURN JSON_OBJECT("error", pCodigoError, "respuesta", pRespuesta);
END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_puedeRetirar`;
DELIMITER $$
/*
    Pemite saber si con todo lo que pago y todo lo que retiro le alcanza para llevarse una línea de venta.
    Devuelve: S:Si - N:No
*/
CREATE FUNCTION `f_puedeRetirar`(pIdLineaVenta BIGINT) RETURNS CHAR(1)
    READS SQL DATA
BEGIN
    DECLARE pPrecioTotal DECIMAL(12,2);
    DECLARE pIdVenta INT;

    SELECT 
        Cantidad*PrecioUnitario,
        IdVenta
        INTO pPrecioTotal, pIdVenta
    FROM LineasProducto lv
    INNER JOIN Ventas v ON v.IdVenta = lv.IdReferencia
    WHERE 
        lv.Tipo = 'V'
        AND lv.IdLineaProducto = pIdLineaVenta;

    IF f_dameCreditoAFavor(pIdVenta) >= pPrecioTotal THEN
        RETURN 'S';
    ELSE
        RETURN 'N';
    END IF;

END $$
DELIMITER ;
DROP FUNCTION IF EXISTS `f_split`;
DELIMITER $$
CREATE FUNCTION `f_split`(pCadena longtext, pDelimitador varchar(10), pIndice int) RETURNS text CHARSET utf8
    DETERMINISTIC
BEGIN
	
	RETURN	REPLACE(
				SUBSTR(
					SUBSTRING_INDEX(pCadena, pDelimitador, pIndice),
					CHAR_LENGTH(SUBSTRING_INDEX(pCadena, pDelimitador, pIndice -1)) + 1
				),
				pDelimitador, ''
			);
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_categoriasProducto_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_categoriasProducto_listar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar las categorias de producto.
        Devuelve una lista de categorias de producto en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_categoriasProducto_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "CategoriasProducto",
            JSON_OBJECT(
                'IdCategoriaProducto', IdCategoriaProducto,
                'Categoria', Categoria,
                'Descripcion', Descripcion
            )
        )
    ) 
    FROM CategoriasProducto
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ciudades_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ciudades_listar` (pIn JSON)
SALIR: BEGIN
    /*
        Permite listar todas las ciudades de una provincia y un pais particular.
    */

    DECLARE pProvincias JSON;
    DECLARE pIdPais char(2);
    DECLARE pIdProvincia int;
    DECLARE pRespuesta JSON;

    SET pProvincias = pIn ->> "$.Provincias";
    SET pIdPais = pProvincias ->> "$.IdPais";
    SET pIdProvincia = pProvincias ->> "$.IdProvincia";

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            "Ciudades",
            JSON_OBJECT(
                'IdCiudad', c.IdCiudad,
                'Ciudad', c.Ciudad
            )
        )
    ) 
    FROM Ciudades c
    WHERE IdPais = pIdPais AND IdProvincia = pIdProvincia
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_cliente_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_cliente_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar un cliente.
        Debe controlar que no tenga presupuestos, ventas, y domicilios asociados 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes->> "$.IdCliente";


    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_CLIENTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT c.IdCliente FROM Clientes c INNER JOIN Presupuestos p USING(IdCliente) WHERE c.IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_CLIENTE_PRESUPUESTO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT c.IdCliente FROM Clientes c INNER JOIN Ventas v USING(IdCliente) WHERE c.IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_CLIENTE_VENTA' , NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT dc.IdCliente FROM DomiciliosCliente dc WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_CLIENTE_DOMICILIO' , NULL) pOut;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Clientes WHERE IdCliente = pIdCliente;
    SELECT f_generarRespuesta(NULL, NULL) pOut;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_cliente_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_cliente_crear`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario crear un cliente controlando que no exista un cliente con el mismo email y tipo y número de documento, tambien crea un Domicilio para dicho cliente. 
        Debe existir el  TipoDocumento y el pais de Nacionalidad.
        Tipo puede ser: F:Fisica o J:Jurídica
        En caso de ser una persona fisica tendra DNI, Pasaporte o Libreta Civica , nombre y apellido, 
        En caso de una persona jurídica tendra CUIT y RazonSocial
        Devuelve un json con el cliente creado en respuesta o el codigo de error en error.
    */
    
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;
    DECLARE pIdPais char(2);
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pTipo char(1);
    DECLARE pFechaNacimiento date;
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pRazonSocial varchar(60);
    DECLARE pEmail varchar(120);
    DECLARE pTelefono varchar(15);
    
    -- Domicilio
    DECLARE pDomicilios JSON;
    DECLARE pIdDomicilio int;

    -- Para la creacion del domicilio
    DECLARE pRespuesta JSON;
    DECLARE pInInterno JSON;



    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo los datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdPais = pClientes ->> "$.IdPais";
    SET pIdTipoDocumento = pClientes ->> "$.IdTipoDocumento";
    SET pDocumento = pClientes ->> "$.Documento";
    SET pTipo = pClientes ->> "$.Tipo";
    SET pFechaNacimiento = pClientes ->> "$.FechaNacimiento";
    SET pNombres = pClientes ->> "$.Nombres";
    SET pApellidos = pClientes ->> "$.Apellidos";
    SET pRazonSocial = pClientes ->> "$.RazonSocial";
    SET pTelefono = pClientes ->> "$.Telefono";
    SET pEmail = pClientes ->> "$.Email";

    SET pDomicilios = pIn ->> "$.Domicilios";
    
    IF (pIdPais IS NULL OR NOT EXISTS (SELECT IdPais FROM Paises WHERE IdPais = pIdPais)) THEN
        SElECT f_generarRespuesta("ERROR_NOEXISTE_PAIS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TIPODOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN ('F', 'J') THEN
        SELECT f_generarRespuesta('ERROR_INVALIDO_TIPOPERSONA', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'J' AND pIdTipoDocumento <> (SELECT Valor FROM Empresa WHERE Parametro = 'IDTIPODOCUMENTOCUIT') THEN
        SELECT f_generarRespuesta("ERROR_TIPODOCUMENTO_JURIDICA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'J' AND ( pRazonSocial = '' OR pRazonSocial IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_RAZONSOCIAL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_DOCUMENTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdCliente FROM Clientes WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_CLIENTE_TIPODOC_DOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pFechaNacimiento IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_FECHANACIMIENTO', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pTipo = 'F' AND (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_NOMBRE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'F' AND (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_APELLIDO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELEFONO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Clientes WHERE Email = pEmail) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'F' AND (pRazonSocial IS NOT NULL OR pRazonSocial = '') THEN
            SET pRazonSocial = NULL;
    END IF;

    IF pTipo = 'J' AND (pNombres IS NOT NULL OR pApellidos IS NOT NULL)   THEN
            SET pNombres = NULL;
            SET pApellidos = NULL;
    END IF;

    START TRANSACTION;
        
        INSERT INTO Clientes (IdCliente,IdPais,IdTipoDocumento,Documento,Tipo,FechaNacimiento,Nombres,Apellidos,RazonSocial,Email,Telefono,FechaAlta,FechaBaja,Estado) VALUES (0, pIdPais, pIdTipoDocumento, pDocumento, pTipo, pFechaNacimiento, pNombres, pApellidos, pRazonSocial, pEmail, pTelefono, NOW(), NULL, 'A');
        SET pIdCliente = (SELECT IdCliente FROM Clientes WHERE IdCliente = LAST_INSERT_ID());
        IF (pDomicilios->>'$.Domicilio' != '' )THEN
            SET pInInterno = JSON_OBJECT("Domicilios", pDomicilios, "Clientes", JSON_OBJECT("IdCliente", pIdCliente));
            -- Armar el JSON para crear el domicilio para el cliente recien creado.
            CALL zsp_domicilio_crear_comun(pInInterno, pIdDomicilio, pRespuesta);

            IF pIdDomicilio IS NULL THEN
                SELECT pRespuesta pOut;
                ROLLBACK;
                LEAVE SALIR;
            END IF;
            SET pDomicilios = (
                SELECT CAST(
                        COALESCE(
                            JSON_OBJECT(
                                'IdDomicilio', IdDomicilio,
                                'IdCiudad', IdCiudad,
                                'IdProvincia', IdProvincia,
                                'IdPais', IdPais,
                                'Domicilio', Domicilio,
                                'CodigoPostal', CodigoPostal,
                                'FechaAlta', FechaAlta,
                                'Observaciones', Observaciones
                            )
                        ,'') AS JSON)
                FROM	Domicilios
                WHERE	IdDomicilio = pIdDomicilio
            );
        ELSE
            SET pDomicilios = NULL;    
        END IF;
        

        SET pRespuesta = (
            SELECT CAST(
                    JSON_OBJECT(
                        "Clientes", JSON_OBJECT(
                            'IdCliente', c.IdCliente,
                            'IdPais', c.IdPais,
                            'IdTipoDocumento', c.IdTipoDocumento,
                            'Documento', c.Documento,
                            'Tipo', c.Tipo,
                            'FechaNacimiento', c.FechaNacimiento,
                            'Nombres', c.Nombres,
                            'Apellidos', c.Apellidos,
                            'RazonSocial', c.RazonSocial,
                            'Email', c.Email,
                            'Telefono', c.Telefono,
                            'FechaAlta', c.FechaAlta,
                            'FechaBaja', c.FechaBaja,
                            'Estado', c.Apellidos
                            ),
                        "Domicilios", pDomicilios) 
                AS JSON)
        FROM	Clientes c
        WHERE	IdCliente = pIdCliente
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_cliente_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_cliente_dame`(pIn JSON)
SALIR:BEGIN
/*
        Permite instanciar un cliente a partir de su Id.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_dame', pIdUsuarioEjecuta, pMensaje);
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
                        'FechaNacimiento', FechaNacimiento,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
                    )
                ,'') AS JSON)
        FROM	Clientes
        WHERE	IdCliente = pIdCliente
    );
    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Clientes", pRespuesta)) AS pOut;


END $$
DELIMITER ;
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

DROP PROCEDURE IF EXISTS `zsp_cliente_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_cliente_dar_baja`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Cliente a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_dar_baja', pIdUsuarioEjecuta, pMensaje);
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

    IF (@pEstado = 'B') THEN
		SELECT f_generarRespuesta('ERROR_CLIENTE_ESTA_BAJA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Clientes
        SET Estado = 'B'
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
DROP PROCEDURE IF EXISTS `zsp_cliente_listar_domicilios`;
DELIMITER $$
CREATE PROCEDURE `zsp_cliente_listar_domicilios`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite listar los domicilios de un cliente
        Devuelve un json con la lista de domicilios en respuesta o el codigo de error en error.
    */

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;
    
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    -- Extraigo los datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_CLIENTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

   SET pRespuesta  = (SELECT
        JSON_ARRAYAGG(
            JSON_OBJECT(
                'Domicilios',
                    JSON_OBJECT(
                        'IdDomicilio', d.IdDomicilio, 
                        'IdCiudad', d.IdCiudad,
                        'IdProvincia', d.IdProvincia,
                        'IdPais', d.IdPais,
                        'Domicilio', d.Domicilio,
                        'CodigoPostal', d.CodigoPostal,
                        'FechaAlta', d.FechaAlta,
                        'Observaciones', d.Observaciones
                ),
                'Ciudades', JSON_OBJECT(
                        'IdCiudad', c.IdCiudad,
                        'IdProvincia', c.IdProvincia,
                        'IdPais', c.IdPais,
                        'Ciudad', c.Ciudad
                ),
                'Provincias', 
                    JSON_OBJECT(
                        'IdProvincia', pr.IdProvincia,
                        'IdPais', pr.IdPais,
                        'Provincia', pr.Provincia
                    ),
                'Paises', 
                    JSON_OBJECT(
                        'IdPais', p.IdPais,
                        'Pais', p.Pais
                    )
            )
        )  
    FROM	DomiciliosCliente dc
    INNER JOIN Domicilios d ON dc.IdDomicilio = d.IdDomicilio
    INNER JOIN Ciudades c ON d.IdCiudad = c.IdCiudad
    INNER JOIN Provincias pr ON pr.IdProvincia = c.IdProvincia
    INNER JOIN Paises p ON p.IdPais = pr.IdPais
    WHERE dc.IdCliente = pIdCliente
    );    
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_cliente_modificar`;
DELIMITER $$
CREATE PROCEDURE `zsp_cliente_modificar`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modificar un cliente existente controlando que no exista un cliente con el mismo email y tipo y número de documento. 
        Debe existir el  TipoDocumento y el pais de Nacionalidad.
        Tipo puede ser: F:Fisica o J:Jurídica
        En caso de ser una persona fisica tendra DNI, Pasaporte o Libreta Civica , nombre y apellido, 
        En caso de una persona jurídica tendra CUIT y RazonSocial
        Devuelve un json con el cliente creado en respuesta o el codigo de error en error.
    */
    
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;
    DECLARE pIdPais char(2);
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pTipo char(1);
    DECLARE pFechaNacimiento date;
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pRazonSocial varchar(60);
    DECLARE pEmail varchar(120);
    DECLARE pTelefono varchar(15);
    

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_cliente_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo los datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";
    SET pIdPais = pClientes ->> "$.IdPais";
    SET pIdTipoDocumento = pClientes ->> "$.IdTipoDocumento";
    SET pDocumento = pClientes ->> "$.Documento";
    SET pTipo = pClientes ->> "$.Tipo";
    SET pFechaNacimiento = pClientes ->> "$.FechaNacimiento";
    SET pNombres = pClientes ->> "$.Nombres";
    SET pApellidos = pClientes ->> "$.Apellidos";
    SET pRazonSocial = pClientes ->> "$.RazonSocial";
    SET pTelefono = pClientes ->> "$.Telefono";
    SET pEmail = pClientes ->> "$.Email";

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_CLIENTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdPais IS NULL OR NOT EXISTS (SELECT IdPais FROM Paises WHERE IdPais = pIdPais)) THEN
        SElECT f_generarRespuesta("ERROR_NOEXISTE_PAIS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TIPODOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN ('F', 'J') THEN
        SELECT f_generarRespuesta('ERROR_INVALIDO_TIPOPERSONA', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'J' AND pIdTipoDocumento <> (SELECT Valor FROM Empresa WHERE Parametro = 'IDTIPODOCUMENTOCUIT') THEN
        SELECT f_generarRespuesta("ERROR_TIPODOCUMENTO_JURIDICA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'J' AND ( pRazonSocial = '' OR pRazonSocial IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_RAZONSOCIAL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_DOCUMENTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdCliente FROM Clientes WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento AND IdCliente <> pIdCliente) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_CLIENTE_TIPODOC_DOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pFechaNacimiento IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_FECHANACIMIENTO', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pTipo = 'F' AND (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_NOMBRE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'F' AND (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_APELLIDO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELEFONO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Clientes WHERE Email = pEmail AND IdCliente <> pIdCliente) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo = 'F' AND (pRazonSocial IS NOT NULL OR pRazonSocial = '') THEN
            SET pRazonSocial = NULL;
    END IF;

    IF pTipo = 'J' AND (pNombres IS NOT NULL OR pApellidos IS NOT NULL)   THEN
            SET pNombres = NULL;
            SET pApellidos = NULL;
    END IF;

    START TRANSACTION;
        
        UPDATE Clientes
        SET IdPais = pIdPais,
            IdTipoDocumento = pIdTipoDocumento,
            Documento = pDocumento,
            Tipo = pTipo,
            FechaNacimiento = pFechaNacimiento,
            Nombres = pNombres,
            Apellidos = pApellidos,
            RazonSocial = pRazonSocial,
            Email = pEmail,
            Telefono = pTelefono
        WHERE IdCliente = pIdCliente;

        SET pClientes = (
            SELECT CAST(
                JSON_OBJECT(
                    'IdCliente', c.IdCliente,
                    'IdPais', c.IdPais,
                    'IdTipoDocumento', c.IdTipoDocumento,
                    'Documento', c.Documento,
                    'Tipo', c.Tipo,
                    'FechaNacimiento', c.FechaNacimiento,
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial,
                    'Email', c.Email,
                    'Telefono', c.Telefono,
                    'FechaAlta', c.FechaAlta,
                    'FechaBaja', c.FechaBaja,
                    'Estado', c.Apellidos
                ) AS JSON)
        FROM	Clientes c
        WHERE	IdCliente = pIdCliente
    );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Clientes", pClientes)) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_clientes_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_clientes_buscar` (pIn JSON)
SALIR: BEGIN
	/*
		Permite buscar los clientes por una cadena, o bien, nombres y apellidos, razon social, email, documento, telefono,
        Tipo de persona (F:Fisica - J:Juridica - T:Todos), estado (A:Activo - B:Baja - T:Todos), pais (**: Todos), 
	*/

   -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdPais char(2);
    DECLARE pDocumento varchar(15);
    DECLARE pTipo char(1);
    DECLARE pEstado char(1);
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pRazonSocial varchar(60);
    DECLARE pEmail varchar(120);
    DECLARE pTelefono varchar(15);
    DECLARE pNombresApellidos varchar(90);

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    DECLARE pRespuesta JSON;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_clientes_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pClientes = pIn ->> "$.Clientes";
    SET pIdPais = pClientes ->> "$.IdPais";
    SET pDocumento = pClientes ->> "$.Documento";
    SET pTipo = pClientes ->> "$.Tipo";
    SET pEstado = pClientes ->> "$.Estado";
    SET pNombres = pClientes ->> "$.Nombres";
    SET pApellidos = pClientes ->> "$.Apellidos";
    SET pRazonSocial = pClientes ->> "$.RazonSocial";
    SET pTelefono = pClientes ->> "$.Telefono";
    SET pEmail = pClientes ->> "$.Email";

    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    SET pNombres = COALESCE(pNombres,'');
    SET pApellidos = COALESCE(pApellidos,'');
    SET pNombresApellidos = CONCAT(pNombres, pApellidos);


    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pTipo IS NULL OR pTipo = '' OR pTipo NOT IN ('F','J') THEN
		SET pTipo = 'T';
	END IF;

    IF pIdPais IS NULL OR pIdPais = '' THEN
        SET pIdPais = '**';
    END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    
    SET pNombresApellidos = COALESCE(pNombresApellidos,'');
    SET pRazonSocial = COALESCE(pRazonSocial,'');
    SET pEmail = COALESCE(pEmail,'');
    SET pDocumento = COALESCE(pDocumento,'');
    SET pTelefono = COALESCE(pTelefono,'');
    SET pTipo = COALESCE(pTipo,'');

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    CREATE TEMPORARY TABLE tmp_ResultadosTotal
    SELECT *
    FROM Clientes 
    WHERE 
        Email LIKE CONCAT(pEmail, '%') AND
        Documento LIKE CONCAT(pDocumento, '%') AND
        Telefono LIKE CONCAT(pTelefono, '%') AND
        IF (RazonSocial IS NULL, CONCAT(Apellidos,',',Nombres) LIKE CONCAT('%', pNombresApellidos, '%'), RazonSocial LIKE CONCAT(pRazonSocial, '%')) AND 
        (IdPais = pIdPais OR pIdPais = '**') AND
        (Tipo = pTipo OR pTipo = 'T') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY CONCAT(Apellidos, ' ', Nombres), RazonSocial;

    -- Para devolver el total en paginaciones
    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_ResultadosTotal);

    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * FROM tmp_ResultadosTotal
    LIMIT pOffset, pLongitudPagina;

    
	SET pRespuesta = (SELECT
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Clientes",
                    JSON_OBJECT(
						'IdCliente', IdCliente,
                        'IdPais', IdPais,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Tipo', Tipo,
                        'FechaNacimiento', FechaNacimiento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'RazonSocial', RazonSocial,
                        'Email', Email,
                        'Telefono', Telefono,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
                )
            )
        )
	FROM tmp_ResultadosFinal);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS zsp_comprobante_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar un comprobante.
        Controla que la venta este en estado 'C'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdComprobante int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdComprobante = COALESCE(pIn ->>'$.Comprobantes.IdComprobante');

    IF NOT EXISTS(SELECT c.IdComprobante FROM Comprobantes c INNER JOIN Ventas v ON v.IdVenta = c.IdVenta WHERE c.IdComprobante = pIdComprobante AND v.Estado = 'C') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM Comprobantes
        WHERE IdComprobante = pIdComprobante;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_comprobante_crear;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear un nuevo comprobante.
        No puede repetirse el Numero y Tipo de Comprobante.
        Devuelve el comprobante en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pComprobantes JSON;
    DECLARE pIdVenta int;
    DECLARE pTipo char(1);
    DECLARE pNumeroComprobante int;
    DECLARE pMonto decimal(10,2);
    DECLARE pObservaciones varchar(255);

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_crear', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdVenta = COALESCE(pComprobantes ->> "$.IdVenta", 0);
    SET pTipo = COALESCE(pComprobantes ->> "$.Tipo", '');
    SET pNumeroComprobante = COALESCE(pComprobantes ->> "$.NumeroComprobante", 0);
    SET pMonto = COALESCE(pComprobantes ->> "$.Monto", 0.00);
    SET pObservaciones = pComprobantes ->> "$.Observaciones";

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'C') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN('A', 'B', 'N', 'M', 'R') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE NumeroComprobante = pNumeroComprobante AND Tipo = pTipo) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF pMonto <= 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_MONTO", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
        INSERT INTO Comprobantes (IdComprobante, IdVenta, IdUsuario, Tipo, NumeroComprobante, Monto, FechaAlta, FechaBaja, Observaciones, Estado) VALUES(0, pIdVenta, pIdUsuarioEjecuta, pTipo, pNumeroComprobante, pMonto, NOW(), NULL, pObservaciones, 'A');

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "Comprobantes",  JSON_OBJECT(
                        'IdComprobante', IdComprobante,
                        'IdVenta', IdVenta,
                        'IdUsuario', IdUsuario,
                        'Tipo', Tipo,
                        'NumeroComprobante', NumeroComprobante,
                        'Monto', Monto,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM	Comprobantes
            WHERE	IdComprobante = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_comprobante_dame;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instanciar un comprobante a partir de su Id.
        Devuelve el comprobante en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pComprobantes JSON;
    DECLARE pIdComprobante int;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdComprobante = COALESCE(pComprobantes ->> "$.IdComprobante");

    IF NOT EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdComprobante = pIdComprobante) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT CAST(
            JSON_OBJECT(
                "Comprobantes",  JSON_OBJECT(
                    'IdComprobante', IdComprobante,
                    'IdVenta', IdVenta,
                    'IdUsuario', IdUsuario,
                    'Tipo', Tipo,
                    'NumeroComprobante', NumeroComprobante,
                    'Monto', Monto,
                    'FechaAlta', FechaAlta,
                    'FechaBaja', FechaBaja,
                    'Observaciones', Observaciones,
                    'Estado', Estado
                ) 
            )
        AS JSON)
        FROM	Comprobantes
        WHERE	IdComprobante = pIdComprobante
    );
	
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_comprobante_dar_alta;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_dar_alta(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite dar de alta un comprobante. Controla que este en estado 'Baja'.
        Devuelve el comprobante en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE pComprobantes JSON;
    DECLARE pIdComprobante int;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->>"$.Comprobantes";
    SET pIdComprobante = COALESCE(pComprobantes->>"$.IdComprobante", 0);

    IF NOT EXISTS(SELECT c.IdComprobante FROM Comprobantes c INNER JOIN Ventas v ON v.IdVenta = c.IdVenta WHERE c.IdComprobante = pIdComprobante AND v.Estado  = 'C' AND c.Estado = 'B') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;
        UPDATE Comprobantes
        SET Estado = 'A'
        WHERE IdComprobante = pIdComprobante;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "Comprobantes",  JSON_OBJECT(
                        'IdComprobante', IdComprobante,
                        'IdVenta', IdVenta,
                        'IdUsuario', IdUsuario,
                        'Tipo', Tipo,
                        'NumeroComprobante', NumeroComprobante,
                        'Monto', Monto,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM	Comprobantes
            WHERE	IdComprobante = pIdComprobante
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_comprobante_dar_baja;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_dar_baja(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite dar de baja un comprobante. Controla que este en estado 'Alta'.
        Devuelve el comprobante en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE pComprobantes JSON;
    DECLARE pIdComprobante int;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->>"$.Comprobantes";
    SET pIdComprobante = COALESCE(pComprobantes->>"$.IdComprobante", 0);

    IF NOT EXISTS(SELECT c.IdComprobante FROM Comprobantes c INNER JOIN Ventas v ON v.IdVenta = c.IdVenta WHERE c.IdComprobante = pIdComprobante AND v.Estado  = 'C' AND c.Estado = 'A') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;
        UPDATE Comprobantes
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdComprobante = pIdComprobante;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "Comprobantes",  JSON_OBJECT(
                        'IdComprobante', IdComprobante,
                        'IdVenta', IdVenta,
                        'IdUsuario', IdUsuario,
                        'Tipo', Tipo,
                        'NumeroComprobante', NumeroComprobante,
                        'Monto', Monto,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM	Comprobantes
            WHERE	IdComprobante = pIdComprobante
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_comprobante_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_comprobante_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el numero, tipo y monto de un comprobante.
        No puede repetirse el Numero y Tipo de Comprobante.
        Devuelve el comprobante en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pComprobantes JSON;
    DECLARE pIdComprobante int;
    DECLARE pIdVenta int;
    DECLARE pTipo char(1);
    DECLARE pNumeroComprobante int;
    DECLARE pMonto decimal(10,2);
    DECLARE pObservaciones varchar(255);

    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobante_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdComprobante = COALESCE(pComprobantes ->> "$.IdComprobante");
    SET pTipo = COALESCE(pComprobantes ->> "$.Tipo", '');
    SET pNumeroComprobante = COALESCE(pComprobantes ->> "$.NumeroComprobante", 0);
    SET pMonto = COALESCE(pComprobantes ->> "$.Monto", 0.00);
    SET pObservaciones = pComprobantes ->> "$.Observaciones";

    IF NOT EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdComprobante = pIdComprobante) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN('A', 'B', 'N', 'M', 'R') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE NumeroComprobante = pNumeroComprobante AND Tipo = pTipo AND IdComprobante != pIdComprobante) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_COMPROBANTE", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF pMonto <= 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_MONTO", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
        UPDATE Comprobantes
        SET NumeroComprobante = pNumeroComprobante,
            Tipo = pTipo,
            Monto = pMonto
        WHERE IdComprobante = pIdComprobante;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "Comprobantes",  JSON_OBJECT(
                        'IdComprobante', IdComprobante,
                        'IdVenta', IdVenta,
                        'IdUsuario', IdUsuario,
                        'Tipo', Tipo,
                        'NumeroComprobante', NumeroComprobante,
                        'Monto', Monto,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM	Comprobantes
            WHERE	IdComprobante = pIdComprobante
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_comprobantes_buscar;
DELIMITER $$
CREATE PROCEDURE zsp_comprobantes_buscar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite buscar un comprobante a partir de:
            - Venta a la cual pertenece (0: Todas)
            - Usuario (0: Todos)
            - Numero (0: Todos)
            - Tipo de comprobante (A: Factura A, B: Factura B, N: Nota de Credito A, M: Nota de Credito B, R: Recibo, T:Todos).
        Devuelve el comporbante en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pComprobantes JSON;
    DECLARE pIdVenta int;
    DECLARE pIdUsuario smallint;
    DECLARE pTipo char(1);
    DECLARE pNumeroComprobante int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_comprobantes_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pComprobantes = pIn ->> "$.Comprobantes";
    SET pIdVenta = COALESCE(pComprobantes ->> "$.IdVenta", 0);
    SET pIdUsuario = COALESCE(pComprobantes ->> "$.IdUsuario", 0);
    SET pTipo = COALESCE(pComprobantes ->> "$.Tipo", 'T');
    SET pNumeroComprobante = COALESCE(pComprobantes ->> "$.NumeroComprobante", 0);

    IF pTipo IS NULL OR pTipo = '' THEN
        SET pTipo = 'T';
    END IF;

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT Valor FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantes;
    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantesPaginados;

    CREATE TEMPORARY TABLE tmp_comprobantes AS
    SELECT *
    FROM Comprobantes 
    WHERE 
    (
        (IdUsuario = pIdUsuario OR pIdUsuario = 0)
        AND (IdVenta = pIdVenta OR pIdVenta = 0)
        AND (Tipo = pTipo OR pTipo = 'T')
        AND (NumeroComprobante = pNumeroComprobante OR pNumeroComprobante = 0)
    );

    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_comprobantes);

    CREATE TEMPORARY TABLE  tmp_comprobantesPaginados AS
    SELECT * 
    FROM tmp_comprobantes
    LIMIT pOffset, pLongitudPagina;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                    "Pagina", pPagina,
                    "LongitudPagina", pLongitudPagina,
                    "CantidadTotal", pCantidadTotal
            ),
            'resultado', JSON_ARRAYAGG(
                JSON_OBJECT(
                    'Comprobantes', JSON_OBJECT(
                        'IdComprobante', IdComprobante,
                        'IdVenta', IdVenta,
                        'IdUsuario', IdUsuario,
                        'Tipo', Tipo,
                        'NumeroComprobante', NumeroComprobante,
                        'Monto', Monto,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    )
                )
            )
        )
        FROM tmp_comprobantesPaginados
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantes;
    DROP TEMPORARY TABLE IF EXISTS tmp_comprobantesPaginados;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_domicilio_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_domicilio_borrar` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite borrar un domicilio controlando que o hay sido utilizado en una venta, remito ni en una ubicacion. 
        Devuelve un json con NULL en respuesta o el codigo de error en error.
    */
    
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pDomicilios JSON;
    DECLARE pIdDomicilio int;
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_domicilio_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;


    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdDomicilio = pDomicilios ->> "$.IdDomicilio";

    IF NOT EXISTS (SELECT IdDomicilio FROM Domicilios  WHERE IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Ventas v USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Remitos r USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT d.IdDomicilio FROM Domicilios d INNER JOIN Ubicaciones u USING (IdDomicilio) WHERE d.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_DOMICILIO_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;
    


    START TRANSACTION;
        IF pIdCliente IS NULL THEN
            IF ( NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio)) THEN
                DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
            END IF;
        ELSE
            IF NOT EXISTS(SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente <> pIdCliente) THEN
                DELETE FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente ;
                DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
            ELSE
                DELETE FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente ;
            END IF;
            
            
        END IF;
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_domicilio_crear_comun`;

DELIMITER $$
CREATE PROCEDURE `zsp_domicilio_crear_comun`(pIn JSON, OUT pIdDomicilio int, OUT pOut JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un domicilio y asociarlo a un cliente en caso de ser necesario. 
        Debe existir el la ciudad, provincia y pais. Controla que no exista el mismo domicilio en la misma ciudad.
        El cliente es opcional.
        Devuelve el Id del domicilio o el error en pOut.
    */
    
    -- Domicilio
    DECLARE pDomicilios JSON;
    DECLARE pIdCiudad int;
    DECLARE pIdProvincia int;
    DECLARE pIdPais char(2);
    DECLARE pDomicilio varchar(120);
    DECLARE pCodigoPostal varchar(10);
    DECLARE pObservaciones varchar(255);

    -- Cliente
    DECLARE pClientes JSON;
    DECLARE pIdCliente int;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET pOut = f_generarRespuesta("ERROR_TRANSACCION", NULL);
        SET pIdDomicilio = NULL;
        ROLLBACK;
	END;

    -- Extraigo datos del Domicilio a crear
    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdCiudad = pDomicilios ->> "$.IdCiudad";
    SET pIdProvincia = pDomicilios ->> "$.IdProvincia";
    SET pIdPais = pDomicilios ->> "$.IdPais";
    SET pDomicilio = pDomicilios ->> "$.Domicilio";
    SET pCodigoPostal = pDomicilios ->> "$.CodigoPostal";
    SET pObservaciones = pDomicilios ->> "$.Observaciones";

    -- Extraigo datos del Cliente
    SET pClientes = pIn ->> "$.Clientes";
    SET pIdCliente = pClientes ->> "$.IdCliente";

    IF (pIdCliente IS NOT NULL AND NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pIdPais IS NULL OR NOT EXISTS (SELECT IdPais FROM Paises WHERE IdPais = pIdPais)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_PAIS", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pIdProvincia IS NULL OR NOT EXISTS (SELECT IdProvincia FROM Provincias WHERE IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_PROVINCIA", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pIdCiudad IS NULL OR NOT EXISTS (SELECT IdCiudad FROM Ciudades WHERE IdCiudad = pIdCiudad AND IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SET pOut = f_generarRespuesta("ERROR_NOEXISTE_CIUDAD", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF (pCodigoPostal IS NULL) THEN
        SET pOut = f_generarRespuesta("ERROR_INGRESAR_CP", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad) THEN
        SET pOut = f_generarRespuesta("ERROR_EXISTE_UBICACION_CIUDAD", NULL);
        SET pIdDomicilio = NULL;
        LEAVE SALIR;
    END IF;

    SET pIdDomicilio = (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad);
    -- En caso que el domicilio exista y el cliente no sea null, lo asocia al cliente con el domicilio
    IF (pIdDomicilio IS NOT NULL) THEN
        IF (pIdCliente IS NOT NULL) THEN
            IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
                INSERT INTO DomiciliosCliente VALUES (pIdDomicilio, pIdCliente, NOW());
                SET pOut = NULL;
            END IF;       
        ELSE
            SET pOut = f_generarRespuesta("ERROR_EXISTE_DOMICILIO", NULL);
                
        END IF;
    -- Si el domicilio no existe lo crea y lo asocia al cliente en caso de ser necesario
    ELSE
        INSERT INTO Domicilios (IdDomicilio,IdCiudad,IdProvincia,IdPais,Domicilio,CodigoPostal,FechaAlta,Observaciones) VALUES (0, pIdCiudad, pIdProvincia, pIdPais, pDomicilio, pCodigoPostal, NOW(), pObservaciones);
        SET pIdDomicilio = (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad);
        IF (pIdCliente IS NOT NULL) THEN
            INSERT INTO DomiciliosCliente VALUES (pIdDomicilio, pIdCliente, NOW());
        END IF;
        SET pOut = NULL;
    END IF;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_domicilio_crear`;
DELIMITER $$
CREATE PROCEDURE  `zsp_domicilio_crear` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite crear un domicilio.
        Llama al procedimiento zsp_domicilio_crear_comun
        Devuelve un json con el domicilio creado en respuesta o el codigo de error en error.
    */

    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    -- Para llamar al procedimiento zsp_domicilio_crear_comun
    DECLARE pRespuesta JSON;
    DECLARE pIdDomicilio int;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_domicilio_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        CALL zsp_domicilio_crear_comun(pIn, pIdDomicilio, pRespuesta);

        IF pIdDomicilio IS NULL THEN
            SELECT pRespuesta pOut;
            LEAVE SALIR;
        END IF;

        SET pRespuesta = (
        SELECT CAST(
                COALESCE(
                    JSON_OBJECT(
                        'IdDomicilio', IdDomicilio,
                        'IdCiudad', IdCiudad,
                        'IdProvincia', IdProvincia,
                        'IdPais', IdPais,
                        'Domicilio', Domicilio,
                        'CodigoPostal', CodigoPostal,
                        'FechaAlta', FechaAlta,
                        'Observaciones', Observaciones
                    )
                ,'') AS JSON)
        FROM	Domicilios
        WHERE	IdDomicilio = pIdDomicilio
        );
        SELECT f_generarRespuesta(NULL, JSON_OBJECT("Domicilios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_grupoProducto_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Permite instanciar un grupo de productos a partir de su Id.
        Devuelve el grupo de producto en 'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- GrupoProducto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto int;
    
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_GRUPOPRODUCTO', NULL)pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS (SELECT Estado FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_GRUPOPRODUCTO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
                    'IdGrupoProducto', IdGrupoProducto,
                    'Grupo', Grupo,
                    'FechaAlta', FechaAlta,
                    'FechaBaja', FechaBaja,
                    'Descripcion', Descripcion,
                    'Estado', Estado
                )
        FROM	GruposProducto
        WHERE	IdGrupoProducto = pIdGrupoProducto
    );
    SELECT f_generarRespuesta(NULL, JSON_OBJECT("GruposProducto", pRespuesta)) AS pOut;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_grupoProducto_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_borrar`(pIn JSON)
SALIR: BEGIN
	/*
        Permite borrar un grupo de producto. Controla que no exista ningun producto que pertenezca al grupo de productos.
        Devuelve NULL'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de prodcuto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProducto FROM Productos WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTO_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;


    DELETE FROM GruposProducto
    WHERE IdGrupoProducto = pIdGrupoProducto;

    SELECT f_generarRespuesta(NULL, NULL) AS pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_grupoProducto_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_dar_alta`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Grupo de productos a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve el grupo de productos en 'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de prodcuto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_GRUPOPRODUCTO_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;

        UPDATE GruposProducto
        SET Estado = 'A'
        WHERE IdGrupoProducto = pIdGrupoProducto;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE IdGrupoProducto = pIdGrupoProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_grupoProducto_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_dar_baja`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Grupo de productos a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve el grupo de productos en 'respuesta' o el codigo de error en 'error'.
	*/
	-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de prodcuto
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";


    IF pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_GRUPOPRODUCTO_ESTA_BAJA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;

        UPDATE GruposProducto
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdGrupoProducto = pIdGrupoProducto;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE IdGrupoProducto = pIdGrupoProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;

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
DROP PROCEDURE IF EXISTS `zsp_grupoProducto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_modificar` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un grupo de productos. Controla que no exista un Grupo de Productos con el mismo nombre.
        Devuelve el grupo de productos en 'respuesta' o el codigo de error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de producto a modificar
    DECLARE pGruposProducto JSON;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pGrupo varchar(40);
    DECLARE pDescripcion varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pIdGrupoProducto = pGruposProducto ->> "$.IdGrupoProducto";
    SET pGrupo = pGruposProducto ->> "$.Grupo";
    SET pDescripcion = pGruposProducto ->> "$.Descripcion";

    IF pIdGrupoProducto IS NULL OR NOT EXISTS(SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pGrupo = '' OR pGrupo IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE Grupo = pGrupo AND IdGrupoProducto <> pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    UPDATE GruposProducto
    SET Grupo = pGrupo,
        Descripcion = pDescripcion
    WHERE IdGrupoProducto = pIdGrupoProducto;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE IdGrupoProducto = pIdGrupoProducto
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_gruposProducto_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_gruposProducto_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar grupos producto por su nombre y Estado (A:Activo - B:Baja - T:Todos)
        Devuelve un JSON con la lista de grupos producto en respuesta o el error en error.        
    */

-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- GruposProducto
    DECLARE pGruposProducto JSON;
    DECLARE pGrupo varchar(40);
    DECLARE pEstado char(1);

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_gruposProducto_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pGrupo = pGruposProducto ->> "$.Grupo";
    SET pEstado = pGruposProducto ->> "$.Estado";

    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    SET pGrupo = COALESCE(pGrupo,'');

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    CREATE TEMPORARY TABLE tmp_ResultadosTotal
    SELECT *
	FROM GruposProducto 
	WHERE	
        Grupo LIKE CONCAT('%', pGrupo, '%') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY Grupo;

    -- Para devolver el total en paginaciones
    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_ResultadosTotal);

    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * FROM tmp_ResultadosTotal
    LIMIT pOffset, pLongitudPagina;

    SET pRespuesta = (SELECT
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", JSON_ARRAYAGG(
                JSON_OBJECT(
                    "GruposProducto",
                    JSON_OBJECT(
						'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
					)
                )
            )
        )
	FROM tmp_ResultadosFinal);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_grupoProducto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_grupoProducto_crear` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un grupo de productos. Controla que no exista un Grupo de Productos con el mismo nombre.
        Devuelve el Grupo en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Grupo de producto a crear
    DECLARE pGruposProducto JSON;
    DECLARE pGrupo varchar(40);
    DECLARE pDescripcion varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_grupoProducto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Grupos de producto
    SET pGruposProducto = pIn ->> "$.GruposProducto";
    SET pGrupo = pGruposProducto ->> "$.Grupo";
    SET pDescripcion = pGruposProducto ->> "$.Descripcion";

    IF pGrupo = '' OR pGrupo IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE Grupo = pGrupo) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    INSERT INTO GruposProducto (IdGrupoProducto, Grupo, FechaAlta, FechaBaja, Descripcion, Estado) VALUES (0, pGrupo, NOW(), NULL, NULLIF(pDescripcion, ''), 'A');

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "GruposProducto",  JSON_OBJECT(
                        'IdGrupoProducto', IdGrupoProducto,
                        'Grupo', Grupo,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Descripcion', Descripcion,
                        'Estado', Estado
                        )
                )
             AS JSON)
			FROM	GruposProducto
			WHERE	Grupo = pGrupo
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_borrar_interno`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_borrar_interno`(pIn JSON, OUT pError varchar(255))
SALIR:BEGIN
    /*
        Procedimiento que permite borrar una linea de orden de produccion. 
        Controla que la linea de orden de produccion este en estado 'PendienteDeProduccion'.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Linea de presupuesto
    DECLARE pIdLineaProducto BIGINT;

    DECLARE pIdRemito INT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    -- Extraigo atributos de la linea de presupuesto
    SET pIdLineaProducto = COALESCE(pIn ->> "$.LineasProducto.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O') THEN
        SET pError = "ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION";
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) NOT IN('F','C') 
        OR EXISTS(SELECT IdTarea FROM Tareas WHERE IdLineaProducto = pIdLineaProducto AND Estado NOT IN('P','C'))
    THEN
        SET pError = "ERROR_BORRAR_LINEA_ORDEN_PRODUCCION";
        LEAVE SALIR;
    END IF;

    -- Obtenemos el IdRemito de "Transformación entrada" (X) asociado, en caso de que se esté fabricando utilizando esqueletos
    SELECT DISTINCT r.IdRemito INTO pIdRemito 
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdLineaProducto = pIdLineaProducto 
            AND lop.Tipo = 'O';

    IF COALESCE(pIdRemito, 0) != 0 THEN
        -- Eliminamos todas las lineas de remito del remito
        DELETE FROM LineasProducto
        WHERE 
            IdReferencia = pIdRemito
            AND IdLineaProductoPadre = pIdLineaProducto
            AND Tipo = 'R';

        -- Eliminamos el remito
        DELETE FROM Remitos
        WHERE IdRemito = pIdRemito;
    END IF;

    DELETE
    FROM LineasProducto 
    WHERE IdLineaProducto = pIdLineaProducto;
    
    SET pError = NULL;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar una linea de orden de produccion. 
        Controla que la linea de orden de produccion este en estado 'PendienteDeProduccion'.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Linea de presupuesto
    DECLARE pIdLineaProducto BIGINT;

    DECLARE pIdRemito INT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pIdLineaProducto = COALESCE(pIn ->> "$.LineasProducto.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) NOT IN('F','C') 
        OR EXISTS(SELECT IdTarea FROM Tareas WHERE IdLineaProducto = pIdLineaProducto AND Estado NOT IN('P','C'))
    THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Obtenemos el IdRemito de "Transformación entrada" (X) asociado, en caso de que se esté fabricando utilizando esqueletos
    SELECT DISTINCT r.IdRemito INTO pIdRemito 
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdLineaProducto = pIdLineaProducto 
            AND lop.Tipo = 'O';

    START TRANSACTION;
        IF COALESCE(pIdRemito, 0) != 0 THEN
            -- Eliminamos todas las lineas de remito del remito
            DELETE FROM LineasProducto
            WHERE 
                IdReferencia = pIdRemito
                AND IdLineaProductoPadre = pIdLineaProducto
                AND Tipo = 'R';

            -- Eliminamos el remito
            DELETE FROM Remitos
            WHERE IdRemito = pIdRemito;
        END IF;

        DELETE
        FROM LineasProducto 
        WHERE IdLineaProducto = pIdLineaProducto;
        
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_cancelar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_cancelar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite cancelar una linea de orden de produccion. 
        Controla que la linea de orden de produccion no se encuentre verificada.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    DECLARE pIdRemitoAnterior INT;
    DECLARE pIdRemitoNuevo INT;

    -- Linea de presupuesto
    DECLARE pIdLineaProducto BIGINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_cancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pIdLineaProducto = COALESCE(pIn ->> "$.LineasProducto.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF COALESCE((SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O'),'') != 'F' THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT DISTINCT r.IdRemito INTO pIdRemitoAnterior
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdLineaProducto = pIdLineaProducto 
            AND lop.Tipo = 'O';

    START TRANSACTION;
        IF COALESCE(pIdRemitoAnterior, 0) != 0 THEN
            -- (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado)
            INSERT INTO Remitos 
            SELECT 0, IdUbicacion, IdUsuario, Tipo, NULL, NOW(), Observaciones, Estado FROM Remitos WHERE IdRemito = pIdRemitoAnterior;

            UPDATE LineasProducto
            SET IdReferencia = LAST_INSERT_ID()
            WHERE 
                IdLineaProductoPadre = pIdLineaProducto
                AND Tipo = 'R'; 

            IF NOT EXISTS(
                SELECT IdLineaProducto
                FROM LineasProducto
                WHERE  
                    IdReferencia = pIdRemitoAnterior
                    AND Tipo = 'R'
            ) THEN
                -- Quedó huerfana borramos el remito
                DELETE FROM Remitos
                WHERE IdRemito = pIdRemitoAnterior;
            END IF;
        END IF;

        UPDATE LineasProducto 
        SET Estado = 'C'
        WHERE 
            IdLineaProducto = pIdLineaProducto
            AND Tipo = 'O';

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
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
                    ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            AS JSON)
            FROM LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaProducto
        );
        
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear una linea de orden de produccion. 
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno.
        Devuelve la linea de orden de produccion en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Linea de orden de produccion a crear
    DECLARE pIdLineaProducto BIGINT;
    DECLARE pIdOrdenProduccion INT;
    DECLARE pIdProductoFinal INT;
    DECLARE pCantidad TINYINT;
    DECLARE pIdLineaOrdenProduccion BIGINT;

    DECLARE pUbicacion JSON;
    DECLARE pUbicaciones JSON;
    DECLARE pIdUbicacion TINYINT;
    DECLARE pCantidadUbicacion TINYINT;
    DECLARE pIdRemito BIGINT;
    DECLARE pCantidadRestante TINYINT;
    DECLARE pIdEsqueleto INT;

    DECLARE pIndice TINYINT DEFAULT 0;

    -- ProductoFinal
    DECLARE pIdProducto INT;
    DECLARE pIdTela SMALLINT;
    DECLARE pIdLustre TINYINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        ROLLBACK;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de orden de producción
    SET pIdOrdenProduccion = pIn ->> "$.LineasProducto.IdReferencia";
    -- Es la cantidad total. La diferencia con la suma de las cantidades de las ubicaciones, se produce sin remito de entrada.
    SET pCantidad = pIn ->> "$.LineasProducto.Cantidad"; 
    SET pCantidadRestante = pCantidad;
    
    SET pUbicaciones = COALESCE(pIn->>"$.Ubicaciones", JSON_ARRAY());

    -- Extraigo atributos del producto final
    SET pIdProducto = pIn ->> "$.ProductosFinales.IdProducto";
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela",0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre",0);

    IF NOT EXISTS (SELECT IdOrdenProduccion FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0 OR pCantidad IS NULL THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pMensaje);
            IF pMensaje IS NOT NULL THEN
                SELECT f_generarRespuesta(pMensaje, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
        
        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);
        SELECT IdProductoFinal INTO pIdEsqueleto FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdTela IS NULL AND IdLustre IS NULL;
 
        IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdOrdenProduccion AND Tipo = 'O' AND IdProductoFinal = pIdProductoFinal) THEN
            SELECT f_generarRespuesta("ERROR_ORDEN_PRODUCCION_EXISTE_PRODUCTOFINAL", NULL) pOut;
            LEAVE SALIR;
        END IF;

        INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
        VALUES(0, NULL, pIdProductoFinal, NULL, pIdOrdenProduccion, 'O', NULL, pCantidad, NOW(), NULL, 'F');

        SET pIdLineaOrdenProduccion = LAST_INSERT_ID();

        WHILE pIndice < JSON_LENGTH(pUbicaciones) DO
            SET pUbicacion = JSON_EXTRACT(pUbicaciones, CONCAT("$[", pIndice, "]"));
            SET pIdUbicacion = pUbicacion->>"$.IdUbicacion";
            SET pCantidadUbicacion = pUbicacion ->> "$.CantidadUbicacion";

            IF pCantidadRestante < pCantidadUbicacion OR pCantidadUbicacion < 0 THEN
                SELECT f_generarRespuesta("ERROR_CANTIDADUBICACION_INVALIDA", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
                SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pCantidadUbicacion <= 0 OR f_calcularStockProducto(pIdEsqueleto, pIdUbicacion) < pCantidadUbicacion THEN
                SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
                LEAVE SALIR;
            END IF;
            
            SELECT DISTINCT COALESCE(r.IdRemito, 0) INTO pIdRemito 
            FROM LineasProducto lop 
            INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
            INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
            WHERE 
                r.Tipo = 'X' 
                AND lop.IdReferencia = pIdOrdenProduccion 
                AND lop.Tipo = 'O';

            -- Creo el remito del tipo transformacion entrada (X)
            IF COALESCE(pIdRemito, 0) = 0 THEN
                INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, NULL, pIdUsuarioEjecuta, 'X', NULL, NOW(), 'Remito de transformación entrada para orden de producción', 'E');
                SET pIdRemito = LAST_INSERT_ID();
            END IF;

            INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
            VALUES(0, pIdLineaOrdenProduccion, pIdEsqueleto, pIdUbicacion, pIdRemito, 'R', NULL, pCantidadUbicacion, NOW(), NULL, 'P');
            
            SET pCantidadRestante =  pCantidadRestante - pCantidadUbicacion;
            SET pIndice = pIndice + 1;
        END WHILE;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
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
                    ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            AS JSON)
            FROM LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE lp.IdLineaProducto = pIdLineaOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_listar_tareas`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_listar_tareas`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar las tareas de una linea de orden de producción. 
        Controla que exista la linea de orden de producción.
        Devuelve las tareas en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Presupuesto
    DECLARE pIdLineaOrdenProduccion BIGINT;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_listar_tareas', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pIdLineaOrdenProduccion = pIn ->> "$.LineasProducto.IdLineaProducto";

    IF pIdLineaOrdenProduccion IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Tareas", JSON_OBJECT(
                        'IdTarea', t.IdTarea,
                        'IdLineaProducto', t.IdLineaProducto,
                        'IdTareaSiguiente', t.IdTareaSiguiente,
                        'IdUsuarioFabricante', t.IdUsuarioFabricante,
                        'IdUsuarioRevisor', t.IdUsuarioRevisor,
                        'Tarea', t.Tarea,
                        'FechaInicio', t.FechaInicio,
                        'FechaPausa', t.FechaPausa,
                        'FechaFinalizacion', t.FechaFinalizacion,
                        'FechaRevision', t.FechaRevision,
                        'FechaAlta', t.FechaAlta,
                        'FechaCancelacion', t.FechaCancelacion,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                    ),
                    "UsuariosFabricante", JSON_OBJECT(
						'IdUsuario', uf.IdUsuario,
                        'Nombres', uf.Nombres,
                        'Apellidos', uf.Apellidos,
                        'Estado', uf.Estado
					),
                    "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                        NULL, 
                        JSON_OBJECT(
                            'IdUsuario', ur.IdUsuario,
                            'Nombres', ur.Nombres,
                            'Apellidos', ur.Apellidos,
                            'Estado', ur.Estado
                        )
                    )
                )
            )
        FROM Tareas t
        INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
        LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
        WHERE IdLineaProducto = pIdLineaOrdenProduccion
    );
	
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaOrdenProduccion_reanudar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaOrdenProduccion_reanudar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite reanudar una linea de orden de produccion.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Linea de presupuesto
    DECLARE pIdLineaProducto BIGINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pIdRemito INT;

    DECLARE pIdProductosFinales JSON;
    DECLARE pLineaProducto JSON;
    DECLARE pIdLineaRemito BIGINT;
    DECLARE pIdProductoFinal INT;
    DECLARE pIdUbicacion INT;
    DECLARE pIndex INT DEFAULT 0;
    DECLARE pLongitud INT DEFAULT 0;
    DECLARE pCantidadStock INT;
    DECLARE pCantidadSolicitada INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaOrdenProduccion_reanudar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pIdLineaProducto = COALESCE(pIn ->> "$.LineasProducto.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF COALESCE((SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O'),'') != 'C' THEN
        SELECT f_generarRespuesta("ERROR_REANUDAR_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET @pIdLineaVentaPadre = (
        SELECT IdLineaProductoPadre FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O'
    );
    IF COALESCE(@pIdLineaVentaPadre, 0) > 0 THEN
        IF COALESCE((
            SELECT Cantidad
            FROM LineasProducto 
            WHERE 
                Tipo = 'V' 
                AND IdLineaProducto = @pIdLineaVentaPadre
                AND f_dameEstadoLineaVenta(IdLineaProducto) = 'P'
        ), 0) < (
            SELECT Cantidad 
            FROM LineasProducto 
            WHERE 
                IdLineaProducto = pIdLineaProducto 
                AND Tipo = 'O'
        ) THEN
            SELECT f_generarRespuesta("ERROR_REANUDAR_LINEA_ORDEN_PRODUCCION_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SELECT DISTINCT r.IdRemito INTO pIdRemito 
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdLineaProducto = pIdLineaProducto 
            AND lop.Tipo = 'O';

    START TRANSACTION;
        IF COALESCE(pIdRemito, 0) != 0 THEN
            SET pIdProductosFinales = (
                SELECT JSON_ARRAYAGG(JSON_OBJECT(
                    'IdLineaProducto', IdLineaProducto,
                    'IdLineaProductoPadre', IdLineaProductoPadre,
                    'IdProductoFinal', IdProductoFinal,
                    'IdUbicacion', IdUbicacion,
                    'Cantidad', Cantidad
                )) 
                FROM LineasProducto 
                WHERE 
                    IdReferencia = pIdRemito
                    AND Tipo = 'R'
            );

            SET pLongitud = JSON_LENGTH(pIdProductosFinales);

            WHILE pIndex < pLongitud DO
                SET pLineaProducto = JSON_EXTRACT(pIdProductosFinales, CONCAT("$[", pIndex, "]"));
                SET pIdProductoFinal = pLineaProducto->>"$.IdProductoFinal";
                SET pIdLineaRemito = pLineaProducto->>"$.IdLineaProducto";
                SET pIdUbicacion = pLineaProducto->>"$.IdUbicacion";

                SET pCantidadSolicitada = (
                    SELECT Cantidad 
                    FROM LineasProducto 
                    WHERE IdLineaProducto = pIdLineaRemito
                );

                IF f_calcularStockProducto(pIdProductoFinal, pIdUbicacion) < pCantidadSolicitada THEN
                    SELECT f_generarRespuesta("ERROR_SIN_STOCK", NULL) pOut;
                    LEAVE SALIR;
                END IF;

                SET pIndex = pIndex + 1;
            END WHILE;

            UPDATE Remitos
            SET FechaEntrega = NOW()
            WHERE IdRemito = pIdRemito; 
        END IF;

        UPDATE LineasProducto 
        SET Estado = 'F'
        WHERE 
            IdLineaProducto = pIdLineaProducto
            AND Tipo = 'O';

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
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
                    ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            AS JSON)
            FROM LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaProducto
        );
        
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineasOrdenProduccion_verificar;
DELIMITER $$
CREATE PROCEDURE zsp_lineasOrdenProduccion_verificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite verificar una línea de órden de producción.
        Devuelve la línea de órden de producción en 'respuesta' o el error en 'error'
    */

    DECLARE pLineasOrdenProduccion JSON;
    DECLARE pLineaOrdenProduccion JSON;
    DECLARE pIdOrdenProduccion INT;
    DECLARE pIdLineaOrdenProduccion bigint;
    DECLARE pIndice tinyint DEFAULT 0;
    DECLARE pIdRemitoTransformacion BIGINT;
    DECLARE pIdRemito BIGINT;
    DECLARE pIdUbicacion TINYINT;

    -- Para lineas remito
    DECLARE pIdProductoFinal INT;
    DECLARE pCantidad TINYINT;

    DECLARE pRespuesta JSON;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdVenta INT;
    DECLARE pIdLineaVenta BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineasOrdenProduccion_verificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF; 
    
    SET pLineasOrdenProduccion = COALESCE(pIn->>'$.LineasOrdenProduccion', JSON_ARRAY());
    SET pIdUbicacion = COALESCE(pIn ->> "$.Ubicaciones.IdUbicacion", 0); 

    IF JSON_LENGTH(pLineasOrdenProduccion) = 0 THEN
        SELECT f_generarRespuesta("ERROR_SIN_LINEASORDENPRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
        WHILE pIndice < JSON_LENGTH(pLineasOrdenProduccion) DO
            SET pLineaOrdenProduccion = JSON_EXTRACT(pLineasOrdenProduccion, CONCAT("$[", pIndice, "]"));
            SET pIdLineaOrdenProduccion = COALESCE(pLineaOrdenProduccion->>'$.IdLineaProducto', 0);

            IF pIndice = 0 THEN
                SET pIdOrdenProduccion = (SELECT COALESCE(IdReferencia, 0) FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Tipo = 'O');
            END IF;

            IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Tipo = 'O') THEN
                SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAORDENPRODUCCION", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF f_dameEstadoLineaOrdenProduccion(pIdLineaOrdenProduccion) != 'I' THEN
                SELECT f_generarRespuesta("ERROR_VERIFICAR_LINEAORDENPRODUCCION_ESTADO_LINEA", NULL) pOut;
                LEAVE SALIR;
            END IF; 

            IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion AND IdReferencia = pIdOrdenProduccion AND Tipo = 'O') THEN
                SELECT f_generarRespuesta("ERROR_DIFERENTE_ORDEN_LINEAORDENPRODUCCION", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF EXISTS(SELECT IdTarea FROM Tareas WHERE IdLineaProducto = pIdLineaOrdenProduccion AND Estado != 'V') THEN
                SELECT f_generarRespuesta("ERROR_NOVERIFICADAS_TAREAS", NULL) pOut;
                LEAVE SALIR;
            END IF;

            SELECT IdProductoFinal, Cantidad INTO pIdProductoFinal, pCantidad FROM LineasProducto WHERE IdLineaProducto = pIdLineaOrdenProduccion;

            IF EXISTS(
                SELECT lr.IdLineaProducto 
                FROM LineasProducto lo 
                INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
                INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
                WHERE 
                    lo.IdLineaProducto = pIdLineaOrdenProduccion
                    AND r.Tipo = 'X'
            ) THEN
                -- El producto final está siendo transformado. 
                -- Seteo en remito el Id del remito de transformacion entrada.
                SET pIdRemito = (
                    SELECT DISTINCT r.IdRemito 
                    FROM LineasProducto lo 
                    INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
                    INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
                    WHERE 
                        lo.IdLineaProducto = pIdLineaOrdenProduccion
                        AND r.Tipo = 'Y'
                );
                IF pIdRemito IS NULL THEN
                    INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) 
                    VALUES(0, pIdUbicacion, pIdUsuarioEjecuta, 'Y', NULL, NOW(), 'Remito de transformación salida por orden de producción', 'C');

                    SET pIdRemito = LAST_INSERT_ID();
                END IF;

                INSERT INTO LineasProducto(IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaOrdenProduccion, pIdProductoFinal, NULL, pIdRemito, 'R', NULL, pCantidad, NOW(), NULL, 'P');
            ELSE
                SET pIdRemito = (
                    SELECT DISTINCT r.IdRemito 
                    FROM LineasProducto lo 
                    INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
                    INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
                    WHERE 
                        lo.IdLineaProducto = pIdLineaOrdenProduccion
                        AND r.Tipo = 'E'
                );

                IF pIdRemito IS NULL THEN
                    INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) 
                    VALUES(0, pIdUbicacion, pIdUsuarioEjecuta, 'E', NULL, NOW(), 'Remito de entrada por orden de producción', 'C');
                    SET pIdRemito = LAST_INSERT_ID();            
                END IF;

                INSERT INTO LineasProducto(IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaOrdenProduccion, pIdProductoFinal, NULL, pIdRemito, 'R', NULL, pCantidad, NOW(), NULL, 'P');
            END IF;

            -- Si viene a partir de una venta generamos un remito de salida para la venta asociada a la linea de venta.
            SELECT DISTINCT lv.IdLineaProducto, lv.IdReferencia INTO pIdLineaVenta, pIdVenta
            FROM LineasProducto lop
            INNER JOIN LineasProducto lv ON lv.IdLineaProducto = lop.IdLineaProductoPadre AND lv.Tipo = 'V'
            WHERE lop.IdLineaProducto = pIdLineaOrdenProduccion;
            
            IF COALESCE(pIdLineaVenta, 0) != 0 THEN
                INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) 
                VALUES(0, NULL, pIdUsuarioEjecuta, 'S', NULL, NOW(), 'Remito de reserva', 'C');

                INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaVenta, pIdProductoFinal, pIdUbicacion, LAST_INSERT_ID(), 'R', NULL, pCantidad, NOW(), NULL, 'P');
            END IF;

            UPDATE LineasProducto
            SET Estado = 'V'
            WHERE 
                IdLineaProducto = pIdLineaOrdenProduccion 
                AND Tipo = 'O';

            SET pIndice = pIndice + 1;
        END WHILE;

        SET pIdRemito = (
            SELECT DISTINCT r.IdRemito 
            FROM LineasProducto lo
            INNER JOIN OrdenesProduccion op ON lo.IdReferencia = op.IdOrdenProduccion AND lo.Tipo = 'O' 
            INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
            INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
            WHERE 
                op.IdOrdenProduccion = pIdOrdenProduccion
                AND r.Tipo = 'E'
        );

        IF pIdRemito IS NOT NULL THEN
            UPDATE Remitos
            SET Estado = 'C',
                FechaEntrega = NOW()
            WHERE IdRemito = pIdRemito;
        END IF;

        SET pIdRemito = (
            SELECT DISTINCT r.IdRemito 
            FROM LineasProducto lo
            INNER JOIN OrdenesProduccion op ON lo.IdReferencia = op.IdOrdenProduccion AND lo.Tipo = 'O' 
            INNER JOIN LineasProducto lr ON lo.IdLineaProducto = lr.IdLineaProductoPadre AND lr.Tipo = 'R'
            INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
            WHERE 
                op.IdOrdenProduccion = pIdOrdenProduccion
                AND r.Tipo = 'X'
        );
        IF pIdRemito IS NOT NULL THEN
            UPDATE Remitos
            SET Estado = 'C',
                FechaEntrega = NOW()
            WHERE IdRemito = pIdRemito;
        END IF;

        SET pRespuesta = (
            SELECT CAST( JSON_OBJECT(
                "OrdenesProduccion",  JSON_OBJECT(
                    'IdOrdenProduccion', op.IdOrdenProduccion,
                    'IdUsuario', op.IdUsuario,
                    'FechaAlta', op.FechaAlta,
                    'Observaciones', op.Observaciones,
                    'Estado', f_dameEstadoOrdenProduccion(op.IdOrdenProduccion)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "LineasOrdenProduccion", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "IdLineaProductoPadre", lp.IdLineaProductoPadre,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "Estado", f_dameEstadoLineaOrdenProduccion(lp.IdLineaProducto),
                            "_IdRemito", r.IdRemito
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            ) AS JSON)
            FROM OrdenesProduccion op
            INNER JOIN Usuarios u ON u.IdUsuario = op.IdUsuario
            LEFT JOIN LineasProducto lp ON op.IdOrdenProduccion = lp.IdReferencia AND lp.Tipo = 'O'
            LEFT JOIN LineasProducto lr ON lp.IdLineaProducto = lr.IdLineaProductoPadre
            LEFT JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE IdOrdenProduccion = pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaPresupuesto_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaPresupuesto_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar una linea de presupuesto. 
        Controla que la linea de presupuesto este en estado 'Pendiente'.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pIdLineaProducto bigint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaPresupuesto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pIdLineaProducto = COALESCE(pIn->>"$.LineasProducto.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'P') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAPRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) <> 'P' THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_LINEAPRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;

        DELETE
        FROM LineasProducto 
        WHERE IdLineaProducto = pIdLineaProducto;
        
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaPresupuesto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaPresupuesto_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear una linea de presupuesto. 
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno. 
        Controla que tenga permiso de cambiar el precio, en caso contrario setea el precio del producto final
        Devuelve la linea de producto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    DECLARE pIdPresupuesto int;
    DECLARE pIdProductoFinal int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pError varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaPresupuesto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdPresupuesto = pLineasProducto ->> "$.IdReferencia";
    SET pPrecioUnitario = pLineasProducto ->> "$.PrecioUnitario";
    SET pCantidad = pLineasProducto ->> "$.Cantidad";

    -- Extraigo atributos del producto final
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF pCantidad <= 0  OR pCantidad IS NULL THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 OR pPrecioUnitario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF pIdTela = 0 THEN
            SET pIdTela = NULL;
        END IF;
        IF pIdLustre = 0 THEN
            SET pIdLustre = NULL;
        END IF;
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
        
        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);
 
        IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdPresupuesto AND Tipo = 'P' AND IdProductoFinal = pIdProductoFinal) THEN
            SELECT f_generarRespuesta("ERROR_PRESUPUESTO_EXISTE_PRODUCTOFINAL", NULL) pOut;
            LEAVE SALIR;
        END IF;

        CALL zsp_usuario_tiene_permiso(pToken, 'modificar_precio_presupuesto', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_calcularPrecioProductoFinal(pIdProductoFinal) INTO pPrecioUnitario;
        END IF;

        INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, NULL, pIdProductoFinal, NULL, pIdPresupuesto, 'P', pPrecioUnitario, pCantidad, NOW(), NULL, 'P');

        SET pRespuesta = (
                SELECT CAST(
                    JSON_OBJECT(
                        "LineasProducto",  JSON_OBJECT(
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
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                AS JSON)
                FROM LineasProducto lp
                LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
                LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
                LEFT JOIN Telas te ON pf.IdTela = te.IdTela
                LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
                WHERE	lp.IdLineaProducto = LAST_INSERT_ID()
            );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaPresupuesto_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaPresupuesto_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite instanciar una linea de presupuesto a partir de su Id. 
        Controla que la linea de presupuesto exista.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaPresupuesto_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = pLineasProducto ->> "$.IdLineaProducto";

    IF pIdLineaProducto IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAPRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "LineasProducto", JSON_OBJECT(
                "IdLineaProducto", lp.IdLineaProducto,
                "IdProductoFinal", lp.IdProductoFinal,
                "Cantidad", lp.Cantidad,
                "PrecioUnitario", lp.PrecioUnitario
                ),
            "ProductosFinales", JSON_OBJECT(
                "IdProductoFinal", pf.IdProductoFinal,
                "IdProducto", pf.IdProducto,
                "IdTela", pf.IdTela,
                "IdLustre", pf.IdLustre,
                "FechaAlta", pf.FechaAlta
            ),
            "Productos",JSON_OBJECT(
                "IdProducto", pr.IdProducto,
                "Producto", pr.Producto
            ),
            "Telas",IF (te.IdTela  IS NOT NULL,
            JSON_OBJECT(
                "IdTela", te.IdTela,
                "Tela", te.Tela
            ),NULL),
            "Lustres",IF (lu.IdLustre  IS NOT NULL,
            JSON_OBJECT(
                "IdLustre", lu.IdLustre,
                "Lustre", lu.Lustre
            ), NULL)
        )
        FROM LineasProducto lp
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	lp.IdLineaProducto = pIdLineaProducto
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaPresupuesto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaPresupuesto_modificar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar una linea de presupuesto. 
        Controla que la linea de presupuesto este en estado 'Pendiente', que exista el cliente para el cual se le esta creando, la ubicación donde se esta realizando y el usuario que lo está creando. 
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno. 
        Devuelve la linea de producto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    DECLARE pIdPresupuesto int;
    DECLARE pIdProductoFinal int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pError varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaPresupuesto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdPresupuesto = pLineasProducto ->> "$.IdReferencia";
    SET pIdLineaProducto = pLineasProducto ->> "$.IdLineaProducto";
    SET pIdProductoFinal = pLineasProducto ->> "$.IdProductoFinal";
    SET pPrecioUnitario = pLineasProducto ->> "$.PrecioUnitario";
    SET pCantidad = pLineasProducto ->> "$.Cantidad";

    -- Extraigo atributos del producto final
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdLineaProducto IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAPRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0  OR pCantidad IS NULL THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 OR pPrecioUnitario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
      
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;

        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre);
        IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdPresupuesto AND Tipo = 'P' AND IdProductoFinal = pIdProductoFinal AND IdLineaProducto <> pIdLineaProducto) THEN
            SELECT f_generarRespuesta("ERROR_PRESUPUESTO_EXISTE_PRODUCTOFINAL", NULL) pOut;
            LEAVE SALIR;
        END IF;

        CALL zsp_usuario_tiene_permiso(pToken, 'modificar_precio_presupuesto', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_calcularPrecioProductoFinal(pIdProductoFinal) INTO pPrecioUnitario;
        END IF;

        UPDATE LineasProducto
        SET IdProductoFinal = pIdProductoFinal,
            Cantidad = pCantidad,
            PrecioUnitario = pPrecioUnitario
        WHERE IdLineaProducto = pIdLineaProducto;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "LineasProducto", JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad,
                    "PrecioUnitario", lp.PrecioUnitario
                    ),
                "ProductosFinales", JSON_OBJECT(
                    "IdProductoFinal", pf.IdProductoFinal,
                    "IdProducto", pf.IdProducto,
                    "IdTela", pf.IdTela,
                    "IdLustre", pf.IdLustre,
                    "FechaAlta", pf.FechaAlta
                ),
                "Productos",JSON_OBJECT(
                    "IdProducto", pr.IdProducto,
                    "Producto", pr.Producto
                ),
                "Telas",IF (te.IdTela  IS NOT NULL,
                JSON_OBJECT(
                    "IdTela", te.IdTela,
                    "Tela", te.Tela
                ),NULL),
                "Lustres",IF (lu.IdLustre  IS NOT NULL,
                JSON_OBJECT(
                    "IdLustre", lu.IdLustre,
                    "Lustre", lu.Lustre
                ), NULL)
            )
            FROM LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaProducto
        );  
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaRemito_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaRemito_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite una linea de remito. Controla que la linea de remito este pendiente de entrega.
        En caso de exito devuelve NULL en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdLineaRemito bigint;

    DECLARE pIdRemito int;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaRemito_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdLineaRemito = COALESCE(pIn->>'$.LineasProducto.IdLineaProducto', 0);

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito);

    -- Significa que no esta pendiente de entrega
    IF (SELECT FechaEntrega FROM Remitos WHERE IdRemito = pIdRemito) IS NOT NULL OR (SELECT Estado FROM Remitos WHERE IdRemito = pIdRemito) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM LineasProducto
        WHERE IdLineaProducto = pIdLineaRemito;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaRemito_crear_interno;
DELIMITER $$
CREATE PROCEDURE zsp_lineaRemito_crear_interno(pIn JSON, OUT pIdLineaRemito int, OUT pError varchar(255))
SALIR: BEGIN
    /*
        Procedimiento que contiene los permisos basicos para crer una linea de remito.
        Devuelve el Id de la linea de remito creada o el error en 'error';
    */
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdRemito int;
    DECLARE pCantidad tinyint;
    DECLARE pIdProductoFinal int;

    -- Producto final;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pMensaje varchar(255);

    -- Extraigo atributos de la linea de remito
    SET pIdRemito = COALESCE(pIn ->> "$.LineasProducto.IdReferencia", 0);
    SET pCantidad = COALESCE(pIn ->> "$.LineasProducto.Cantidad", 0);
    SET pIdUbicacion = pIn ->> "$.LineasProducto.IdUbicacion";

    -- Extraigo atributos del producto final
    SET pIdProducto = COALESCE(pIn ->> "$.ProductosFinales.IdProducto", 0);
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela", 0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre", 0);

    SET @pTipo = (SELECT Tipo FROM Remitos WHERE IdRemito = pIdRemito);

    IF @pTipo IN ('S', 'Y') AND NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_UBICACION_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF @pTipo IN ('E', 'X') THEN
        SET pIdUbicacion = NULL;
    END IF;

    IF pCantidad = 0 THEN
        SET pIdLineaRemito = 0;
        SET pError = "ERROR_CANTIDAD_INVALIDA";
        LEAVE SALIR;
    END IF;

    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;
    -- Si no existe el producto final y el remito es de entrada lo creo. No puedo crear una linea de remito para un remito de salida con algo que no existe
    IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
        IF @pTipo IN ('E', 'X') THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pMensaje);
            IF pMensaje IS NOT NULL THEN
                SET pError = pMensaje;
                SET pIdLineaRemito = 0;
                LEAVE SALIR;
            END IF;
        ELSE
            SELECT f_generarRespuesta("ERROR_PRODUCTOFINAL_NOEXISTE", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF @pTipo IN ('S', 'Y') AND pCantidad < f_calcularStockProducto(pIdProductoFinal, pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);

    INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, NULL, pIdProductoFinal, pIdUbicacion, pIdRemito, 'R', NULL, pCantidad, NOW(), NULL, 'P');

    SET pIdLineaRemito = LAST_INSERT_ID();
    SET pError = NULL;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaRemito_crear;
DELIMITER $$
CREATE PROCEDURE zsp_lineaRemito_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedmiento que permite crear una linea de remito
        Devuelve la linea de remito en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdLineaRemito bigint;
    DECLARE pError varchar(255);

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaRemito_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        CALL zsp_lineaRemito_crear_interno(pIn, pIdLineaRemito, pError);
        IF pError IS NOT NULL THEN
            SELECT f_generarRespuesta(pError, NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
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
                    ) ,
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            AS JSON)
            FROM	LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaRemito AND lp.Tipo = 'R'
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaRemito_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaRemito_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una linea de remito. Controla que se encuentre pendiente de entrega.
        Devuelve la linea de remito modificada en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdLineaRemito bigint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdRemito int;
    DECLARE pCantidad tinyint;
    DECLARE pIdProductoFinal int;
    
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    DECLARE pError varchar(255);

    DECLARE pRespuesta JSON;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    SET pIdLineaRemito = COALESCE(pIn->>'$.LineasProducto.IdLineaProducto', 0);
    SET pIdUbicacion = COALESCE(pIn->>'$.LineasProducto.IdUbicacion', 0);
    SET pCantidad = COALESCE(pIn->>'$.LineasProducto.Cantidad', 0);
    SET pIdProducto = COALESCE(pIn->>'$.ProductosFinales.IdProducto', 0);
    SET pIdTela = COALESCE(pIn->>'$.ProductosFinales.IdTela', 0);
    SET pIdLustre = COALESCE(pIn->>'$.ProductosFinales.IdLustre', 0);

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProducto = pIdLineaRemito);
    SET @pTipo = (SELECT Tipo FROM Remitos WHERE IdRemito = pIdRemito);

    IF @pTipo IN ('S', 'Y') AND NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_UBICACION_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT FechaEntrega FROM Remitos WHERE IdRemito = pIdRemito) IS NOT NULL OR (SELECT Estado FROM Remitos WHERE IdRemito = pIdRemito) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_NOPENDIENTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0 THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
        
        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre);

        UPDATE LineasProducto
        SET IdProductoFinal = pIdProductoFinal,
            Cantidad = pCantidad,
            IdUbicacion = NULLIF(pIdUbicacion, 0)
        WHERE IdLineaProducto = pIdLineaRemito;
        
        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
                        'IdLineaProducto', lp.IdLineaProducto,
                        'IdLineaProductoPadre', lp.IdLineaProductoPadre,
                        'IdProductoFinal', lp.IdProductoFinal,
                        'IdUbicacion', lp.IdUbicacion,
                        'IdReferencia', lp.IdReferencia,
                        'Tipo', lp.Tipo,
                        'PrecioUnitario', lp.PrecioUnitario,
                        "_PrecioUnitarioActual",  f_calcularPrecioProductoFinal(lp.IdProductoFinal),
                        'Cantidad', lp.Cantidad,
                        'FechaAlta', lp.FechaAlta,
                        'FechaCancelacion', lp.FechaCancelacion,
                        'Estado', lp.Estado
                    ) ,
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            AS JSON)
            FROM	LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaRemito AND lp.Tipo = 'R'
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaVenta_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una linea de venta.
        Controla que se encuentre en estado 'P'.
        Devuelve NULL en respuesta o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = COALESCE(pLineasProducto ->> "$.IdLineaProducto", 0);

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Estado = 'P') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM LineasProducto
        WHERE IdLineaProducto = pIdLineaProducto;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaVenta_cancelar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_cancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite cancelar una linea de venta.
        Controla que se encuentre en Estado 'P'.
        Devuelve la Linea de Venta en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de venta
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;

    DECLARE pFacturado DECIMAL(10,2);
    DECLARE pCancelado DECIMAL(10,2);
    DECLARE pMontoCancelado DECIMAL(10, 2);
    DECLARE pMontoACancelar DECIMAL(10,2);

    DECLARE pIdLineaRemito BIGINT;
    DECLARE pIdLineaOP BIGINT;
    
    DECLARE pIdVenta int;

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_cancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = COALESCE(pLineasProducto ->> "$.IdLineaProducto", 0);

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'V') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) != 'P' THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT v.Estado FROM Ventas v INNER JOIN LineasProducto lp ON lp.IdReferencia = v.IdVenta WHERE lp.IdLineaProducto = pIdLineaProducto) != 'C' THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT IdReferencia, Cantidad, PrecioUnitario INTO pIdVenta, @pCantidad, @pPrecioUnitario FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto;
    SET pMontoCancelado = COALESCE((SELECT SUM(PrecioUnitario * Cantidad) FROM LineasProducto WHERE IdReferencia = pIdVenta AND Tipo = 'V' AND Estado = 'C'), 0);
    SET pMontoACancelar = COALESCE((SELECT PrecioUnitario * Cantidad FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto), 0);

    -- Compruebo si existe una Factura A. En caso que haya deben existir notas de credito cuya suma total sea igual a las lineas de venta canceladas.
    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'A' AND Estado = 'A') THEN
        SET pFacturado = (SELECT COALESCE(SUM(Monto),0) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'A' AND Estado = 'A');
        SET pCancelado = (SELECT COALESCE(SUM(Monto),0)FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'N' AND Estado ='A');
        IF (pFacturado - pCancelado) > pMontoACancelar THEN
            IF pCancelado < (pMontoCancelado + pMontoACancelar) THEN
                SELECT f_generarRespuesta("ERROR_NOTACREDITOA_VENTA", NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'B' AND Estado = 'A') THEN
        SET pFacturado = (SELECT COALESCE(SUM(Monto),0) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'B' AND Estado = 'A');
        SET pCancelado = (SELECT COALESCE(SUM(Monto),0) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'M' AND Estado ='A');
        IF (pFacturado - pCancelado) > pMontoACancelar THEN
            IF pCancelado < (pMontoCancelado + pMontoACancelar) THEN
                SELECT f_generarRespuesta("ERROR_NOTACREDITOB_VENTA", NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
    END IF;

    START TRANSACTION;
        SET pIdLineaRemito = (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R');
        IF COALESCE(pIdLineaRemito, 0) != 0 THEN
            SET pIdLineaRemito = (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R');
            UPDATE LineasProducto
            SET Estado = 'C',
                FechaCancelacion = NOW()
            WHERE IdLineaProducto = pIdLineaRemito;
        END IF;

        SET pIdLineaOP = (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'O');
        IF COALESCE(pIdLineaOP, 0) != 0 THEN
            UPDATE LineasProducto
            SET IdLineaProductoPadre = NULL
            WHERE IdLineaProducto = pIdLineaOP;
        END IF;

        UPDATE LineasProducto
        SET Estado = 'C',
            FechaCancelacion = NOW()
        WHERE IdLineaProducto = pIdLineaProducto;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "LineasProducto", JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad,
                    "PrecioUnitario", lp.PrecioUnitario
                )
            )
        FROM LineasProducto lp
        WHERE	lp.IdLineaProducto = pIdLineaProducto
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaVenta_crear_interno;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_crear_interno(pIn JSON, OUT pIdLineaVenta bigint, OUT pError varchar(255))
SALIR: BEGIN
    /*
        Procedimiento interno para crear una linea de venta.
        Devuelve el IdLineaProducto en caso de crear la linea de venta o 0 en caso de error.
    */
    -- Linea de venta
    DECLARE pLineasProducto JSON;
    DECLARE pIdVenta int;
    DECLARE pIdProductoFinal int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pMensaje varchar(255);

    -- Extraigo atributos de la linea de venta
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdVenta = COALESCE(pLineasProducto ->> "$.IdReferencia", 0);
    SET pPrecioUnitario = COALESCE(pLineasProducto ->> "$.PrecioUnitario", 0.00);
    SET pCantidad = COALESCE(pLineasProducto ->> "$.Cantidad", 0);

    -- Extraigo atributos del producto final
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = COALESCE(pProductosFinales ->> "$.IdProducto", 0);
    SET pIdTela = COALESCE(pProductosFinales ->> "$.IdTela", 0);
    SET pIdLustre = COALESCE(pProductosFinales ->> "$.IdLustre", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_NOEXISTE_VENTA";
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0 THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_CANTIDAD_INVALIDA";
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 OR pPrecioUnitario IS NULL THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_INVALIDO_PRECIO";
        LEAVE SALIR;
    END IF;
    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;
    IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
        CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pMensaje);
        IF pMensaje IS NOT NULL THEN
            SET pError = pMensaje;
            SET pIdLineaVenta = 0;
            LEAVE SALIR;
        END IF;
    END IF;
    
    SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre);

    IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdReferencia = pIdVenta AND Tipo = 'V' AND IdProductoFinal = pIdProductoFinal) THEN
        SET pIdLineaVenta = 0;
        SET pError = "ERROR_VENTA_EXISTE_PRODUCTOFINAL";
        LEAVE SALIR;
    END IF;

    INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, NULL, pIdProductoFinal, NULL, pIdVenta, 'V', pPrecioUnitario, pCantidad, NOW(), NULL, 'P');

    SET pIdLineaVenta = LAST_INSERT_ID();
    SET pError = NULL;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaVenta_crear;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una linea de venta.
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno. 
        Controla que tenga permiso de cambiar el precio, en caso contrario setea el precio del producto final
        Devuelve la linea de producto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pError varchar(255);

    DECLARE pIdLineaVenta bigint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        
        CALL zsp_lineaVenta_crear_interno(pIn, pIdLineaVenta, pError);
        IF pError IS NOT NULL THEN
            SELECT f_generarRespuesta(pError, NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "LineasProducto",  JSON_OBJECT(
                        'IdLineaProducto', lp.IdLineaProducto,
                        'IdLineaProductoPadre', lp.IdLineaProductoPadre,
                        'IdProductoFinal', lp.IdProductoFinal,
                        'IdUbicacion', lp.IdUbicacion,
                        'IdReferencia', lp.IdReferencia,
                        'Tipo', lp.Tipo,
                        'PrecioUnitario', lp.PrecioUnitario,
                        "_PrecioUnitarioActual",  f_calcularPrecioProductoFinal(lp.IdProductoFinal),
                        'Cantidad', lp.Cantidad,
                        'FechaAlta', lp.FechaAlta,
                        'FechaCancelacion', lp.FechaCancelacion,
                        'Estado', lp.Estado
                    ) ,
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            AS JSON)
            FROM	LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaVenta AND lp.Tipo = 'V'
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lineaVenta_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_lineaVenta_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite instanciar una linea de venta a partir de su Id. 
        Controla que la linea de venta exista.
        Devuelve el NULL en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de presupuesto a crear
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de venta
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = pLineasProducto ->> "$.IdLineaProducto";

    IF pIdLineaProducto IS NULL OR NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "LineasProducto", JSON_OBJECT(
                "IdLineaProducto", lp.IdLineaProducto,
                "IdProductoFinal", lp.IdProductoFinal,
                "Cantidad", lp.Cantidad,
                "PrecioUnitario", lp.PrecioUnitario,
                "_PrecioUnitarioActual",  f_calcularPrecioProductoFinal(lp.IdProductoFinal)
            ),
            "ProductosFinales", JSON_OBJECT(
                "IdProductoFinal", pf.IdProductoFinal,
                "IdProducto", pf.IdProducto,
                "IdTela", pf.IdTela,
                "IdLustre", pf.IdLustre,
                "FechaAlta", pf.FechaAlta
            ),
            "Productos",JSON_OBJECT(
                "IdProducto", pr.IdProducto,
                "Producto", pr.Producto
            ),
            "Telas",IF (te.IdTela  IS NOT NULL,
            JSON_OBJECT(
                "IdTela", te.IdTela,
                "Tela", te.Tela
            ),NULL),
            "Lustres",IF (lu.IdLustre  IS NOT NULL,
            JSON_OBJECT(
                "IdLustre", lu.IdLustre,
                "Lustre", lu.Lustre
            ), NULL)
        )
        FROM LineasProducto lp
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	lp.IdLineaProducto = pIdLineaProducto
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_lineaVenta_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_lineaVenta_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una linea de venta.
        En caso que el producto final no exista llama al zsp_productoFinal_crear_interno. 
        Controla que tenga permiso de cambiar el precio, en caso contrario setea el precio del producto final
        Devuelve la linea de producto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Linea de venta
    DECLARE pLineasProducto JSON;
    DECLARE pIdLineaProducto bigint;
    DECLARE pIdVenta int;
    DECLARE pIdProductoFinal int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pError varchar(255);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lineaVenta_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la linea de presupuesto
    SET pLineasProducto = pIn ->> "$.LineasProducto";
    SET pIdLineaProducto = COALESCE(pLineasProducto ->> "$.IdLineaProducto", 0);
    SET pIdVenta = COALESCE(pLineasProducto ->> "$.IdReferencia", 0);
    SET pPrecioUnitario = COALESCE(pLineasProducto ->> "$.PrecioUnitario", 0.00);
    SET pCantidad = COALESCE(pLineasProducto ->> "$.Cantidad", 0);

    -- Extraigo atributos del producto final
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = COALESCE(pProductosFinales ->> "$.IdProducto", 0);
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad <= 0 THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecioUnitario <= 0.00 IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
            CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
        
        SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre);

        IF EXISTS (SELECT IdProductoFinal FROM LineasProducto WHERE IdLineaProducto != pIdLineaProducto AND Tipo = 'V' AND IdProductoFinal = pIdProductoFinal AND IdReferencia = pIdVenta) THEN
            SELECT f_generarRespuesta("ERROR_VENTA_EXISTE_PRODUCTOFINAL", NULL) pOut;
            LEAVE SALIR;
        END IF;

        CALL zsp_usuario_tiene_permiso(pToken, 'modificar_precio_venta', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_calcularPrecioProductoFinal(pIdProductoFinal) INTO pPrecioUnitario;
        END IF;

        UPDATE LineasProducto
        SET IdProductoFinal = pIdProductoFinal,
            Cantidad = pCantidad,
            PrecioUnitario = pPrecioUnitario
        WHERE IdLineaProducto = pIdLineaProducto;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "LineasProducto", JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad,
                    "PrecioUnitario", lp.PrecioUnitario
                    ),
                "ProductosFinales", JSON_OBJECT(
                    "IdProductoFinal", pf.IdProductoFinal,
                    "IdProducto", pf.IdProducto,
                    "IdTela", pf.IdTela,
                    "IdLustre", pf.IdLustre,
                    "FechaAlta", pf.FechaAlta
                ),
                "Productos",JSON_OBJECT(
                    "IdProducto", pr.IdProducto,
                    "Producto", pr.Producto
                ),
                "Telas",IF (te.IdTela  IS NOT NULL,
                JSON_OBJECT(
                    "IdTela", te.IdTela,
                    "Tela", te.Tela
                ),NULL),
                "Lustres",IF (lu.IdLustre  IS NOT NULL,
                JSON_OBJECT(
                    "IdLustre", lu.IdLustre,
                    "Lustre", lu.Lustre
                ), NULL)
            )
            FROM LineasProducto lp
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	lp.IdLineaProducto = pIdLineaProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_lustres_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_lustres_listar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar los lustres.
        Devuelve una lista de los lustres en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_lustres_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "Lustres",
            JSON_OBJECT(
                'IdLustre', IdLustre,
                'Lustre', Lustre,
                'Observaciones', Observaciones
            )
        )
    ) 
    FROM Lustres
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ordenesProduccion_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ordenesProduccion_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar una orden de producción por: 
        - Usuario (0: Todos)
        - Estado (E:En Creación - P:Pendiente - C:Cancelada - R:En Producción - V:Verificada - T:Todos)
        - IdUsuarioFabricante(0:Todos),
        - IdUsuarioRevisor(0:Todos),
        - Producto(0:Todos),
        - Telas(0:Todos),
        - Lustre (0: Todos),
        - Periodo de fechas
        Devuelve una lista de órdenes de producción en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta SMALLINT;
    DECLARE pToken VARCHAR(256);
    DECLARE pMensaje TEXT;

    -- Orden de producción a buscar
    DECLARE pIdUsuario SMALLINT;
    DECLARE pEstado CHAR(1);

    -- Paginacion
    DECLARE pPagina INT;
    DECLARE pLongitudPagina INT;
    DECLARE pCantidadTotal INT;
    DECLARE pOffset INT;

    -- Parametros busqueda
    DECLARE pParametrosBusqueda JSON;
    DECLARE pFechaInicio DATETIME;
    DECLARE pFechaFin DATETIME;

    -- Tareas
    DECLARE pIdUsuarioRevisor SMALLINT;
    DECLARE pIdUsuarioFabricante SMALLINT;

    -- Productos Final
    DECLARE pIdProducto INT;
    DECLARE pIdLustre TINYINT;
    DECLARE pIdTela SMALLINT;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pResultado JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn->>"$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta->>"$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenesProduccion_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la orden de producción
    SET pIdUsuario = COALESCE(pIn ->> "$.OrdenesProduccion.IdUsuario", 0);
    SET pEstado = COALESCE(pIn ->> "$.OrdenesProduccion.Estado", 'T');

    -- Extraigo atributos de tareas
    SET pIdUsuarioRevisor = COALESCE(pIn ->> "$.Tareas.IdUsuarioRevisor", 0);
    SET pIdUsuarioFabricante = COALESCE(pIn ->> "$.Tareas.IdUsuarioFabricante", 0);

    -- Extraigo atributos del producto final
    SET pIdProducto = COALESCE(pIn ->> "$.ProductosFinales.IdProducto", 0);
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela", 0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre", 0);

    -- Extraigo atributos de la paginacion
    SET pPagina = pIn ->> "$.Paginaciones.Pagina";
    SET pLongitudPagina = pIn ->> "$.Paginaciones.LongitudPagina";

    -- Extraigo atributos de los parámetros de busqueda
    SET pParametrosBusqueda = pIn ->>"$.ParametrosBusqueda";
    IF CHAR_LENGTH(COALESCE(pParametrosBusqueda ->>"$.FechaInicio", '')) > 0 THEN
        SET pFechaInicio = pParametrosBusqueda ->> "$.FechaInicio";
    END IF;
    IF CHAR_LENGTH(COALESCE(pParametrosBusqueda ->>"$.FechaFin", '')) = 0 THEN
        SET pFechaFin = NOW();
    ELSE
        SET pFechaFin = CONCAT(pParametrosBusqueda ->> "$.FechaFin"," 23:59:59");
    END IF;

    IF pEstado NOT IN ('E','P','C','R','V','T') THEN
		SET pEstado = 'T';
	END IF;

    IF COALESCE(pPagina, 0) < 1 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccion;
    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccionPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_lineasOrdenesProduccion;


    -- Órdenes de producción que cumplen con las condiciones
    CREATE TEMPORARY TABLE tmp_OrdenesProduccion
    AS SELECT op.IdOrdenProduccion AS IdOrdenProduccion
    FROM OrdenesProduccion op
    LEFT JOIN LineasProducto lp ON (lp.IdReferencia = op.IdOrdenProduccion AND lp.Tipo = 'O')
    LEFT JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
    LEFT JOIN Tareas t ON (t.IdLineaProducto = lp.IdLineaProducto)
	WHERE 
        (op.IdUsuario = pIdUsuario OR pIdUsuario = 0)
        AND (t.IdUsuarioFabricante = pIdUsuarioFabricante OR pIdUsuarioFabricante = 0)
        AND (t.IdUsuarioRevisor = pIdUsuarioRevisor OR pIdUsuarioRevisor = 0)
        AND (op.Estado = pEstado OR pEstado = 'T')
        AND ((pFechaInicio IS NULL AND op.FechaAlta <= pFechaFin) OR (pFechaInicio IS NOT NULL AND op.FechaAlta BETWEEN pFechaInicio AND pFechaFin))
        AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
        AND (pf.IdTela = pIdTela OR pIdTela = 0)
        AND (pf.IdLustre = pIdLustre OR pIdLustre = 0)
    ORDER BY op.IdOrdenProduccion DESC;

    SET pCantidadTotal = (SELECT COUNT(DISTINCT IdOrdenProduccion) FROM tmp_OrdenesProduccion);

    -- Órdenes de producción buscadas paginadas
    CREATE TEMPORARY TABLE tmp_OrdenesProduccionPaginadas AS
    SELECT DISTINCT IdOrdenProduccion
    FROM tmp_OrdenesProduccion
    ORDER BY IdOrdenProduccion DESC
    LIMIT pOffset, pLongitudPagina;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    -- Lineas de las órdenes de producción
    CREATE TEMPORARY TABLE tmp_lineasOrdenesProduccion AS
    SELECT  
		tmpp.IdOrdenProduccion,
        IF(COUNT(lp.IdLineaProducto) > 0, CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
            "LineasProducto",  
                JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad
                ),
            "ProductosFinales",
                JSON_OBJECT(
                    "IdProductoFinal", pf.IdProductoFinal,
                    "IdProducto", pf.IdProducto,
                    "IdTela", pf.IdTela,
                    "IdLustre", pf.IdLustre,
                    "FechaAlta", pf.FechaAlta
                ),
            "Productos",
                JSON_OBJECT(
                    "IdProducto", pr.IdProducto,
                    "Producto", pr.Producto
                ),
            "Telas",IF (te.IdTela  IS NOT NULL,
                JSON_OBJECT(
                    "IdTela", te.IdTela,
                    "Tela", te.Tela
                ), NULL),
            "Lustres",IF (lu.IdLustre  IS NOT NULL,
                JSON_OBJECT(
                    "IdLustre", lu.IdLustre,
                    "Lustre", lu.Lustre
                ), NULL)
        ) ORDER BY lp.Cantidad DESC),''), ']') AS JSON), NULL) AS LineasOrdenProduccion
    FROM    tmp_OrdenesProduccionPaginadas tmpp
    LEFT JOIN LineasProducto lp ON (lp.IdReferencia = tmpp.IdOrdenProduccion AND lp.Tipo = 'O')
    LEFT JOIN ProductosFinales pf ON pf.IdProductoFinal = lp.IdProductoFinal
    LEFT JOIN Productos pr ON pr.IdProducto = pf.IdProducto
    LEFT JOIN Telas te ON te.IdTela = pf.IdTela
    LEFT JOIN Lustres lu ON lu.IdLustre = pf.IdLustre
    GROUP BY tmpp.IdOrdenProduccion;

    SET pRespuesta = JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", (
                SELECT CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', op.IdOrdenProduccion,
                        'IdUsuario', op.IdUsuario,
                        'FechaAlta', op.FechaAlta,
                        'Observaciones', op.Observaciones,
                        'Estado', f_dameEstadoOrdenProduccion(op.IdOrdenProduccion)
                    ),
                    "Usuarios", JSON_OBJECT(
                        "Nombres", u.Nombres,
                        "Apellidos", u.Apellidos
                    ),
                    "LineasOrdenProduccion", tmpp.LineasOrdenProduccion
                ) ORDER BY op.FechaAlta DESC),''), ']') AS JSON)
                FROM tmp_lineasOrdenesProduccion tmpp
                INNER JOIN OrdenesProduccion op ON op.IdOrdenProduccion = tmpp.IdOrdenProduccion
                INNER JOIN Usuarios u ON op.IdUsuario = u.IdUsuario
            )
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccion;
    DROP TEMPORARY TABLE IF EXISTS tmp_OrdenesProduccionPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_lineasOrdenesProduccion;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_ordenProduccion_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una orden de producción. Controla que se encuentre en Estado = 'E', en caso positivo borra sus lineas tambien.
        Devuelve NULL en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdRemito INT;

    DECLARE pIdOrdenProduccion int;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdOrdenProduccion = pIn ->> '$.OrdenesProduccion.IdOrdenProduccion';

    IF NOT EXISTS (SELECT IdOrdenProduccion FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion AND f_dameEstadoOrdenProduccion(IdOrdenProduccion) IN('E', 'C')) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Obtenemos el IdRemito de "Transformación entrada" (X) asociado, en caso de que se esté fabricando utilizando esqueletos
    SELECT DISTINCT r.IdRemito INTO pIdRemito 
        FROM LineasProducto lop 
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto 
        INNER JOIN Remitos r ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R' 
        WHERE 
            r.Tipo = 'X' 
            AND lop.IdReferencia = pIdOrdenProduccion 
            AND lop.Tipo = 'O';

    START TRANSACTION;
        IF COALESCE(pIdRemito, 0) != 0 THEN
            -- Eliminamos todas las lineas de remito del remito
            DELETE FROM LineasProducto
            WHERE 
                IdReferencia = pIdRemito
                AND Tipo = 'R';

            -- Eliminamos el remito
            DELETE FROM Remitos
            WHERE IdRemito = pIdRemito;
        END IF;

        DELETE
        FROM OrdenesProduccion
        WHERE IdOrdenProduccion = pIdOrdenProduccion;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_ordenProduccion_crear;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una nueva orden de producción en estado En Creación.
        Devuelve la orden de producción en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE pObservaciones VARCHAR(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pToken = pIn->>"$.UsuariosEjecuta.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_crear', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pObservaciones = COALESCE(pIn->>"$.UsuariosEjecuta.Observaciones", "");

    START TRANSACTION;
        INSERT INTO OrdenesProduccion (IdOrdenProduccion, IdUsuario, FechaAlta, Observaciones, Estado) VALUES (0, pIdUsuarioEjecuta, NOW(), pObservaciones, 'E');

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', IdOrdenProduccion,
                        'IdUsuario', IdUsuario,
                        'FechaAlta', FechaAlta,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM    OrdenesProduccion
            WHERE   IdOrdenProduccion = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_ordenProduccion_dame;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instanciar una orden de producción desde la base de datos.
        Devuelve la orden de producción en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    DECLARE pIdOrdenProduccion INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdOrdenProduccion = pIn ->> '$.OrdenesProduccion.IdOrdenProduccion';

    IF pIdOrdenProduccion IS NULL OR NOT EXISTS (SELECT IdOrdenProduccion FROM OrdenesProduccion WHERE IdOrdenProduccion = pIdOrdenProduccion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pRespuesta = (
            SELECT CAST( JSON_OBJECT(
                "OrdenesProduccion",  JSON_OBJECT(
                    'IdOrdenProduccion', op.IdOrdenProduccion,
                    'IdUsuario', op.IdUsuario,
                    'FechaAlta', op.FechaAlta,
                    'Observaciones', op.Observaciones,
                    'Estado', f_dameEstadoOrdenProduccion(op.IdOrdenProduccion)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "LineasOrdenProduccion", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "IdLineaProductoPadre", lp.IdLineaProductoPadre,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "Estado", f_dameEstadoLineaOrdenProduccion(lp.IdLineaProducto)
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            ) AS JSON)
            FROM OrdenesProduccion op
            INNER JOIN Usuarios u ON u.IdUsuario = op.IdUsuario
            LEFT JOIN LineasProducto lp ON op.IdOrdenProduccion = lp.IdReferencia AND lp.Tipo = 'O'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE IdOrdenProduccion = pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_ordenProduccion_pasarAPendiente;
DELIMITER $$
CREATE PROCEDURE zsp_ordenProduccion_pasarAPendiente(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite pasar a pendiente una determinada orden de producción.
        Devuelve la orden de producción en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pIdRemito BIGINT;
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE pIdOrdenProduccion INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pToken = pIn->>"$.UsuariosEjecuta.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ordenProduccion_pasarAPendiente', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdOrdenProduccion = pIn->>"$.OrdenesProduccion.IdOrdenProduccion";

    IF NOT EXISTS(
        SELECT
            lop.IdLineaProducto
        FROM OrdenesProduccion op
        INNER JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdReferencia = op.IdOrdenProduccion)
        WHERE 
            op.IdOrdenProduccion = pIdOrdenProduccion
            AND op.Estado = 'E'
    ) THEN
        SELECT f_generarRespuesta("ERROR_ORDEN_PRODUCCION_SIN_LINEAS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    /*
        Controlamos que todas las lineas sean producibles
    */
    IF EXISTS(
        SELECT
            lop.IdLineaProducto
        FROM OrdenesProduccion op
        INNER JOIN LineasProducto lop ON (lop.Tipo = 'O' AND lop.IdReferencia = op.IdOrdenProduccion)
        INNER JOIN ProductosFinales pf ON (pf.IdProductoFinal = lop.IdProductoFinal)
        INNER JOIN Productos p ON (p.IdProducto = pf.IdProducto)
        LEFT JOIN LineasProducto lp ON (lp.IdLineaProducto = lop.IdLineaProducto)
        WHERE 
            op.IdOrdenProduccion = pIdOrdenProduccion
            AND (p.IdTipoProducto != 'P')
    ) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE OrdenesProduccion
        SET Estado = 'C'
        WHERE IdOrdenProduccion = pIdOrdenProduccion;

        SELECT DISTINCT COALESCE(r.IdRemito, 0) INTO pIdRemito 
        FROM OrdenesProduccion op
        INNER JOIN LineasProducto lop ON lop.IdReferencia = op.IdOrdenProduccion AND lop.Tipo = 'O'
        INNER JOIN LineasProducto lr ON lr.IdLineaProductoPadre = lop.IdLineaProducto AND lr.Tipo = 'R'
        INNER JOIN Remitos r ON r.IdRemito = lr.IdReferencia
        WHERE op.IdOrdenProduccion = pIdOrdenProduccion;

        IF pIdRemito > 0 THEN
            UPDATE Remitos
            SET Estado  = 'C',
                FechaEntrega = NOW()
            WHERE IdRemito = pIdRemito;
        END IF;

        SET pRespuesta = (
            SELECT CAST(
                JSON_OBJECT(
                    "OrdenesProduccion",  JSON_OBJECT(
                        'IdOrdenProduccion', IdOrdenProduccion,
                        'IdUsuario', IdUsuario,
                        'FechaAlta', FechaAlta,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ) 
                )
            AS JSON)
            FROM    OrdenesProduccion
            WHERE   IdOrdenProduccion = pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_paises_listar`;

DELIMITER $$
CREATE PROCEDURE  `zsp_paises_listar`()

SALIR:BEGIN
    /*
        Procedimiento que permite listar todos los paises . 
        Devuelve un json todos los paises.
    */

    DECLARE pRespuesta JSON;

    SET pRespuesta = (SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Paises",
                    JSON_OBJECT(
						'IdPais', IdPais,
                        'Pais', Pais
					)
                )
            )
	FROM Paises);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut; 

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_permisos_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_permisos_listar`(pIn JSON)

SALIR:BEGIN
	/*
		Lista todos los permisos existentes y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;
    DECLARE pRespuesta TEXT;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_permisos_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultados;

    CREATE TEMPORARY TABLE tmp_resultados AS
    SELECT * FROM Permisos 
    ORDER BY Permiso
    LIMIT pOffset, pLongitudPagina; 

    -- Para devolver el total en paginaciones
    SET pCantidadTotal = (SELECT COUNT(*) FROM Permisos);

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_OBJECT(
                "Paginaciones", JSON_OBJECT(
                    "Pagina", pPagina,
                    "LongitudPagina", pLongitudPagina,
                    "CantidadTotal", pCantidadTotal
                ),
                "resultado", JSON_ARRAYAGG(
                JSON_OBJECT('Permisos',
                    JSON_OBJECT(
                        'IdPermiso', IdPermiso, 
                        'Permiso', Permiso,
                        'Procedimiento', Procedimiento,
                        'Descripcion', Descripcion
                    )
                )
            )
            )
        ,'')
	FROM tmp_resultados 
    ORDER BY Permiso);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultados;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS zsp_presupuesto_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_presupuesto_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar un presupuesto. Controla que se encuentre en Estado = 'E', en caso positivo borra sus lineas tambien.
        Devuelve NULL en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuestos
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pPresupuestos = pIn ->> '$.Presupuestos';
    SET pIdPresupuesto = pPresupuestos ->> '$.IdPresupuesto';

    IF NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto AND Estado IN('E', 'C')) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'P' AND IdReferencia = pIdPresupuesto AND Estado = 'P') THEN
            DELETE
            FROM LineasProducto
            WHERE Tipo = 'P' AND IdReferencia = pIdPresupuesto;
        END IF;

        DELETE
        FROM Presupuestos
        WHERE IdPresupuesto = pIdPresupuesto;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_presupuestos_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuestos_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar un presupuesto por: 
        - Usuario (0: Todos)
        - Cliente (0: Todos)
        - Estado (E:En Creación - C:Creado - V:Vendido - X: Expirado -T:Todos)
        - Producto(0:Todos),
        - Telas(0:Todos),
        - Lustre (0: Todos),
        - Ubicación (0:Todas las ubicaciones)
        - Periodo de fechas
        Devuelve una lista de presupuestos en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuesto a buscar
    DECLARE pPresupuestos JSON;
    DECLARE pIdCliente int;
    DECLARE pIdUsuario smallint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pFechaLimite datetime;
    DECLARE pFechaExpiracion datetime;
    DECLARE pEstado char(1);

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    -- Parametros busqueda
    DECLARE pParametrosBusqueda JSON;
    DECLARE pFechaInicio datetime;
    DECLARE pFechaFin datetime;

    -- Productos Final
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pResultado JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuestos_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    CALL zsp_usuario_tiene_permiso(pToken, 'buscar_presupuestos_ajenos', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        IF pIdUsuarioEjecuta <> pIdUsuario THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    -- Extraigo atributos del presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdCliente = pPresupuestos ->> "$.IdCliente";
    SET pIdUsuario = pPresupuestos ->> "$.IdUsuario";
    SET pIdUbicacion = pPresupuestos ->> "$.IdUbicacion";
    SET pEstado = pPresupuestos ->> "$.Estado";

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    -- Extraigo atributos de los parametros de busqueda
    SET pParametrosBusqueda = pIn ->>"$.ParametrosBusqueda";
    IF CHAR_LENGTH(COALESCE(pParametrosBusqueda ->>"$.FechaInicio", '')) > 0 THEN
        SET pFechaInicio = pParametrosBusqueda ->> "$.FechaInicio";
    END IF;
    IF CHAR_LENGTH(COALESCE(pParametrosBusqueda ->>"$.FechaFin", '')) = 0 THEN
        SET pFechaFin = NOW();
    ELSE
        SET pFechaFin = CONCAT(pParametrosBusqueda ->> "$.FechaFin"," 23:59:59");
    END IF;
    
    SET pIdCliente = COALESCE(pIdCliente, 0);
    SET pIdUbicacion = COALESCE(pIdUbicacion, 0);
    SET pIdUsuario = COALESCE(pIdUsuario, 0);
    SET pIdProducto = COALESCE(pIdProducto, 0);
    SET pIdTela = COALESCE(pIdTela, 0);
    SET pIdLustre = COALESCE(pIdLustre, 0);

    SET pFechaExpiracion = (SELECT(DATE_SUB(NOW(), INTERVAL (SELECT Valor FROM Empresa WHERE Parametro = 'PERIODOVALIDEZ') DAY)));
    IF pEstado = 'X' THEN
        SET pFechaLimite = pFechaExpiracion;
    END IF;

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('C','E','V') THEN
		SET pEstado = 'T';
	END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_Presupuestos;
    DROP TEMPORARY TABLE IF EXISTS tmp_PresupuestosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmp_presupuestosPrecios;


    -- Presupuestos que cumplen con las condiciones
    CREATE TEMPORARY TABLE tmp_Presupuestos
    AS SELECT p.IdPresupuesto
    FROM Presupuestos p
    LEFT JOIN LineasProducto lp ON (lp.IdReferencia = p.IdPresupuesto AND lp.Tipo = 'P')
    LEFT JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
	WHERE (p.IdUsuario = pIdUsuario OR pIdUsuario = 0)
    AND (p.IdCliente = pIdCliente OR pIdCliente = 0)
    AND (p.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
    AND (p.Estado = pEstado OR pEstado = 'T')
    AND (p.FechaAlta <= pFechaLimite OR pFechaLimite IS NULL)
    AND ((pFechaInicio IS NULL AND p.FechaAlta <= pFechaFin) OR (pFechaInicio IS NOT NULL AND p.FechaAlta BETWEEN pFechaInicio AND pFechaFin))
    AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
    AND (pf.IdTela = pIdTela OR pIdTela = 0)
    AND (pf.IdLustre = pIdLustre OR pIdLustre = 0)
    ORDER BY p.IdPresupuesto DESC;

    SET pCantidadTotal = (SELECT COUNT(DISTINCT IdPresupuesto) FROM tmp_Presupuestos);

    -- Presupuestos buscados paginados
    CREATE TEMPORARY TABLE tmp_PresupuestosPaginados AS
    SELECT DISTINCT tmp.IdPresupuesto
    FROM tmp_Presupuestos tmp
    ORDER BY tmp.IdPresupuesto DESC
    LIMIT pOffset, pLongitudPagina;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;
    
    -- Resultset de los presupuestos con sus montos totales
    CREATE TEMPORARY TABLE tmp_presupuestosPrecios AS
    SELECT  
		tmpp.*, 
        SUM(lp.Cantidad * lp.PrecioUnitario) AS PrecioTotal, 
        IF(COUNT(lp.IdLineaProducto) > 0, CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
            "LineasProducto",  
                JSON_OBJECT(
                    "IdLineaProducto", lp.IdLineaProducto,
                    "IdProductoFinal", lp.IdProductoFinal,
                    "Cantidad", lp.Cantidad,
                    "PrecioUnitario", lp.PrecioUnitario
                ),
            "ProductosFinales",
                JSON_OBJECT(
                    "IdProductoFinal", pf.IdProductoFinal,
                    "IdProducto", pf.IdProducto,
                    "IdTela", pf.IdTela,
                    "IdLustre", pf.IdLustre,
                    "FechaAlta", pf.FechaAlta
                ),
            "Productos",
                JSON_OBJECT(
                    "IdProducto", pr.IdProducto,
                    "Producto", pr.Producto
                ),
            "Telas",IF (te.IdTela  IS NOT NULL,
                JSON_OBJECT(
                    "IdTela", te.IdTela,
                    "Tela", te.Tela
                ),NULL),
            "Lustres",IF (lu.IdLustre  IS NOT NULL,
                JSON_OBJECT(
                    "IdLustre", lu.IdLustre,
                    "Lustre", lu.Lustre
                ), NULL)
        ) ORDER BY lp.Cantidad DESC),''), ']') AS JSON), NULL) AS LineasPresupuesto
    FROM    tmp_PresupuestosPaginados tmpp
    LEFT JOIN LineasProducto lp ON tmpp.IdPresupuesto = lp.IdReferencia AND lp.Tipo = 'P'
    LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
    LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
    LEFT JOIN Telas te ON pf.IdTela = te.IdTela
    LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
    GROUP BY tmpp.IdPresupuesto;

    SET pRespuesta = JSON_OBJECT(
        "Paginaciones", JSON_OBJECT(
            "Pagina", pPagina,
            "LongitudPagina", pLongitudPagina,
            "CantidadTotal", pCantidadTotal
        ),
        "resultado", (
            SELECT CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
                "Presupuestos",  JSON_OBJECT(
                    'IdPresupuesto', p.IdPresupuesto,
                    'IdCliente', p.IdCliente,
                    'IdVenta', p.IdVenta,
                    'IdUbicacion', p.IdUbicacion,
                    'IdUsuario', p.IdUsuario,
                    'PeriodoValidez', p.PeriodoValidez,
                    'FechaAlta', p.FechaAlta,
                    'Observaciones', p.Observaciones,
                    'Estado', IF(p.FechaAlta < pFechaExpiracion, "X", p.Estado),
                    '_PrecioTotal', tmpp.PrecioTotal
                ),
                "Clientes", JSON_OBJECT(
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasPresupuesto", tmpp.LineasPresupuesto
            ) ORDER BY p.FechaAlta DESC),''), ']') AS JSON)
            FROM tmp_presupuestosPrecios tmpp
            INNER JOIN Presupuestos p ON p.IdPresupuesto = tmpp.IdPresupuesto
            INNER JOIN Clientes c ON p.IdCliente = c.IdCliente
            INNER JOIN Usuarios u ON p.IdUsuario = u.IdUsuario
            INNER JOIN Ubicaciones ub ON p.IdUbicacion = ub.IdUbicacion
        )
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_Presupuestos;
    DROP TEMPORARY TABLE IF EXISTS tmp_PresupuestosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmp_presupuestosPrecios;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_presupuesto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un presupuesto. 
        Controla que exista el cliente para el cual se le esta creando, la ubicación donde se esta realizando y el usuario que lo está creando.
        Crea al Presupuesto en Estado 'E'.
        Devuelve el presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuesto a crear
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;
    DECLARE pIdCliente int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pPeriodoValidez tinyint;
    DECLARE pObservaciones varchar(255);


    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdCliente = pPresupuestos ->> "$.IdCliente";
    SET pIdUbicacion = pPresupuestos ->> "$.IdUbicacion";
    SET pObservaciones = pPresupuestos ->> "$.Observaciones";

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT Valor INTO pPeriodoValidez FROM Empresa WHERE Parametro = 'PERIODOVALIDEZ'; 


    START TRANSACTION;

    INSERT INTO Presupuestos (IdPresupuesto, IdCliente, IdVenta, IdUbicacion, IdUsuario, PeriodoValidez, FechaAlta, Observaciones, Estado) VALUES(0, pIdCliente, NULL, pIdUbicacion, pIdUsuarioEjecuta, pPeriodoValidez, NOW(), NULLIF(pObservaciones, ''), 'E');

    SELECT MAX(IdPresupuesto) INTO pIdPresupuesto FROM Presupuestos;

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
                        ) 
                )
             AS JSON)
			FROM	Presupuestos p
			WHERE	p.IdPresupuesto = pIdPresupuesto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_presupuesto_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite pasar instanciar un presupuesto a partir de su Id. 
        Devuelve el presupuesto con sus lineas de presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuestos
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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_dame', pIdUsuarioEjecuta, pMensaje);
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

    CALL zsp_usuario_tiene_permiso(pToken, 'dame_presupuesto_ajeno', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto AND IdUsuario = pIdUsuarioEjecuta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "Presupuestos",  JSON_OBJECT(
                'IdPresupuesto', p.IdPresupuesto,
                'IdCliente', p.IdCliente,
                'IdVenta', p.IdVenta,
                'IdUbicacion', p.IdUbicacion,
                'IdUsuario', p.IdUsuario,
                'PeriodoValidez', p.PeriodoValidez,
                'FechaAlta', p.FechaAlta,
                'Observaciones', p.Observaciones,
                'Estado', p.Estado,
                '_PrecioTotal', SUM(lp.Cantidad * lp.PrecioUnitario)
            ),
            "Clientes", JSON_OBJECT(
                'Nombres', c.Nombres,
                'Apellidos', c.Apellidos,
                'RazonSocial', c.RazonSocial,
                'Documento', c.Documento
            ),
            "Usuarios", JSON_OBJECT(
                "Nombres", u.Nombres,
                "Apellidos", u.Apellidos
            ),
            "Ubicaciones", JSON_OBJECT(
                "Ubicacion", ub.Ubicacion
            ),
            "Domicilios", JSON_OBJECT(
                "Domicilio", d.Domicilio
            ),
            "LineasPresupuesto", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario
                        ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            ), JSON_ARRAY())
        )
        FROM Presupuestos p
        INNER JOIN Clientes c ON c.IdCliente = p.IdCliente
        INNER JOIN Usuarios u ON u.IdUsuario = p.IdUsuario
        INNER JOIN Ubicaciones ub ON ub.IdUbicacion = p.IdUbicacion
        INNER JOIN Domicilios d ON d.IdDomicilio = ub.IdDomicilio
        LEFT JOIN LineasProducto lp ON p.IdPresupuesto = lp.IdReferencia AND lp.Tipo = 'P'
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	p.IdPresupuesto = pIdPresupuesto
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
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

    SET pRespuesta = (
        SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario
                        ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            )
        FROM Presupuestos p
        LEFT JOIN LineasProducto lp ON p.IdPresupuesto = lp.IdReferencia AND lp.Tipo = 'P'
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	p.IdPresupuesto = pIdPresupuesto
    );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_presupuesto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_modificar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un presupuesto existente. 
        Controla que el presupuesto no se encuentre en Estado 'Vendido' exista el cliente para el cual se le esta creando, la ubicación donde se esta realizando y el usuario que lo está modificando.
        Devuelve el presupuesto en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Presupuesto a crear
    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;
    DECLARE pIdCliente int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pPeriodoValidez tinyint;
    DECLARE pObservaciones varchar(255);


    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Presupuesto
    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pIdPresupuesto = pPresupuestos ->> "$.IdPresupuesto";
    SET pIdCliente = pPresupuestos ->> "$.IdCliente";
    SET pIdUbicacion = pProductos ->> "$.IdUbicacion";
    SET pObservaciones = pProductos ->> "$.Observaciones";

    IF pIdPresupuesto IS NULL OR NOT EXISTS (SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) <> 'E' THEN
        SELECT f_generarRespuesta("ERROR_MODIFICAR_PRESUPUESTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdCliente IS NULL OR NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;


    START TRANSACTION;

    UPDATE Presupuestos
    SET IdCliente = pIdCliente,
        IdUbicacion = pIdUbicacion,
        Observaciones = NULLIF(pObservaciones, '')
    WHERE IdPresupuesto = pIdPresupuesto;

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
                        ) 
                )
             AS JSON)
			FROM	Presupuestos p
			WHERE	p.IdPresupuesto = pIdPresupuesto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_presupuesto_pasar_a_creado`;

DELIMITER $$
CREATE PROCEDURE `zsp_presupuesto_pasar_a_creado`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite pasar un presupuesto a creado. 
        Controla que exista presupuesto tenga al menos una linea de presupuesto asociada.
        Cambia el Estado a 'C'.
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
    DECLARE pPeriodoValidez tinyint;


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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuesto_pasar_a_creado', pIdUsuarioEjecuta, pMensaje);
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

    SELECT Valor INTO pPeriodoValidez FROM Empresa WHERE Parametro = 'PERIODOVALIDEZ'; 

    IF NOW() >= (SELECT DATE_ADD(FechaAlta, INTERVAL pPeriodoValidez DAY) FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_PRESUPUESTO_EXPIRADO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'P' AND IdReferencia = pIdPresupuesto) THEN
        SELECT f_generarRespuesta("ERROR_PRESUPUESTO_SINLINEAS", NULL) pOut;
        LEAVE SALIR;
    END IF;


    START TRANSACTION;

    UPDATE Presupuestos
    SET Estado = 'C'
    WHERE IdPresupuesto = pIdPresupuesto;

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
                        ) 
                )
             AS JSON)
			FROM	Presupuestos p
			WHERE	p.IdPresupuesto = pIdPresupuesto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS zsp_presupuestos_dame_multiple;
DELIMITER $$
CREATE PROCEDURE zsp_presupuestos_dame_multiple(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instancias mas de un presupuesto a partir de sus Id.
        Devuelve los presupuestos con sus lineas de presupuesto en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pPresupuestos JSON;
    DECLARE pIdPresupuesto int;

    DECLARE pLongitud int unsigned;
    DECLARE pIndex int unsigned DEFAULT 0;
    DECLARE pCondicion varchar(100);

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuestos_dame_multiple', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pPresupuestos = pIn ->> "$.Presupuestos";
    SET pLongitud = JSON_LENGTH(pPresupuestos);
    SET pRespuesta = JSON_ARRAY();

    WHILE pIndex < pLongitud DO
        SET pIdPresupuesto = JSON_EXTRACT(pPresupuestos, CONCAT("$[", pIndex, "]"));

        IF NOT EXISTS(SELECT IdPresupuesto FROM Presupuestos WHERE IdPresupuesto = pIdPresupuesto) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_PRESUPUESTO", NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET @pPresupuesto = (
            SELECT JSON_OBJECT(
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
                "Clientes", JSON_OBJECT(
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasPresupuesto", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "_PrecioUnitarioActual",  f_calcularPrecioProductoFinal(lp.IdProductoFinal)
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            )
            FROM Presupuestos p
            INNER JOIN Clientes c ON c.IdCliente = p.IdCliente
            INNER JOIN Usuarios u ON u.IdUsuario = p.IdUsuario
            INNER JOIN Ubicaciones ub ON ub.IdUbicacion = p.IdUbicacion
            LEFT JOIN LineasProducto lp ON p.IdPresupuesto = lp.IdReferencia AND lp.Tipo = 'P'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	p.IdPresupuesto = pIdPresupuesto
        );

        SET pRespuesta = JSON_ARRAY_INSERT(pRespuesta, CONCAT('$[', pIndex, ']'), CAST(@pPresupuesto AS JSON));
        SET pIndex = pIndex + 1;
    END WHILE;
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_presupuestos_transformar_venta;
DELIMITER $$
CREATE PROCEDURE zsp_presupuestos_transformar_venta(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una venta a partir de un conjunto de lineas de presupuesto.
        Controla que todas las lineas pertenezcan a presupuestos del mismo cliente.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdCliente int;
    DECLARE pIdDomicilio int;
    DECLARE pEstado char(1) DEFAULT 'C';
    DECLARE pObservaciones varchar(255);

    -- LineasPresupuesto
    DECLARE pLineasPresupuesto JSON;
    DECLARE pIdLineaProducto bigint;
    DECLARE pIdProductoFinal int;
    DECLARE pTipo char(1);
    DECLARE pIdReferencia int;
    DECLARE pPrecioUnitario decimal(10,2);
    DECLARE pCantidad tinyint;

    -- LineasVenta
    DECLARE pLineasVenta JSON;
    DECLARE pLineaVenta JSON;
 

    DECLARE pLongitud INT UNSIGNED;
    DECLARE pIndex INT UNSIGNED DEFAULT 0;

    DECLARE pIdLineaProductoPendiente bigint;
    DECLARE fin tinyint;

    DECLARE pError varchar(255);

    DECLARE pRespuesta JSON;

    DECLARE lineasPresupuestos_cursor CURSOR FOR
        SELECT lp.IdLineaProducto 
        FROM Presupuestos p
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'P' AND lp.IdReferencia = p.IdPresupuesto)
        WHERE lp.Estado = 'P' AND p.Estado = 'V' AND p.IdVenta = @pIdVenta;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_presupuestos_transformar_venta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> '$.Ventas';
    SET pIdDomicilio = COALESCE(pVentas ->> '$.IdDomicilio', 0);
    SET pIdUbicacion = COALESCE(pVentas ->> '$.IdUbicacion', 0);
    SET pObservaciones = COALESCE(pVentas ->> '$.Observaciones', '');

    IF NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion AND Estado = 'A') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pLineasPresupuesto = COALESCE(pIn ->> "$.LineasPresupuesto", JSON_ARRAY());
        SET pLongitud = JSON_LENGTH(pLineasPresupuesto);

        WHILE pIndex < pLongitud DO
            SET pIdLineaProducto = JSON_EXTRACT(pLineasPresupuesto, CONCAT("$[", pIndex, "]"));
            -- SET pIdLineaProducto = pLineasPresupuesto -> CONCAT('$[', pIndex, ']');
            SELECT IdProductoFinal, IdReferencia, Tipo, PrecioUnitario, Cantidad 
            INTO pIdProductoFinal, pIdReferencia, pTipo, pPrecioUnitario, pCantidad 
            FROM LineasProducto 
            WHERE IdLineaProducto = pIdLineaProducto AND Estado = 'P';

            IF pTipo IS NULL OR pTipo != 'P' THEN
                SELECT f_generarRespuesta("ERROR_TIPO_INVALIDO", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pIndex = 0 THEN
                SET pIdCliente = (SELECT IdCliente FROM Presupuestos WHERE IdPresupuesto = pIdReferencia);
                IF pIdCliente > 0 AND pIdDomicilio > 0 THEN
                    IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
                        SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
                        LEAVE SALIR;
                    END IF;
                END IF;

                INSERT INTO Ventas (IdVenta, IdCliente, IdDomicilio, IdUbicacion, IdUsuario, FechaAlta, Observaciones, Estado)
                VALUES (0, pIdCliente, pIdDomicilio, pIdUbicacion, pIdUsuarioEjecuta, NOW(), pObservaciones, 'E');
                SET @pIdVenta = LAST_INSERT_ID();
            ELSE
                IF (SELECT IdCliente FROM Presupuestos WHERE IdPresupuesto = pIdReferencia) !=  pIdCliente THEN
                    SELECT f_generarRespuesta("ERROR_CLIENTE_INVALIDO", NULL) pOut;
                    LEAVE SALIR;
                END IF;
            END IF;

            UPDATE LineasProducto
            SET Estado = 'U'
            WHERE IdLineaProducto = pIdLineaProducto;

            UPDATE Presupuestos
            SET
                IdVenta = @pIdVenta,
                Estado = 'V'
            WHERE IdPresupuesto = pIdReferencia;

            INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado)
            VALUES (0, pIdLineaProducto, pIdProductoFinal, NULL, @pIdVenta, 'V', pPrecioUnitario, pCantidad, NOW(), NULL, 'P');

            SET pIndex := pIndex + 1;
        END WHILE;

        SET pIndex = 0;

        OPEN lineasPresupuestos_cursor;
            get_lineaPresupuesto: LOOP
                FETCH lineasPresupuestos_cursor INTO pIdLineaProductoPendiente;
                IF fin = 1 THEN
                    LEAVE get_lineaPresupuesto;
                END IF;

                UPDATE LineasProducto
                SET Estado = 'N'
                WHERE IdLineaProducto = pIdLineaProductoPendiente;
            END LOOP get_lineaPresupuesto;
        CLOSE lineasPresupuestos_cursor;

        SET pLineasVenta = COALESCE(pIn ->> "$.LineasVenta", JSON_ARRAY());
        SET pLongitud = JSON_LENGTH(pLineasVenta);

        WHILE pIndex < pLongitud DO
            SET pLineaVenta = JSON_EXTRACT(pLineasVenta, CONCAT("$[", pIndex, "]"));
            SET pLineaVenta = (SELECT JSON_SET(pLineaVenta, '$.LineasProducto.IdReferencia', @pIdVenta, '$.LineasProducto.Tipo', 'V'));
            CALL zsp_lineaVenta_crear_interno(pLineaVenta, pIdLineaProducto, pError);
            IF pError IS NOT NULL THEN
                SELECT f_generarRespuesta(pError, NULL) pOut;
                LEAVE SALIR;
            END IF;
            IF (SELECT PrecioUnitario FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'V') != f_calcularPrecioProductoFinal(pIdLineaProducto) THEN
                SET pEstado = 'R';
            END IF;

            SET pIndex = pIndex + 1;
        END WHILE;

        IF EXISTS(
            SELECT IdLineaProducto 
            FROM LineasProducto 
            WHERE 
                IdReferencia = @pIdVenta 
                AND Tipo = 'V'
                AND PrecioUnitario != f_calcularPrecioProductoFinal(IdProductoFinal) 
        ) THEN
            SET pEstado = 'R';
        END IF;

        UPDATE Ventas
        SET Estado = pEstado
        WHERE IdVenta = @pIdVenta;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Ventas",  JSON_OBJECT(
                    'IdVenta', v.IdVenta,
                    'IdCliente', v.IdCliente,
                    'IdDomicilio', v.IdDomicilio,
                    'IdUbicacion', v.IdUbicacion,
                    'IdUsuario', v.IdUsuario,
                    'FechaAlta', v.FechaAlta,
                    'Observaciones', v.Observaciones,
                    'Estado', v.Estado
                ),
                "Clientes", JSON_OBJECT(
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial
                ),
                "Domicilios", JSON_OBJECT(
                    'Domicilio', d.Domicilio
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasVenta", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            )
            FROM Ventas v
            INNER JOIN Usuarios u ON u.IdUsuario = v.IdUsuario
            INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
            INNER JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
            INNER JOIN Ubicaciones ub ON ub.IdUbicacion = v.IdUbicacion
            LEFT JOIN LineasProducto lp ON v.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	v.IdVenta = @pIdVenta
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_productoFinal_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar un producto final. Controla que no este siendo utilizado en un presupuesto, venta, órden de producción o remito.
        Devuelve NULL 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProductoFinal = pProductosFinales ->> "$.IdProductoFinal";

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT pf.IdProductoFinal FROM ProductosFinales pf INNER JOIN LineasProducto lp ON pf.IdProductoFinal = lp.IdProductoFinal WHERE pf.IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE FROM ProductosFinales pf WHERE pf.IdProductoFinal = pIdProductoFinal;
		SELECT f_generarRespuesta(NULL, NULL) AS pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_productoFinal_crear_interno`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_crear_interno`(pIn JSON, out pIdProductoFinal int, out pError varchar(255))
SALIR:BEGIN
    /*
        Procedimiento que permite crear un producto final. Controla que exista el producto, tela y lustre, y que no se repita la combinacion Producto, Tela y Lustre.
        Devuelve el producto final, junto al producto, tela y lustre en 'respuesta' o el error en 'error'.
    */

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;

     -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdTela = 0 THEN
        SET pIdTela = NULL;
    END IF;
    IF pIdLustre = 0 THEN
        SET pIdLustre = NULL;
    END IF;

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT "ERROR_NOEXISTE_PRODUCTO" INTO pError;
        LEAVE SALIR;
    END IF;

    IF ((SELECT tp.IdTipoProducto FROM TiposProducto tp INNER JOIN Productos p ON p.IdTipoProducto = tp.IdTipoProducto WHERE IdProducto = pIdProducto) != (SELECT Valor FROM Empresa WHERE Parametro = 'IDTIPOPRODUCTOFABRICABLE')) AND (pIdTela IS NOT NULL OR pIdLustre IS NOT NULL) THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTO_INVALIDO", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF pIdTela IS NOT NULL AND pIdTela != 0 THEN
        IF (SELECT LongitudTela FROM Productos WHERE IdProducto = pIdProducto) <=0 THEN
            SELECT f_generarRespuesta("ERROR_PRODUCTO_INVALIDO", NULL) pOut;
            LEAVE SALIR;
        END IF;
        IF NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
            SELECT "ERROR_NOEXISTE_TELA" INTO pError;
            LEAVE SALIR;
        END IF;
    END IF;

    IF pIdLustre IS NOT NULL AND pIdLustre != 0 THEN
        IF NOT EXISTS (SELECT IdLustre FROM Lustres WHERE IdLustre = pIdLustre) THEN
            SELECT "ERROR_NOEXISTE_LUSTRE" INTO pError;
            LEAVE SALIR;
        END IF;
    END IF;
    
    -- Controlo que no se repita la combinacion Producto-Tela-Lustre o Producto-Lustre o Producto-Tela
    IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela IS NULL, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre IS NULL, IdLustre IS NULL, IdLustre = pIdLustre)) THEN
        SELECT "ERROR_EXISTE_PRODUCTOFINAL" INTO pError;
        LEAVE SALIR;
    END IF;

    INSERT INTO ProductosFinales (IdProductoFinal, IdProducto, IdLustre, IdTela, FechaAlta, FechaBaja, Estado) VALUES(0, pIdProducto, pIdLustre, IF(pIdTela = 0, NULL, pIdTela), NOW(), NULL, 'A');
    SET pIdProductoFinal = LAST_INSERT_ID();
    SET pError = NULL;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_productoFinal_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un producto final. Llama a zsp_productoFinal_crear_interno.
        Devuelve el producto final, junto al producto, tela y lustre en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Producto Final
    DECLARE pIdProductoFinal int;

    -- Llamado a zsp_productoFinal_crear_interno
    DECLARE pError varchar(255);


     -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        CALL zsp_productoFinal_crear_interno(pIn, pIdProductoFinal, pError);
        IF pError IS NULL THEN
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
                        )
                    )
                AS JSON)
                FROM	ProductosFinales pf
                WHERE	pf.IdProductoFinal = pIdProductoFinal
            );
            SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
        ELSE
            SELECT f_generarRespuesta(NULL, pError) AS pOut;
        END IF;
    COMMIT;

END $$
DELIMITER ;
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

    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;

    -- Ultimos precios Productos
    CREATE TEMPORARY TABLE tmp_preciosProductos AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'P' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPreciosProductos AS
    SELECT pr.* 
    FROM tmp_preciosProductos tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    -- Ultimos precios Telas
    CREATE TEMPORARY TABLE tmp_preciosTelas AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'T' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPreciosTelas AS
    SELECT pr.* 
    FROM tmp_preciosTelas tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "ProductosFinales",  
                            JSON_OBJECT(
                                'IdProductoFinal', pf.IdProductoFinal,
                                'IdProducto', pf.IdProducto,
                                'IdLustre', pf.IdLustre,
                                'IdTela', pf.IdTela,
                                'FechaAlta', pf.FechaAlta,
                                'FechaBaja', pf.FechaBaja,
                                'Estado', pf.Estado,
                                '_PrecioTotal', (upp.Precio + COALESCE(pr.LongitudTela, 0) * upt.Precio),
                                '_Cantidad', f_calcularStockProducto(pf.IdProductoFinal, 0)
                            ),
                        "Productos",
                            JSON_OBJECT(
                                'IdProducto', pr.IdProducto,
                                'IdCategoriaProducto', pr.IdCategoriaProducto,
                                'IdGrupoProducto', pr.IdGrupoProducto,
                                'IdTipoProducto', pr.IdTipoProducto,
                                'Producto', pr.Producto,
                                'LongitudTela', pr.LongitudTela,
                                'FechaAlta', pr.FechaAlta,
                                'FechaBaja', pr.FechaBaja,
                                'Observaciones', pr.Observaciones,
                                'Estado', pr.Estado
                            ),
                        "Lustres",
                            JSON_OBJECT(
                                'IdLustre', lu.IdLustre,
                                'Lustre', lu.Lustre
                            ),
                        "Telas",  
                            JSON_OBJECT(
                                'IdTela', te.IdTela,
                                'Tela', te.Tela
                            )
                )
             AS JSON)
			FROM	ProductosFinales pf            
            INNER JOIN Productos pr ON (pr.IdProducto = pf.IdProducto)
            LEFT JOIN Telas te ON (te.IdTela = pf.IdTela)
            LEFT JOIN Lustres lu ON (lu.IdLustre = pf.IdLustre)
            INNER JOIN tmp_ultimosPreciosProductos upp ON (pf.IdProducto = upp.IdReferencia)
            LEFT JOIN tmp_ultimosPreciosTelas upt ON (pf.IdTela = upt.IdReferencia)
            WHERE pf.IdProductoFinal = pIdProductoFinal
        );
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_productoFinal_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_dar_alta`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de alta un producto final que se encontraba en estado "Baja". Controla que el producto final exista
        Devuelve un json con el producto en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProductoFinal = pProductosFinales ->> "$.IdProductoFinal";

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTOFINAL_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE ProductosFinales
        SET Estado = 'A'
        WHERE IdProductoFinal = pIdProductoFinal;

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
                    )
                )
             AS JSON)
			FROM	ProductosFinales pf
			WHERE	pf.IdProductoFinal = pIdProductoFinal
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;


END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_productoFinal_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_dar_baja`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de baja un producto final que se encontraba en estado "Alta". Controla que el producto final exista
        Devuelve un json con el producto en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- ProductoFinal
    DECLARE pProductosFinales JSON;
    DECLARE pIdProductoFinal int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProductoFinal = pProductosFinales ->> "$.IdProductoFinal";

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTOFINAL_ESTA_BAJA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE ProductosFinales
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdProductoFinal = pIdProductoFinal;

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
                    )
                )
             AS JSON)
			FROM	ProductosFinales pf
			WHERE	pf.IdProductoFinal = pIdProductoFinal
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_productoFinal_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_productoFinal_modificar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un producto final. Controla que exista el producto, tela y lustre, y que no se repita la combinacion Producto, Tela y Lustre.
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

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProductoFinal = pProductosFinales ->> "$.IdProductoFinal";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";

    IF pIdProductoFinal IS NULL OR NOT EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela IS NOT NULL AND NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdLustre IS NOT NULL AND NOT EXISTS (SELECT IdLustre FROM Lustres WHERE IdLustre = pIdLustre) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LUSTRE", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    -- Controlo que no se repita la combinacion Producto-Tela-Lustre o Producto-Lustre o Producto-Tela
    IF pIdLustre IS NOT NULL THEN
        IF pIdTela IS NOT NULL THEN
            IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdTela = pIdTela AND IdLustre = pIdLustre) THEN
                SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL", NULL) pOut;
                LEAVE SALIR;
            END IF;
        ELSE
            IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdLustre = pIdLustre) THEN
                SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL", NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
    ELSE
        IF pIdTela IS NOT NULL THEN
            IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdTela = pIdTela) THEN
                SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL", NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;
    END IF;


    START TRANSACTION;
        UPDATE ProductosFinales
        SET IdProducto = pIdProducto,
            IdTela = pIdTela,
            IdLustre = pIdLustre
        WHERE IdProductoFinal = pIdProductoFinal;

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
                    )
                )
             AS JSON)
			FROM	ProductosFinales pf
			WHERE	pf.IdProductoFinal = pIdProductoFinal
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS zsp_productoFinal_mover;
DELIMITER $$
CREATE PROCEDURE zsp_productoFinal_mover(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite mover un producto final de una ubicacion a otra.
        Devuelve el producto final en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdProductoFinal int;
    DECLARE pCantidad int;
    DECLARE pIdUbicacionEntrada tinyint;
    DECLARE pIdUbicacionSalida tinyint;
    DECLARE pProductosFinales JSON;

    DECLARE pIdLineaRemito bigint;
    DECLARE pError varchar(255);

    DECLARE pRespuesta JSON;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_mover', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdProductoFinal = pIn ->> "$.LineasProducto.IdProductoFinal";
    SET pCantidad = pIn ->> "$.LineasProducto.Cantidad";
    SET pIdUbicacionEntrada = pIn ->> "$.UbicacionesEntrada.IdUbicacion";
    SET pIdUbicacionSalida = pIn ->> "$.UbicacionesSalida.IdUbicacion";

    IF NOT EXISTS(SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTOFINAL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacionEntrada) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacionSalida) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pCantidad > f_calcularStockProducto(pIdProductoFinal, pIdUbicacionSalida) THEN
        SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        -- Creo el remito de salida
        INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, NULL, pIdUsuarioEjecuta, 'S', NULL, NOW(), 'Movimiento de productos', 'E');

        SET @pIdRemitoSalida = LAST_INSERT_ID();

        SET pProductosFinales = (
            SELECT JSON_OBJECT(
                'IdProducto', IdProducto,
                'IdLustre', COALESCE(IdLustre, 0),
                'IdTela', COALESCE(IdTela, 0)
            )
            FROM ProductosFinales
            WHERE IdProductoFinal = pIdProductoFinal
        );

        CALL zsp_lineaRemito_crear_interno(
            JSON_OBJECT(
                'LineasProducto',JSON_OBJECT(
                    'IdReferencia', @pIdRemitoSalida,
                    'IdUbicacion', pIdUbicacionSalida,
                    'Cantidad', pCantidad
                ),
                'ProductosFinales', pProductosFinales
            ), 
            pIdLineaRemito,
            pError
        );

        IF pError IS NOT NULL THEN
            SELECT f_generarRespuesta(pError, NULL) pOut;
            LEAVE SALIR;
        END IF;

        -- Creo el remito de entrada
        INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, pIdUbicacionEntrada, pIdUsuarioEjecuta, 'E', NULL, NOW(), 'Movimiento de productos', 'E');
        
        SET @pIdRemitoEntrada = LAST_INSERT_ID();

        CALL zsp_lineaRemito_crear_interno(
            JSON_OBJECT(
                'LineasProducto',JSON_OBJECT(
                    'IdReferencia', @pIdRemitoEntrada,
                    'Cantidad', pCantidad
                ),
                'ProductosFinales', pProductosFinales
            ), 
            pIdLineaRemito,
            pError
        );

        IF pError IS NOT NULL THEN
            SELECT f_generarRespuesta(pError, NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET @pNow = NOW();

        UPDATE Remitos
        SET Estado = 'C',
            FechaEntrega = @pNow
        WHERE IdRemito = @pIdRemitoEntrada;

        UPDATE Remitos
        SET Estado = 'C',
            FechaEntrega = @pNow
        WHERE IdRemito = @pIdRemitoSalida;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                'ProductosFinales', JSON_OBJECT(
                    'IdProductoFinal', pf.IdProductoFinal,
                    'IdProducto', pf.IdProducto,
                    'IdTela', pf.IdTela,
                    'IdLustre', pf.IdLustre,
                    '_Cantidad', @pCantidad
                ),
                'Productos', JSON_OBJECT(
                    'IdProducto', p.IdProducto,
                    'Producto', p.Producto
                ),
                'Telas',IF (t.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela
                    ),NULL
                ),
                'Lustres',IF (l.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        'IdLustre', l.IdLustre,
                        'Lustre', l.Lustre
                    ), NULL
                ),
                'Ubicaciones', CAST(@pUbicaciones AS JSON)
            )
            FROM ProductosFinales pf
            INNER JOIN Productos p ON pf.IdProducto = p.IdProducto
            LEFT JOIN Telas t ON pf.IdTela = t.IdTela
            LEFT JOIN Lustres l ON pf.IdLustre = l.IdLustre
            WHERE pf.IdProductoFinal = pIdProductoFinal
        );

         SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_productoFinal_stock;
DELIMITER $$
CREATE PROCEDURE zsp_productoFinal_stock(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite conocer el stock de un producto final en una ubicacion determinada.
    */
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productoFinal_stock', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdUbicacion = COALESCE(pIn->>'$.Ubicaciones.IdUbicacion', 0);
    SET pIdProductoFinal = COALESCE(pIn->>'$.ProductosFinales.IdProductoFinal', 0);
    SET pIdProducto = COALESCE(pIn->>'$.ProductosFinales.IdProducto', 0);
    SET pIdLustre = COALESCE(pIn->>'$.ProductosFinales.IdLustre', 0);
    SET pIdTela = COALESCE(pIn->>'$.ProductosFinales.IdTela', 0);

    IF pIdProductoFinal = 0 THEN
        SET pIdProductoFinal = COALESCE((SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela) AND IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre)), 0);
    END IF;

    IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_UBICACION_NOEXISTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdProductoFinal = 0 THEN
        SELECT f_generarRespuesta('ERROR_PRODUCTOFINAL_NOEXISTE', NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET @pCantidad = f_calcularStockProducto(pIdProductoFinal, pIdUbicacion);

    SET @pUbicaciones = (
        SELECT JSON_OBJECT(
            'IdUbicacion', IdUbicacion,
            'Ubicacion', Ubicacion
        ) 
        FROM Ubicaciones 
        WHERE IdUbicacion = pÌdUbicacion
    );

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            'ProductosFinales', JSON_OBJECT(
                'IdProductoFinal', pf.IdProductoFinal,
                'IdProducto', pf.IdProducto,
                'IdTela', pf.IdTela,
                'IdLustre', pf.IdLustre,
                '_Cantidad', @pCantidad
            ),
            'Productos', JSON_OBJECT(
                'IdProducto', p.IdProducto,
                'Producto', p.Producto
            ),
            'Telas',IF (t.IdTela  IS NOT NULL,
                JSON_OBJECT(
                    'IdTela', t.IdTela,
                    'Tela', t.Tela
                ),NULL
            ),
            'Lustres',IF (l.IdLustre  IS NOT NULL,
                JSON_OBJECT(
                    'IdLustre', l.IdLustre,
                    'Lustre', l.Lustre
                ), NULL
            ),
            'Ubicaciones', CAST(@pUbicaciones AS JSON)
        )
        FROM ProductosFinales pf
        INNER JOIN Productos p ON pf.IdProducto = p.IdProducto
        LEFT JOIN Telas t ON pf.IdTela = t.IdTela
        LEFT JOIN Lustres l ON pf.IdLustre = l.IdLustre
        WHERE pf.IdProductoFinal = pIdProductoFinal
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_productosFinales_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_productosFinales_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar un producto por su nombre, Tipo de Producto (T: Todos), Categoria de Productos (0: Todos), Grupo de Productos (0 : Todos), Estado (A:Activo - B:Baja - T:Todos).
        Devuelve una lista de productos en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a buscar
    DECLARE pProductosFinales JSON;
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;
    DECLARE pEstado char(1);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productosFinales_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductosFinales = pIn ->> "$.ProductosFinales";
    SET pIdProducto = pProductosFinales ->> "$.IdProducto";
    SET pIdTela = pProductosFinales ->> "$.IdTela";
    SET pIdLustre = pProductosFinales ->> "$.IdLustre";
    SET pEstado = pProductosFinales ->> "$.Estado";

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    SET pIdProducto = COALESCE(pIdProducto, 0);
    SET pIdTela = COALESCE(pIdTela, 0);
    SET pIdLustre = COALESCE(pIdLustre, 0);

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_ProductosFinales;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    -- Resultset completo
    CREATE TEMPORARY TABLE tmp_ProductosFinales
    AS SELECT *
    FROM ProductosFinales
	WHERE (IdProducto = pIdProducto OR pIdProducto = 0)
    AND (IdTela = pIdTela OR pIdTela = 0)
    AND (IdLustre = pIdLustre OR pIdLustre = 0)
    AND (Estado = pEstado OR pEstado = 'T');

    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_ProductosFinales);

    -- Resultset paginado
    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * 
    FROM tmp_ProductosFinales
    LIMIT pOffset, pLongitudPagina;

    -- Ultimos precios Productos
    CREATE TEMPORARY TABLE tmp_preciosProductos AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'P' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPreciosProductos AS
    SELECT pr.* 
    FROM tmp_preciosProductos tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    -- Ultimos precios Telas
    CREATE TEMPORARY TABLE tmp_preciosTelas AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'T' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPreciosTelas AS
    SELECT pr.* 
    FROM tmp_preciosTelas tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pRespuesta = (SELECT 
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", 
                JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "ProductosFinales",  
                            JSON_OBJECT(
                                'IdProductoFinal', tp.IdProductoFinal,
                                'IdProducto', tp.IdProducto,
                                'IdLustre', tp.IdLustre,
                                'IdTela', tp.IdTela,
                                'FechaAlta', tp.FechaAlta,
                                'FechaBaja', tp.FechaBaja,
                                'Estado', tp.Estado,
                                '_PrecioTotal', (upp.Precio + COALESCE(pr.LongitudTela, 0) * upt.Precio),
                                '_Cantidad', f_calcularStockProducto(tp.IdProductoFinal, 0)
                            ),
                        "Productos",
                            JSON_OBJECT(
                                'IdProducto', pr.IdProducto,
                                'IdCategoriaProducto', pr.IdCategoriaProducto,
                                'IdGrupoProducto', pr.IdGrupoProducto,
                                'IdTipoProducto', pr.IdTipoProducto,
                                'Producto', pr.Producto,
                                'LongitudTela', pr.LongitudTela,
                                'FechaAlta', pr.FechaAlta,
                                'FechaBaja', pr.FechaBaja,
                                'Observaciones', pr.Observaciones,
                                'Estado', pr.Estado
                            ),
                        "Lustres",
                            JSON_OBJECT(
                                'IdLustre', lu.IdLustre,
                                'Lustre', lu.Lustre
                            ),
                        "Telas",  
                            JSON_OBJECT(
                                'IdTela', te.IdTela,
                                'Tela', te.Tela
                            )
                    )
                )
        )
	FROM tmp_ResultadosFinal tp
    INNER JOIN Productos pr ON (pr.IdProducto = tp.IdProducto)
    LEFT JOIN Telas te ON (te.IdTela = tp.IdTela)
    LEFT JOIN Lustres lu ON (lu.IdLustre = tp.IdLustre)
    INNER JOIN tmp_ultimosPreciosProductos upp ON (tp.IdProducto = upp.IdReferencia)
    LEFT JOIN tmp_ultimosPreciosTelas upt ON (tp.IdTela = upt.IdReferencia)
	);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_ProductosFinales;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPreciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_producto_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar un producto junto con todos sus precios, controlando que no sea usado por un producto final.
        Devuelve null en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a borrar
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
         -- Para poder borrar en la tabla precios
        SET SQL_SAFE_UPDATES = 0;
        DELETE FROM Productos WHERE IdProducto = pIdProducto;
        DELETE FROM Precios WHERE Tipo = 'P' AND  IdReferencia = pIdProducto;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
        SET SQL_SAFE_UPDATES = 1;

    COMMIT;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_producto_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_crear`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite crear un producto. Controla que no exista uno con el mismo nombre y que pertenezca a la misma catgoria y grupo de productos, que la longitud de tela necesaria
        sea mayor o igual que cero, que existan la categoeria, el grupo y el tipo de producto, y que el precio sea mayor que cero.
        Devuelve el producto con su precio en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;
    DECLARE pIdCategoriaProducto tinyint;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pIdTipoProducto char(1);
    DECLARE pProducto varchar(80);
    DECLARE pLongitudTela decimal(10,2);
    DECLARE pObservaciones varchar(255);

    -- Precio del producto
    DECLARE pPrecios JSON;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pProducto = pProductos ->> "$.Producto";
    SET pIdCategoriaProducto = pProductos ->> "$.IdCategoriaProducto";
    SET pIdGrupoProducto = pProductos ->> "$.IdGrupoProducto";
    SET pIdTipoProducto = pProductos ->> "$.IdTipoProducto";
    SET pLongitudTela = pProductos ->> "$.LongitudTela";
    SET pObservaciones = pProductos ->> "$.Observaciones";

    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";

    IF pProducto IS NULL OR pProducto = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdCategoriaProducto IS NULL OR NOT EXISTS (SELECT IdCategoriaProducto FROM CategoriasProducto WHERE IdCategoriaProducto = pIdCategoriaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CATEGORIAPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto AND Estado = 'A')) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProducto FROM Productos WHERE Producto = pProducto AND IdCategoriaProducto = pIdCategoriaProducto AND IdGrupoProducto = pIdGrupoProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pLongitudTela < 0 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDA_LONGITUDTELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdTipoProducto FROM TiposProducto WHERE IdTipoProducto = pIdTipoProducto) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Productos (IdProducto, IdCategoriaProducto, IdGrupoProducto, IdTipoProducto, Producto, LongitudTela, FechaAlta, FechaBaja, Observaciones, Estado) VALUES (0, pIdCategoriaProducto, pIdGrupoProducto, pIdTipoProducto, pProducto, pLongitudTela, NOW(), NULL, NULLIF(pObservaciones, ''), 'A');
    SET pIdProducto = (SELECT IdProducto FROM Productos WHERE Producto = pProducto AND IdCategoriaProducto = pIdCategoriaProducto AND IdGrupoProducto = pIdGrupoProducto);
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'P', pIdProducto, NOW());

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
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
                    "Precios", JSON_OBJECT(
                        'IdPrecio', ps.IdPrecio,
                        'Precio', ps.Precio,
                        'FechaAlta', ps.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Productos p
            INNER JOIN Precios ps ON (ps.Tipo = 'P' AND p.IdProducto = ps.IdReferencia)
			WHERE	p.IdProducto = pIdProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_producto_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_dame`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite instanciar un producto a partir de su Id.
        Devuelve el producto con su precio actual en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a borrar
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    DECLARE pIdProductoFinal INT;

    -- Precio actual
    DECLARE pIdPrecio int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Para stock
    DECLARE pStock JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    SELECT IdProductoFinal INTO pIdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND IdTela IS NULL AND IdLustre IS NULL;

    IF COALESCE(pIdProductoFinal, 0) > 0 THEN
        SET pStock = (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', IdUbicacion,
                        'IdDomicilio', IdDomicilio,
                        'Ubicacion', Ubicacion,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Observaciones', Observaciones,
                        'Estado', Estado
                    ),
                    "Cantidad", f_calcularStockProducto(pIdProductoFinal, IdUbicacion)
                )
            ) Stock
            FROM Ubicaciones
            WHERE f_calcularStockProducto(pIdProductoFinal, IdUbicacion) > 0
        );
    END IF;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
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
                        'Estado', p.Estado,
                        'Stock', pStock
                    ),
                    "GruposProducto", 
                        JSON_OBJECT(
                            'IdGrupoProducto', gp.IdGrupoProducto,
                            'Grupo', gp.Grupo,
                            'Estado', gp.Estado
                        ),
                    "CategoriasProducto", 
                        JSON_OBJECT(
                            'IdCategoriaProducto', cp.IdCategoriaProducto,
                            'Categoria', cp.Categoria
                        ),
                    "TiposProducto", 
                        JSON_OBJECT(
                            'IdTipoProducto', tp.IdTipoProducto,
                            'TipoProducto', tp.TipoProducto
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', ps.IdPrecio,
                        'Precio', ps.Precio,
                        'FechaAlta', ps.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Productos p
            INNER JOIN Precios ps ON (ps.Tipo = 'P' AND p.IdProducto = ps.IdReferencia)
            INNER JOIN GruposProducto gp ON (gp.IdGrupoProducto = p.IdGrupoProducto)
            INNER JOIN TiposProducto tp ON (p.IdTipoProducto = tp.IdTipoProducto)
            INNER JOIN CategoriasProducto cp ON (cp.IdCategoriaProducto = p.IdCategoriaProducto)
			WHERE	p.IdProducto = pIdProducto AND ps.IdPrecio = pIdPrecio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_producto_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_dar_alta`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de alta un producto que se encontraba en estado "Baja". Controla que el producto exista
        Devuelve un json con el producto en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Productos WHERE IdProducto = pIdProducto) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTO_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Productos
        SET Estado = 'A'
        WHERE IdProducto = pIdProducto;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
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
                        )
                )
             AS JSON)
			FROM	Productos p
			WHERE	p.IdProducto = pIdProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;


    COMMIT;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_producto_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_dar_baja`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de baja un producto que se encontraba en estado "Alta". Controla que el producto exista
        Devuelve un json con el producto en 'respuesta' o el error en 'error'.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Productos WHERE IdProducto = pIdProducto) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_PRODUCTO_ESTA_BAJA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Productos
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdProducto = pIdProducto;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
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
                        )
                )
             AS JSON)
			FROM	Productos p
			WHERE	p.IdProducto = pIdProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;


    COMMIT;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_producto_listar_precios`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_listar_precios`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar el historico de precios de un producto.
        Devuelve una lista de precios en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Producto del cual se desea conocer el historico de precios
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_listar_precios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "Precios",
            JSON_OBJECT(
                'IdPrecio', IdPrecio,
                'Precio', Precio,
                'FechaAlta', FechaAlta
            )
        )
    ) 
    FROM Precios 
    WHERE Tipo = 'P' AND IdReferencia = pIdProducto
    ORDER BY IdPrecio DESC
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_producto_modificar_precio`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_modificar_precio`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el precio de un producto. Controla que el precio sea mayor que cero.
        Devuelve un json con el producto y el precio en 'respuesta' o el 'error' en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;

    -- Precio
    DECLARE pPrecios JSON;
    DECLARE pIdPrecio int;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_modificar_precio', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos del producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";
    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";


    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    IF pPrecio = (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'P', pIdProducto, NOW());

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
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
                    "Precios", JSON_OBJECT(
                        'IdPrecio', ps.IdPrecio,
                        'Precio', ps.Precio,
                        'FechaAlta', ps.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Productos p
            INNER JOIN Precios ps ON (ps.Tipo = 'P' AND p.IdProducto = ps.IdReferencia)
			WHERE	p.IdProducto = pIdProducto AND ps.IdPrecio = pIdPrecio
        );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_producto_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_producto_modificar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite modificar un producto. Controla que no exista uno con el mismo nombre y que pertenezca a la misma catgoria y grupo de productos, quue la longitud de tela necesaria
        sea mayor o igual que cero, que existan la categoeria, el grupo y el tipo de producto.
        Devuelve el producto con su precio en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdProducto int;
    DECLARE pIdCategoriaProducto tinyint;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pIdTipoProducto char(1);
    DECLARE pProducto varchar(80);
    DECLARE pLongitudTela decimal(10,2);
    DECLARE pObservaciones varchar(255);
    
    -- Precio
    DECLARE pPrecios JSON;
    DECLARE pIdPrecio int;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pIdProducto = pProductos ->> "$.IdProducto";
    SET pProducto = pProductos ->> "$.Producto";
    SET pIdCategoriaProducto = pProductos ->> "$.IdCategoriaProducto";
    SET pIdGrupoProducto = pProductos ->> "$.IdGrupoProducto";
    SET pIdTipoProducto = pProductos ->> "$.IdTipoProducto";
    SET pLongitudTela = pProductos ->> "$.LongitudTela";
    SET pObservaciones = pProductos ->> "$.Observaciones";

    IF pIdProducto IS NULL OR NOT EXISTS (SELECT IdProducto FROM Productos WHERE IdProducto = pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pProducto IS NULL OR pProducto = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdCategoriaProducto IS NULL OR NOT EXISTS (SELECT IdCategoriaProducto FROM CategoriasProducto WHERE IdCategoriaProducto = pIdCategoriaProducto) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CATEGORIAPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdGrupoProducto IS NULL OR NOT EXISTS (SELECT IdGrupoProducto FROM GruposProducto WHERE IdGrupoProducto = pIdGrupoProducto AND Estado = 'A')) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_GRUPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProducto FROM Productos WHERE Producto = pProducto AND IdCategoriaProducto = pIdCategoriaProducto AND IdGrupoProducto = pIdGrupoProducto AND IdProducto <> pIdProducto) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pLongitudTela < 0 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDA_LONGITUDTELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdTipoProducto FROM TiposProducto WHERE IdTipoProducto = pIdTipoProducto) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPOPRODUCTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";


    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;

    START TRANSACTION;

    IF pPrecio <> (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        -- Verificamos que tenga permiso para modificar el precio
        CALL zsp_usuario_tiene_permiso(pToken, 'zsp_producto_modificar_precio', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;

        INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'P', pIdProducto, NOW());

        SELECT f_dameUltimoPrecio('P', pIdProducto) INTO pIdPrecio;
    END IF;

    
    UPDATE Productos
    SET IdCategoriaProducto = pIdCategoriaProducto,
        IdGrupoProducto = pIdGrupoProducto,
        IdTipoProducto = pIdTipoProducto,
        Producto = pProducto,
        LongitudTela = pLongitudTela,
        Observaciones = NULLIF(pObservaciones, '')
    WHERE IdProducto = pIdProducto;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
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
                    "Precios", JSON_OBJECT(
                        'IdPrecio', ps.IdPrecio,
                        'Precio', ps.Precio,
                        'FechaAlta', ps.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Productos p
            INNER JOIN Precios ps ON (ps.Tipo = 'P' AND ps.IdReferencia = pIdPrecio)
			WHERE	p.IdProducto = pIdProducto
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_productos_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_productos_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar un producto por su nombre, Tipo de Producto (T: Todos), Categoria de Productos (0: Todos), Grupo de Productos (0 : Todos), Estado (A:Activo - B:Baja - T:Todos).
        Devuelve una lista de productos en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Producto a crear
    DECLARE pProductos JSON;
    DECLARE pIdCategoriaProducto tinyint;
    DECLARE pIdGrupoProducto tinyint;
    DECLARE pIdTipoProducto char(1);
    DECLARE pProducto varchar(80);
    DECLARE pEstado char(1);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_productos_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos del Producto
    SET pProductos = pIn ->> "$.Productos";
    SET pProducto = pProductos ->> "$.Producto";
    SET pIdCategoriaProducto = pProductos ->> "$.IdCategoriaProducto";
    SET pIdGrupoProducto = pProductos ->> "$.IdGrupoProducto";
    SET pIdTipoProducto = pProductos ->> "$.IdTipoProducto";
    SET pEstado = pProductos ->> "$.Estado";

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    IF pIdTipoProducto IS NULL OR pIdTipoProducto = '' THEN
		SET pIdTipoProducto = 'T';
	END IF;

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    SET pProducto = COALESCE(pProducto, '');
    SET pIdCategoriaProducto = COALESCE(pIdCategoriaProducto, 0);
    SET pIdGrupoProducto = COALESCE(pIdGrupoProducto, 0);

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_Productos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    -- Resultset completo
    CREATE TEMPORARY TABLE tmp_Productos
    AS SELECT p.*, gp.Grupo AS Grupo, gp.Estado AS gpEstado, cp.Categoria AS Categoria, tp.TipoProducto AS TipoProducto
    FROM Productos p
    INNER JOIN GruposProducto gp ON (gp.IdGrupoProducto = p.IdGrupoProducto)
    INNER JOIN TiposProducto tp ON (p.IdTipoProducto = tp.IdTipoProducto)
    INNER JOIN CategoriasProducto cp ON (cp.IdCategoriaProducto = p.IdCategoriaProducto)
	WHERE	
        Producto LIKE CONCAT(pProducto, '%') AND
        (p.Estado = pEstado OR pEstado = 'T') AND
        (p.IdTipoProducto = pIdTipoProducto OR pIdTipoProducto = 'T') AND
        (p.IdCategoriaProducto = pIdCategoriaProducto OR pIdCategoriaProducto = 0) AND
        (p.IdGrupoProducto = pIdGrupoProducto OR pIdGrupoProducto = 0)
	ORDER BY Producto;

    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_Productos);

    -- Resultset paginado
    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * 
    FROM tmp_Productos
    LIMIT pOffset, pLongitudPagina;


    CREATE TEMPORARY TABLE tmp_preciosProductos AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'P' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPrecios AS
    SELECT pr.* 
    FROM tmp_preciosProductos tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);

    SET pRespuesta = (SELECT 
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", 
                JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "Productos",
                            JSON_OBJECT(
                                'IdProducto', tp.IdProducto,
                                'IdCategoriaProducto', tp.IdCategoriaProducto,
                                'IdGrupoProducto', tp.IdGrupoProducto,
                                'IdTipoProducto', tp.IdTipoProducto,
                                'Producto', tp.Producto,
                                'LongitudTela', tp.LongitudTela,
                                'FechaAlta', tp.FechaAlta,
                                'FechaBaja', tp.FechaBaja,
                                'Observaciones', tp.Observaciones,
                                'Estado', tp.Estado
                            ),
                        "GruposProducto", 
                            JSON_OBJECT(
                                'IdGrupoProducto', tp.IdGrupoProducto,
                                'Grupo', tp.Grupo,
                                'Estado', tp.gpEstado
                            ),
                        "CategoriasProducto", 
                            JSON_OBJECT(
                                'IdCategoriaProducto', tp.IdCategoriaProducto,
                                'Categoria', tp.Categoria
                            ),
                        "TiposProducto", 
                            JSON_OBJECT(
                                'IdTipoProducto', tp.IdTipoProducto,
                                'TipoProducto', tp.TipoProducto
                            ),
                        "Precios", 
                            JSON_OBJECT(
                                'IdPrecio', tps.IdPrecio,
                                'Precio', tps.Precio,
                                'FechaAlta', tps.FechaAlta
                            )
                    )
                )
        )
	FROM tmp_ResultadosFinal tp
    INNER JOIN tmp_ultimosPrecios tps ON (tps.Tipo = 'P' AND tp.IdProducto = tps.IdReferencia)
	);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_Productos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosProductos;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_provincias_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_provincias_listar`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que devuelve una lista de provincias de un pais.
        Devuelve un JSON con las provincias
    
    */

    DECLARE pRespuesta JSON;
    DECLARE pPaises JSON;
    DECLARE pIdPais char(2);

    SET pPaises = pIn ->>"$.Paises";
    SET pIdPais = pPaises ->>"$.IdPais";


    SET pRespuesta = (SELECT JSON_ARRAYAGG(
        JSON_OBJECT(
            "Provincias",
            JSON_OBJECT(
                'IdProvincia', IdProvincia,
                'Provincia', Provincia,
                'IdPais', IdPais
            )
        )
    ) 
    FROM Provincias 
    WHERE IdPais = pIdPais
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remito_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar un remito que esta en estado 'En Creacion'
        Devuelve NULL en 'respuesta' o el error en 'error'
    */
    DECLARE pIdRemito int;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET @pEstado = (SELECT Estado FROM Remitos WHERE IdRemito = pIdRemito);

    IF (SELECT FechaEntrega FROM Remitos WHERE IdRemito = pIdRemito) IS NOT NULL OR @pEstado = 'B' THEN
        SELECT f_generarRespuesta("ERROR_BORRAR_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdReferencia = pIdRemito AND Tipo = 'R') THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_LINEAREMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE
        FROM Remitos
        WHERE IdRemito = pIdRemito;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remito_cancelar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_cancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite cancelar un remito. Controla que se encuentre creado.
        En caso de exito devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_cancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'C' AND FechaEntrega IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_NOCREADO_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Remitos
        SET Estado = 'B'
        WHERE IdRemito = pIdRemito;

        SET pRespuesta = (
			SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    'IdRemito', IdRemito,
                    'IdUbicacion', IdUbicacion,
                    'IdUsuario', IdUsuario,
                    'Tipo', Tipo,
                    'FechaEntrega', FechaEntrega,
                    'FechaAlta', FechaAlta,
                    'Observaciones', Observaciones,
                    'Estado', Estado
                ) 
            )
			FROM	Remitos
			WHERE	IdRemito = pIdRemito
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remito_crear;
DELIMITER $$
CREATE PROCEDURE zsp_remito_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite dar de alta un nuevo remito. Se crea en estado 'En Creacion'.
        Devuelve el remito creado en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdUbicacion tinyint;
    DECLARE pTipo char(1);
    DECLARE pObservaciones varchar(255);

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
  
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdUbicacion = COALESCE(pIn->>'$.Remitos.IdUbicacion', 0);
    SET pTipo = COALESCE(pIn->>'$.Remitos.Tipo', '');
    SET pObservaciones = pIn->>'$.Domicilios.Observaciones';

    IF pTipo IN ('E', 'X') AND NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pTipo NOT IN('E','S','X', 'Y') THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_TIPO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, NULLIF(pIdUbicacion, 0), pIdUsuarioEjecuta, pTipo, NULL, NOW(), NULLIF(pObservaciones, ''), 'E');

        SET pRespuesta = (
			SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    'IdRemito', r.IdRemito,
                    'IdUbicacion', r.IdUbicacion,
                    'IdUsuario', r.IdUsuario,
                    'Tipo', r.Tipo,
                    'FechaEntrega', r.FechaEntrega,
                    'FechaAlta', r.FechaAlta,
                    'Observaciones', r.Observaciones,
                    'Estado', r.Estado
                ),
                'Ubicaciones', IF(r.IdUbicacion IS NOT NULL,
                 JSON_OBJECT(
                    'IdUbicacion', u.IdUbicacion,
                    'Ubicacion', u.Ubicacion
                 ), 
                 NULL)
            )
			FROM	Remitos r
            LEFT JOIN Ubicaciones u ON u.IdUbicacion = r.IdUbicacion
			WHERE	IdRemito = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remito_dame;
DELIMITER $$
CREATE PROCEDURE zsp_remito_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instanciar un remito a partir de su Id.
        Devuelve el remito en "respuesta" o el error en "errorr.
    */
    DECLARE pIdRemito int;
    DECLARE pRespuesta JSON;
    DECLARE pExtra JSON;
    

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, "zsp_remito_dame", pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != "OK" THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>"$.Remitos.IdRemito", 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_REMITO_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT lpp.IdLineaProducto FROM LineasProducto lp INNER JOIN LineasProducto lpp ON lp.IdLineaProductoPadre = lpp.IdLineaProducto WHERE lp.IdReferencia = pIdRemito AND lp.Tipo = "R" AND lpp.Tipo = "V") THEN
        SET pExtra = (
            SELECT JSON_OBJECT(
                "Ventas",  JSON_OBJECT(
                    "IdVenta", v.IdVenta,
                    "IdCliente", v.IdCliente,
                    "IdDomicilio", v.IdDomicilio,
                    "IdUbicacion", v.IdUbicacion,
                    "IdUsuario", v.IdUsuario,
                    "FechaAlta", v.FechaAlta,
                    "Observaciones", v.Observaciones,
                    "Estado", f_calcularEstadoVenta(v.IdVenta)
                ),
                "Clientes", JSON_OBJECT(
                    "Nombres", c.Nombres,
                    "Apellidos", c.Apellidos,
                    "RazonSocial", c.RazonSocial
                ),
                "Domicilios", JSON_OBJECT(
                    "Domicilio", d.Domicilio
                )
            )
            FROM LineasProducto lp
            INNER JOIN LineasProducto lpp ON lpp.IdLineaProducto = lp.IdLineaProductoPadre
            INNER JOIN Ventas v ON lpp.IdReferencia = v.IdVenta
            INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
            LEFT JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
            WHERE lp.IdReferencia = pIdRemito AND lp.Tipo = "R" AND lpp.Tipo = "V"
        );
    END IF;

    SET pRespuesta = (
        SELECT JSON_OBJECT(
            "Remitos",  JSON_OBJECT(
                "IdRemito", r.IdRemito,
                "IdUbicacion", r.IdUbicacion,
                "IdUsuario", r.IdUsuario,
                "Tipo", r.Tipo,
                "FechaEntrega", r.FechaEntrega,
                "FechaAlta", r.FechaAlta,
                "Observaciones", r.Observaciones,
                "Estado", f_calcularEstadoRemito(r.IdRemito),
                "_Extra", pExtra
            ),
            "Usuarios", JSON_OBJECT(
                "Nombres", u.Nombres,
                "Apellidos", u.Apellidos
            ),
            "Ubicaciones", JSON_OBJECT(
                "Ubicacion", ue.Ubicacion
            ),
            "LineasRemito", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "IdUbicacion", lp.IdUbicacion,
                        "Estado", lp.Estado
                    ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Ubicaciones", JSON_OBJECT(
                        "Ubicacion", us.Ubicacion
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            ), JSON_ARRAY())
        )
        FROM Remitos r
        INNER JOIN Usuarios u ON u.IdUsuario = r.IdUsuario
        LEFT JOIN Ubicaciones ue ON ue.IdUbicacion = r.IdUbicacion
        LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = "R"
        LEFT JOIN Ubicaciones us ON lp.IdUbicacion = us.IdUbicacion
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	r.IdRemito = pIdRemito
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remito_descancelar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_descancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite descancelar un remito. Controla que se encuentre cancelado.
        En caso de exito devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_descancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'B') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Remitos
        SET Estado = 'C'
        WHERE IdRemito = pIdRemito;

        SET pRespuesta = (
			SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    'IdRemito', IdRemito,
                    'IdUbicacion', IdUbicacion,
                    'IdUsuario', IdUsuario,
                    'Tipo', Tipo,
                    'FechaEntrega', FechaEntrega,
                    'FechaAlta', FechaAlta,
                    'Observaciones', Observaciones,
                    'Estado', Estado
                ) 
            )
			FROM	Remitos
			WHERE	IdRemito = pIdRemito
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remito_entregar;
DELIMITER $$
CREATE PROCEDURE zsp_remito_entregar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite entregar un remito. Controla que tenga lineas y setea la fecha de entrega en caso de recibirla.
        Devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;
    DECLARE pFechaEntrega datetime;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    DECLARE pExtra JSON;

    DECLARE pIdVenta INT;
    DECLARE pPrecioTotal DECIMAL(10,2);

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_entregar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);
    SET pFechaEntrega = COALESCE(pIn->>'$.Remitos.FechaEntrega', NOW());

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdReferencia = pIdRemito AND Tipo = 'R') THEN
        SELECT f_generarRespuesta("ERROR_SINLINEAS_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'C' AND FechaEntrega IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_NOCREADO_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT lv.IdReferencia, (lv.Cantidad * lv.PrecioUnitario) INTO pIdVenta, pPrecioTotal
    FROM Remitos r 
    INNER JOIN LineasProducto lr ON lr.IdReferencia = r.IdRemito AND lr.Tipo = 'R'
    INNER JOIN LineasProducto lv ON lv.IdLineaProducto = lr.IdLineaProductoPadre AND lv.Tipo = 'V'
    WHERE r.IdRemito = pIdRemito;

    START TRANSACTION;
        IF COALESCE(pIdVenta, 0) != 0 THEN
            IF f_dameCreditoAFavor(pIdVenta) < pPrecioTotal THEN
                SELECT f_generarRespuesta("ERROR_CREDITO_INSUFICIENTE", NULL) pOut;
                LEAVE SALIR;
            END IF;
        END IF;

        UPDATE Remitos
        SET FechaEntrega = pFechaEntrega
        WHERE IdRemito = pIdRemito;

        IF EXISTS(SELECT lpp.IdLineaProducto FROM LineasProducto lp INNER JOIN LineasProducto lpp ON lp.IdLineaProductoPadre = lpp.IdLineaProducto WHERE lp.IdReferencia = pIdRemito AND lp.Tipo = "R" AND lpp.Tipo = "V") THEN
            SET pExtra = (
                SELECT JSON_OBJECT(
                    "Ventas",  JSON_OBJECT(
                        "IdVenta", v.IdVenta,
                        "IdCliente", v.IdCliente,
                        "IdDomicilio", v.IdDomicilio,
                        "IdUbicacion", v.IdUbicacion,
                        "IdUsuario", v.IdUsuario,
                        "FechaAlta", v.FechaAlta,
                        "Observaciones", v.Observaciones,
                        "Estado", f_calcularEstadoVenta(v.IdVenta)
                    ),
                    "Clientes", JSON_OBJECT(
                        "Nombres", c.Nombres,
                        "Apellidos", c.Apellidos,
                        "RazonSocial", c.RazonSocial
                    ),
                    "Domicilios", JSON_OBJECT(
                        "Domicilio", d.Domicilio
                    )
                )
                FROM LineasProducto lp
                INNER JOIN LineasProducto lpp ON lpp.IdLineaProducto = lp.IdLineaProductoPadre
                INNER JOIN Ventas v ON lpp.IdReferencia = v.IdVenta
                INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
                LEFT JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
                WHERE lp.IdReferencia = pIdRemito AND lp.Tipo = "R" AND lpp.Tipo = "V"
            );
        END IF;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    "IdRemito", r.IdRemito,
                    "IdUbicacion", r.IdUbicacion,
                    "IdUsuario", r.IdUsuario,
                    "Tipo", r.Tipo,
                    "FechaEntrega", r.FechaEntrega,
                    "FechaAlta", r.FechaAlta,
                    "Observaciones", r.Observaciones,
                    "Estado", f_calcularEstadoRemito(r.IdRemito),
                    "_Extra", pExtra
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ue.Ubicacion
                ),
                "LineasRemito", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "IdUbicacion", lp.IdUbicacion,
                            "Estado", lp.Estado
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Ubicaciones", JSON_OBJECT(
                            "Ubicacion", us.Ubicacion
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            )
            FROM Remitos r
            INNER JOIN Usuarios u ON u.IdUsuario = r.IdUsuario
            LEFT JOIN Ubicaciones ue ON ue.IdUbicacion = r.IdUbicacion
            LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = "R"
            LEFT JOIN Ubicaciones us ON lp.IdUbicacion = us.IdUbicacion
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	r.IdRemito = pIdRemito
        );

        SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    
    COMMIT;  
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remito_pasar_a_creado;
DELIMITER $$
CREATE PROCEDURE zsp_remito_pasar_a_creado(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento quer permite pasar un remito a 'Creado'.
        Controla que este en estado 'En Creacion' y que tenga al menos una linea de remito.
        Devuelve el remito en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdRemito int;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_remito_pasar_a_creado', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdRemito = COALESCE(pIn->>'$.Remitos.IdRemito', 0);

    IF NOT EXISTS(SELECT IdRemito FROM Remitos WHERE IdRemito = pIdRemito AND Estado = 'E') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdReferencia = pIdRemito AND Tipo = 'R') THEN
        SELECT f_generarRespuesta("ERROR_SINLINEAS_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
        UPDATE Remitos
        SET Estado = 'C'
        WHERE IdRemito = pIdRemito;

        SET pRespuesta = (
			SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    'IdRemito', IdRemito,
                    'IdUbicacion', IdUbicacion,
                    'IdUsuario', IdUsuario,
                    'Tipo', Tipo,
                    'FechaEntrega', FechaEntrega,
                    'FechaAlta', FechaAlta,
                    'Observaciones', Observaciones,
                    'Estado', Estado
                ) 
            )
			FROM	Remitos
			WHERE	IdRemito = pIdRemito
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_remitos_buscar;
DELIMITER $$
CREATE PROCEDURE zsp_remitos_buscar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite buscar remitos.
        Se pueden buscarlo a partir:
            -Rango de fechas en el cual fue creado
            -Ubicacion de entrada o salida del remito (0:Todas)
            -Rango de fecha en el que fue entregado
            -Estado del remito (E:"En Creacion", C:"Creado", N:"Cancelado", F:"Entregado", T:Todos)
            -Tipo de remito (E:"Entrada", S:"Salida", X:"Transformación Entrada", Y:"Transformación Salida", T:Todos)
            -Usuario que lo creo(0:Todos)
    */
    DECLARE pIdUbicacionEntrada tinyint;
    DECLARE pIdUsuario int;
    DECLARE pTipo char(1);
    DECLARE pEstado char(1);

    -- Lineas de remito
    DECLARE pIdUbicacionSalida tinyint;

    -- Producto final
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;

    -- Paginacion
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    -- Parametros busqueda
    DECLARE pParametrosBusqueda JSON;
    DECLARE pFechaEntregaDesde date;
    DECLARE pFechaEntregaHasta date;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, "zsp_remitos_buscar", pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != "OK" THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdUsuario = COALESCE(pIn->>"$.Remitos.IdUsuario", 0);

    IF pIdUsuario != pIdUsuarioEjecuta THEN
        CALL zsp_usuario_tiene_permiso(pToken, "remitos_buscar_ajeno", pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != "OK" THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SET pTipo = COALESCE(pIn->>"$.Remitos.Tipo", "T");
    SET pEstado = COALESCE(pIn->>"$.Remitos.Estado", "T");
    SET pIdUbicacionEntrada = COALESCE(pIn->>"$.Remitos.IdUbicacion", 0);
    SET pIdUbicacionSalida = COALESCE(pIn->>"$.LineasProducto.IdUbicacion", 0);

    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaEntregaDesde", "")) > 0 THEN
        SET pFechaEntregaDesde = pIn ->> "$.ParametrosBusqueda.FechaEntregaDesde";
    END IF;
    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaEntregaHasta", "")) = 0 THEN
        SET pFechaEntregaHasta = NOW();
    ELSE
        SET pFechaEntregaHasta = pIn ->> "$.ParametrosBusqueda.FechaEntregaHasta";
    END IF;


    SET pIdProducto = COALESCE(pIn->>"$.ProductosFinales.IdProducto", 0);
    SET pIdLustre = COALESCE(pIn->>"$.ProductosFinales.IdLustre", 0);
    SET pIdTela = COALESCE(pIn->>"$.ProductosFinales.IdTela", 0);

    SET pPagina = COALESCE(pIn ->> "$.Paginaciones.Pagina", 1);
    SET pLongitudPagina = COALESCE(pIn ->> "$.Paginaciones.LongitudPagina", (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = "LONGITUDPAGINA"));

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultadosSinPaginar;
    DROP TEMPORARY TABLE IF EXISTS  tmp_resultadosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmpp_resultadoFinal;

    CREATE TEMPORARY TABLE tmp_resultadosSinPaginar
    AS SELECT DISTINCT(r.IdRemito)
    FROM Remitos r
    LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = "R"
    LEFT JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
    WHERE
        (r.IdUbicacion = pIdUbicacionEntrada OR pIdUbicacionEntrada = 0)
        AND (r.Tipo = pTipo OR pTipo = "T")
        AND (f_calcularEstadoRemito(r.IdRemito) = pEstado OR pEstado = "T")
        AND (r.IdUsuario = pIdUsuario OR pIdUsuario = 0)
        -- AND ((pFechaEntregaDesde IS NULL AND r.FechaEntrega <= pFechaEntregaHasta) OR (pFechaEntregaDesde IS NOT NULL AND r.FechaEntrega BETWEEN pFechaEntregaDesde AND pFechaEntregaHasta)) 
        AND (lp.IdUbicacion = pIdUbicacionSalida OR pIdUbicacionSalida = 0)
        AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
        AND (pf.IdTela = pIdTela OR pIdTela = 0)
        AND (pf.IdLustre = pIdLustre OR pIdLustre = 0)
    ORDER BY r.IdRemito DESC;

    SET pCantidadTotal = COALESCE((SELECT COUNT(DISTINCT IdRemito) FROM tmp_resultadosSinPaginar), 0);

    CREATE TEMPORARY TABLE tmp_resultadosPaginados
    AS SELECT IdRemito
    FROM tmp_resultadosSinPaginar
    LIMIT pOffset, pLongitudPagina;

    CREATE TEMPORARY TABLE  tmpp_resultadoFinal
    AS SELECT
        tmpp.IdRemito,
        IF(COUNT(lp.IdLineaProducto) > 0, 
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario
                    ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Ubicaciones", JSON_OBJECT(
                        "Ubicacion", u.Ubicacion
                    ),
                    "Productos", JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                )
		    ), NULL
        ) AS LineasRemito
    FROM    tmp_resultadosPaginados tmpp
    LEFT JOIN LineasProducto lp ON tmpp.IdRemito = lp.IdReferencia AND lp.Tipo = "R"
    LEFT JOIN Ubicaciones u ON u.IdUbicacion = lp.IdUbicacion
    LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
    LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
    LEFT JOIN Telas te ON pf.IdTela = te.IdTela
    LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
    GROUP BY tmpp.IdRemito;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    SET pRespuesta = JSON_OBJECT(
        "Paginaciones", JSON_OBJECT(
            "Pagina", pPagina,
            "LongitudPagina", pLongitudPagina,
            "CantidadTotal", pCantidadTotal
        ),
        "resultado", (
            SELECT CAST(CONCAT("[", COALESCE(GROUP_CONCAT(JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    "IdRemito", r.IdRemito,
                    "IdUbicacion", r.IdUbicacion,
                    "IdUsuario", r.IdUsuario,
                    "Tipo", r.Tipo,
                    "FechaEntrega", r.FechaEntrega,
                    "FechaAlta", r.FechaAlta,
                    "Observaciones", r.Observaciones,
                    "Estado", f_calcularEstadoRemito(r.IdRemito)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasRemito", tmpp.LineasRemito
            )ORDER BY r.FechaAlta DESC),""), "]") AS JSON)
            FROM tmpp_resultadoFinal tmpp
            INNER JOIN Remitos r ON r.IdRemito = tmpp.IdRemito
            INNER JOIN Usuarios u ON r.IdUsuario = u.IdUsuario
            LEFT JOIN Ubicaciones ub ON r.IdUbicacion = ub.IdUbicacion
            ORDER BY r.FechaAlta DESC
        )    
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_resultadosSinPaginar;
    DROP TEMPORARY TABLE IF EXISTS  tmp_resultadosPaginados;
    DROP TEMPORARY TABLE IF EXISTS tmpp_resultadoFinal;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_rol_asignar_permisos`;
DELIMITER $$
CREATE  PROCEDURE `zsp_rol_asignar_permisos`(pIn JSON)

SALIR: BEGIN
	/*
		Dado el rol y una cadena formada por la lista de los IdPermisos separados por comas, asigna los permisos seleccionados como dados y quita los no dados.
		Cambia el token de los usuarios del rol así deban reiniciar sesión y retomar permisos.
		Devuelve null en 'respuesta' o el codigo de error en 'error'.
	*/	
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pNumero varchar(11);
	DECLARE pMensaje text;
	DECLARE pRoles, pPermisos, pUsuariosEjecuta JSON;
	DECLARE pIdRol int;
	DECLARE pToken varchar(256);

	/*Para el While*/
	DECLARE i INT DEFAULT 0;
	DECLARE pPermiso JSON;
	DECLARE pIdPermiso smallint;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SHOW ERRORS;
		SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> '$.Roles';
	SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
	SET pPermisos = pIn ->> '$.Permisos';

    SET pIdRol = pRoles ->> '$.IdRol';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
	
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_asignar_permisos', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje != 'OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol)THEN
		SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    START TRANSACTION;
		DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
        CREATE TEMPORARY TABLE tmp_permisosrol ENGINE = MEMORY AS
        SELECT * FROM PermisosRol WHERE IdRol = pIdRol;
		
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;

		WHILE i < JSON_LENGTH(pPermisos) DO
			SELECT JSON_EXTRACT(pPermisos,CONCAT('$[',i,']')) INTO pPermiso;
			SET pIdPermiso = pPermiso ->> '$.IdPermiso';
			IF NOT EXISTS(SELECT IdPermiso FROM Permisos WHERE IdPermiso = pIdPermiso)THEN
				SELECT f_generarRespuesta('ERROR_NOEXISTE_PERMISO_LISTA', NULL) pOut;
                ROLLBACK;
                LEAVE SALIR;
            END IF;
            INSERT INTO PermisosRol VALUES(pIdPermiso, pIdRol);
			SELECT i + 1 INTO i;
		END WHILE;

        IF EXISTS(SELECT IdPermiso
			FROM
			(SELECT IdPermiso
			FROM tmp_permisosrol
			UNION ALL
			SELECT IdPermiso
			FROM PermisosRol
			WHERE IdRol = pIdRol) p
			GROUP BY IdPermiso
			HAVING COUNT(IdPermiso) = 1) THEN /*Si existen cambios, es decir existe un nuevo tipo de permiso respecto a la tabla original (tmp_permisosrol) => Reseteamos token.*/
                UPDATE Usuarios SET Token = md5(CONCAT(CONVERT(IdUsuario,char(10)),UNIX_TIMESTAMP())) WHERE IdRol = pIdRol;
		END IF;
		SELECT f_generarRespuesta(NULL, NULL) pOut;
        DROP TEMPORARY TABLE IF EXISTS tmp_permisosrol;
	COMMIT;    
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_borrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_borrar`(pIn JSON)

SALIR: BEGIN
    /*
        Permite borrar un rol controlando que no exista un usuario asociado.
        Devuelve null en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pRoles JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdRol int;
    DECLARE pToken varchar(256);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pIdRol IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INDICAR_ROL', NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdRol FROM Roles WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
	IF EXISTS(SELECT IdRol FROM Usuarios WHERE IdRol = pIdRol) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_ROL_USUARIO', NULL) pOut;
		LEAVE SALIR;
	END IF;
	
    START TRANSACTION;
	
        DELETE FROM PermisosRol WHERE IdRol = pIdRol;
        DELETE FROM Roles WHERE IdRol = pIdRol;
        SELECT f_generarRespuesta(NULL, NULL) pOut;

	COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_crear`(pIn JSON)

SALIR: BEGIN
	/*
		Permite crear un rol controlando que el nombre no exista ya. 
		Devuelve el rol creado en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pRoles JSON;
	DECLARE pUsuarioEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
	DECLARE pIdRol tinyint;
	DECLARE pToken varchar(256);
	DECLARE pRol varchar(40);
	DECLARE pDescripcion varchar(255);
	DECLARE pRespuesta JSON;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> "$.Roles";
	SET pUsuarioEjecuta = pIn ->> "$.UsuariosEjecuta";
	SET pToken = pUsuarioEjecuta ->> "$.Token";
	SET pRol = pRoles ->> "$.Rol";
	SET pDescripcion = pRoles ->> "$.Descripcion";
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBREROL', NULL) pOut;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_NOMBREROL', NULL) pOut;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;
		
        INSERT INTO Roles VALUES (DEFAULT, pRol, NOW(), NULLIF(pDescripcion,''));
		SET pIdRol = (SELECT IdRol FROM Roles WHERE Rol = pRol);
		SET pRespuesta = (SELECT (CAST(
			COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
						)
					,'')
			AS JSON)) FROM Roles WHERE Rol = pRol);
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) AS pOut;
	COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_rol_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_dame`(pIn JSON)

SALIR: BEGIN
    /*
        Procedimiento que sirve para instanciar un rol desde la base de datos. Devuelve el objeto en 'respuesta' o un error en 'error'.
    */
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';

	SET pRespuesta = (
        SELECT CAST(
				COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
					)
				,'') AS JSON)
        FROM	Roles
        WHERE	IdRol = pIdRol
    );

    SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_roles_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_roles_listar`()

BEGIN
	/*
		Lista todos los roles existentes. Ordena por Rol. Devuelve la lista de roles en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pOut JSON;
    DECLARE pRespuesta TEXT;


    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT("Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol, 
                        'Rol', Rol,
                        'FechaAlta', FechaAlta,
                        'Descripcion', Descripcion
                    )
                )
            ),'')
	FROM Roles
    ORDER BY Rol);
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_rol_listar_permisos`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_listar_permisos`(pIn JSON)

BEGIN
	/*
		Lista todos los permisos existentes para un rol y devuelve la lista de permisos en 'respuesta' o el codigo de error en 'error'.
	*/
    DECLARE pRoles JSON;
    DECLARE pIdRol int;
    DECLARE pRespuesta JSON;

    SET pRoles = pIn ->> '$.Roles';
    SET pIdRol = pRoles ->> '$.IdRol';



    SET pRespuesta = (SELECT 
            JSON_ARRAYAGG(
                JSON_OBJECT('Permisos',
                    JSON_OBJECT(
                        'IdPermiso', p.IdPermiso, 
                        'Permiso', Permiso,
                        'Procedimiento', Procedimiento,
                        'Descripcion', Descripcion
                    )
                )
            )
	FROM Permisos p 
    INNER JOIN PermisosRol pr ON p.IdPermiso = pr.IdPermiso
    WHERE pr.IdRol = pIdRol
    ORDER BY Procedimiento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_rol_modificar`;
DELIMITER $$
CREATE PROCEDURE `zsp_rol_modificar`(pIn JSON)

SALIR: BEGIN
	/*
		Permite modificar un rol controlando que el nombre no exista ya. 
		Devuelve el rol modifica en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pRoles JSON;
	DECLARE pUsuarioEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
	DECLARE pIdRol tinyint;
	DECLARE pToken varchar(256);
	DECLARE pRol varchar(40);
	DECLARE pDescripcion varchar(255);
	DECLARE pRespuesta JSON;

	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

	SET pRoles = pIn ->> "$.Roles";
	SET pUsuarioEjecuta = pIn ->> "$.UsuariosEjecuta";
	SET pToken = pUsuarioEjecuta ->> "$.Token";
    SET pIdRol = pRoles ->> "$.IdRol";
	SET pRol = pRoles ->> "$.Rol";
	SET pDescripcion = pRoles ->> "$.Descripcion";
    
	CALL zsp_usuario_tiene_permiso(pToken, 'zsp_rol_crear', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;
    
	IF (pRol IS NULL OR pRol = '') THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBREROL', NULL) pOut;
        LEAVE SALIR;
	END IF;
    
    IF EXISTS(SELECT Rol FROM Roles WHERE Rol = pRol AND IdRol != pIdRol) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_NOMBREROL', NULL) pOut;
		LEAVE SALIR;
	END IF;	

    START TRANSACTION;
		
        UPDATE Roles 
        SET Rol = pRol,
            Descripcion = NULLIF(pDescripcion,'')
        WHERE IdRol = pIdRol;
        
		SET pRespuesta = (SELECT (CAST(
			COALESCE(
					JSON_OBJECT(
						'IdRol', IdRol, 
						'Rol', Rol,
						'FechaAlta', FechaAlta,
						'Descripcion', Descripcion
						)
					,'')
			AS JSON)) FROM Roles WHERE IdRol = pIdRol);
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Roles", pRespuesta)) AS pOut;
	COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_sesion_cerrar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_cerrar`(pIn JSON)

SALIR: BEGIN
    /*
        Permite cerrar la sesion de un usuario a partir de su Id.
        Devuelve OK o el mensaje de error en Mensaje.
    */
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pIdUsuario smallint;
    DECLARE pUsuarios, pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    SET pIdUsuario = pUsuarios ->> '$.IdUsuario';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_sesion_cerrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF pIdUsuario IS NULL THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_USUARIO', NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL) pOut;
        LEAVE SALIR;
    END IF;
	
    START TRANSACTION;
        UPDATE Usuarios
        SET Token = ''
        WHERE IdUsuario = pIdusuario;
        SELECT f_generarRespuesta(NULL, NULL) pOut;
	COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_sesion_iniciar`;
DELIMITER $$
CREATE PROCEDURE `zsp_sesion_iniciar`(pIn JSON)

SALIR: BEGIN
	/*
		Procedimiento que permite a un usuario iniciar sesion en ZMGestion.
        Devuelve el usuario que ha iniciado sesion en pOut o el codigo de error en caso de error.
	*/
    DECLARE pIdUsuario smallint;
    DECLARE pTIEMPOINTENTOS, pMAXINTPASS, pIntentos int;
    DECLARE pFechaUltIntento datetime;
    DECLARE pUsuarios JSON;
    DECLARE pPass VARCHAR(255);
    DECLARE pUsuario VARCHAR(40);
    DECLARE pEmail VARCHAR(120);
    DECLARE pToken VARCHAR(256);

    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pToken = COALESCE(pUsuarios ->> '$.Token', ''); 

    IF pToken = '' THEN
        SELECT f_generarRespuesta('ERROR_TRANSACCION', NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pUsuario = COALESCE(pUsuarios ->> '$.Usuario', '');
    SET pEmail = COALESCE(pUsuarios ->> '$.Email', '');
    SET pPass = COALESCE(pUsuarios ->> '$.Password', ''); 


    SET pTIEMPOINTENTOS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='TIEMPOINTENTOS');
    SET pMAXINTPASS = (SELECT CONVERT(Valor, UNSIGNED) FROM Empresa WHERE Parametro='MAXINTPASS');

    IF pUsuario = '' AND pEmail = '' THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Control porque no se puede enviar usuario y correo electronico. Debe ser uno de los dos
    IF pUsuario <> '' AND pEmail <> '' THEN
        SELECT f_generarRespuesta('ERROR_INGRESE_USUARIOEMAIL', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pEmail <> '' THEN
        IF(NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail)) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
		ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        END IF;
    ELSE
        IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario) THEN
            SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            LEAVE SALIR;
        ELSE
			SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Usuario = pUsuario);
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario AND Estado = 'A') THEN
        SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        SET pIntentos = (SELECT Intentos FROM Usuarios WHERE IdUsuario = pIdUsuario);
        SET pFechaUltIntento = (SELECT FechaUltIntento FROM Usuarios WHERE IdUsuario = pIdUsuario);

        IF DATE_ADD(pFechaUltIntento, INTERVAL pTIEMPOINTENTOS MINUTE) < NOW() THEN
            SET pIntentos = 0;
            -- SELECT pTIEMPOINTENTOS Mensaje;
        END IF;

        IF NOT EXISTS (SELECT Estado FROM Usuarios WHERE `Password` = pPass AND ESTADO = 'A' AND IdUsuario = pIdUsuario) THEN
            IF (pIntentos + 1) >= pMAXINTPASS THEN
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW(),
                    Estado = 'B'
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_BLOQUEADO', NULL) pOut;
            ELSE
                UPDATE Usuarios
                SET Intentos = (pIntentos + 1),
                    FechaUltIntento = NOW()
                WHERE IdUsuario = pIdUsuario;
                COMMIT;
                SELECT f_generarRespuesta('ERROR_LOGIN_INCORRECTO', NULL) pOut;
            END IF;
            LEAVE SALIR;
        ELSE
            UPDATE Usuarios
            SET Token = pToken,
                FechaUltIntento = NOW(),
                Intentos = 0
            WHERE IdUsuario = pIdUsuario;

            SET pUsuarios = (
                SELECT CAST(
                        COALESCE(
                            JSON_OBJECT(
                                'IdUsuario', IdUsuario, 
                                'IdRol', IdRol,
                                'IdUbicacion', IdUbicacion,
                                'IdTipoDocumento', IdTipoDocumento,
                                'Documento', Documento,
                                'Nombres', Nombres,
                                'Apellidos', Apellidos,
                                'EstadoCivil', EstadoCivil,
                                'Telefono', Telefono,
                                'Email', Email,
                                'CantidadHijos', CantidadHijos,
                                'Usuario', Usuario,
                                'Token', Token,
                                'FechaNacimiento', FechaNacimiento,
                                'FechaInicio', FechaInicio,
                                'FechaAlta', FechaAlta,
                                'Estado', Estado
                            )
                        ,'') AS JSON)
                FROM	Usuarios
                WHERE	IdUsuario = pIdUsuario
            );
            SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pUsuarios)) pOut; 
        END IF;        
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_stock_calcular;
DELIMITER $$
CREATE PROCEDURE zsp_stock_calcular(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite conocer el stock de los productos finales.
        Se puede filtrar por producto final, tela, lustre o ubicacion.
        Devuelve una lista de productos finales junto con su cantidad en 'respuesta' o un error en 'error'.
    */
    DECLARE pIdProductoFinal int;
    DECLARE pIdProducto int;
    DECLARE pIdTela smallint;
    DECLARE pIdLustre tinyint;
    DECLARE pIdUbicacion tinyint;

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_stock_calcular', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdProducto = COALESCE(pIn->>'$.ProductosFinales.IdProducto', 0);
    SET pIdTela = COALESCE(pIn->>'$.ProductosFinales.IdTela', 0);
    SET pIdLustre = COALESCE(pIn->>'$.ProductosFinales.IdLustre', 0);
    SET pIdUbicacion = COALESCE(pIn->>'$.Ubicaciones.IdUbicacion', 0);

    SET pIdProductoFinal = COALESCE((SELECT IdProductoFinal FROM ProductosFinales WHERE IdProducto = pIdProducto AND  (IF(pIdTela = 0, IdTela IS NULL, IdTela = pIdTela)) AND (IF(pIdLustre = 0, IdLustre IS NULL, IdLustre = pIdLustre))), 0);

    DROP TEMPORARY TABLE IF EXISTS tmp_stock;

    CREATE TEMPORARY TABLE tmp_stock AS
    SELECT
        IdProductoFinal,
        CASE 
            WHEN pIdUbicacion != 0 THEN r.IdUbicacion
        END,
        SUM(IF(r.Tipo IN ('E', 'X'), lp.Cantidad, -1 * lp.Cantidad)) Total
    FROM Remitos r
    INNER JOIN LineasProducto lp ON lp.IdReferencia = r.IdRemito AND lp.Tipo = 'R'
    INNER JOIN ProductosFinales pf ON pf.IdProductoFinal = lp.IdProductoFinal
    WHERE 
        (lp.IdProductoFinal = pIdProductoFinal OR pIdProductoFinal = 0)
        AND (r.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
    GROUP BY
        IdProductoFinal,
        (CASE 
            WHEN pIdUbicacion != 0 THEN r.IdUbicacion
        END);

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    SET pRespuesta = JSON_OBJECT(
        "resultado", (
            SELECT CAST(CONCAT("[", COALESCE(GROUP_CONCAT(JSON_OBJECT(
                "ProductosFinales",  JSON_OBJECT(
                    "IdProductoFinal", pf.IdProductoFinal,
                    "IdProducto", pf.IdProducto,
                    "IdTela", pf.IdTela,
                    "IdLustre", pf.IdLustre,
                    "__Cantidad", tmp.Total
                ),
                "Productos", JSON_OBJECT(
                    "IdProducto", p.IdProducto,
                    "Producto", p.Producto
                ),
                "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", t.IdTela,
                        "Tela", t.Tela
                    ),NULL),
                "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", l.IdLustre,
                        "Lustre", l.Lustre
                    ), NULL),
                "Ubicaciones", (pIdUbicacion != 0,
                    JSON_OBJECT(
                        "IdUbicacion", u.IdUbicacion,
                        "Ubicacion", u.Ubicacion
                    ), NULL)
            )),""), "]") AS JSON)
            FROM tmp_stock tmp
            INNER JOIN ProductosFinales pf ON pf.IdProductoFinal = tmp.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = p.IdProducto
            LEFT JOIN Telas t ON pf.IdTela = t.IdTela
            LEFT JOIN Lustres l ON pf.IdLustre = l.IdLustre
            LEFT JOIN Ubicaciones u ON u.IdUbicacion = tmp.IdUbicacion
        )    
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_stock;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una tarea.
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_borrar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) NOT IN ('P','C') THEN
        SELECT f_generarRespuesta("ERROR_TAREA_BORRAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTarea FROM Tareas WHERE IdTareaSiguiente = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_TAREA_BORRAR_TAREA_SIGUIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        DELETE FROM Tareas 
        WHERE IdTarea = pIdTarea;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_cancelar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_cancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite cancelar una tarea.
        Pasa la tarea al estado: 'C' - Cancelada
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_cancelar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) NOT IN ('E','S','F') THEN
        SELECT f_generarRespuesta("ERROR_TAREA_CANCELAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaCancelacion = NOW(),
            Estado = 'C'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_crear;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una tarea para una linea de orden de producción
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pTarea VARCHAR(255);
    DECLARE pIdLineaProducto BIGINT;
    DECLARE pIdTareaSiguiente BIGINT;
    DECLARE pIdUsuarioFabricante SMALLINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_crear', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTarea = pIn->>'$.Tareas.Tarea';
    SET pIdLineaProducto = pIn->>'$.Tareas.IdLineaProducto';
    SET pIdTareaSiguiente = pIn->>'$.Tareas.IdTareaSiguiente';
    SET pIdUsuarioFabricante = pIn->>'$.Tareas.IdUsuarioFabricante';

    IF COALESCE(pTarea, '') = '' THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto AND Tipo = 'O') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_LINEA_ORDEN_PRODUCCION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTareaSiguiente IS NOT NULL AND NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTareaSiguiente) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (
        SELECT IdRol 
        FROM Usuarios 
        WHERE 
            IdUsuario = pIdUsuarioFabricante 
            AND IdRol = (SELECT Valor FROM Empresa WHERE Parametro = 'IDROLFABRICANTE')
    ) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_USUARIO_FABRICANTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Tareas (IdTarea, IdLineaProducto, IdTareaSiguiente, IdUsuarioFabricante, Tarea, FechaAlta, Estado)
        VALUES (DEFAULT, pIdLineaProducto, pIdTareaSiguiente, pIdUsuarioFabricante, pTarea, NOW(), 'P');
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_ejecutar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_ejecutar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite iniciar la ejecución de una tarea.
        Pasa la tarea al estado: 'E' - En proceso
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_ejecutar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) != 'P' THEN
        SELECT f_generarRespuesta("ERROR_TAREA_EJECUTAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    /* 
        IF EXISTS (SELECT IdTarea FROM Tareas WHERE IdTareaSiguiente = pIdTarea AND Estado = 'E') THEN
            SELECT f_generarRespuesta("ERROR_TAREA_ANTERIOR_EN_PROCESO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    */

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaInicio = NOW(),
            Estado = 'E'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_finalizar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_finalizar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite finalizar la ejecución de una tarea.
        Pasa la tarea al estado: 'F' - Finalizada
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_finalizar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) != 'E' THEN
        SELECT f_generarRespuesta("ERROR_TAREA_FINALIZAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaFinalizacion = NOW(),
            Estado = 'F'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_pausar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_pausar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite pausar la ejecución de una tarea.
        Pasa la tarea al estado: 'S' - Pausada
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_pausar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) != 'E' THEN
        SELECT f_generarRespuesta("ERROR_TAREA_PAUSAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaPausa = NOW(),
            Estado = 'S'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_reanudar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_reanudar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite reanudar la ejecución de una tarea.
        Pasa la tarea al estado: 'E' - En proceso
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_reanudar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) NOT IN ('S','F','V','C') THEN
        SELECT f_generarRespuesta("ERROR_TAREA_REANUDAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaInicio = NOW(),
            Estado = 'E'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_tareas_verificar;
DELIMITER $$
CREATE PROCEDURE zsp_tareas_verificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite pausar la ejecución de una tarea.
        Pasa la tarea al estado: 'S' - Pausada
    */
    DECLARE pMensaje TEXT;
    DECLARE pRespuesta JSON;

    -- Tareas
    DECLARE pIdTarea BIGINT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    CALL zsp_usuario_tiene_permiso(pIn->>"$.UsuariosEjecuta.Token", 'zsp_tareas_verificar', @pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdTarea = COALESCE(pIn->>'$.Tareas.IdTarea', 0);

    IF NOT EXISTS (SELECT IdTarea FROM Tareas WHERE IdTarea = pIdTarea) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TAREA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Tareas WHERE IdTarea = pIdTarea) != 'F' THEN
        SELECT f_generarRespuesta("ERROR_TAREA_VERIFICAR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Tareas 
        SET 
            FechaRevision = NOW(),
            IdUsuarioRevisor = @pIdUsuarioEjecuta,
            Estado = 'V'
        WHERE IdTarea = pIdTarea;
        
        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Tareas", JSON_OBJECT(
                    'IdTarea', t.IdTarea,
                    'IdLineaProducto', t.IdLineaProducto,
                    'IdTareaSiguiente', t.IdTareaSiguiente,
                    'IdUsuarioFabricante', t.IdUsuarioFabricante,
                    'IdUsuarioRevisor', t.IdUsuarioRevisor,
                    'Tarea', t.Tarea,
                    'FechaInicio', t.FechaInicio,
                    'FechaPausa', t.FechaPausa,
                    'FechaFinalizacion', t.FechaFinalizacion,
                    'FechaRevision', t.FechaRevision,
                    'FechaAlta', t.FechaAlta,
                    'FechaCancelacion', t.FechaCancelacion,
                    'Observaciones', t.Observaciones,
                    'Estado', t.Estado
                ),
                "UsuariosFabricante", JSON_OBJECT(
                    'IdUsuario', uf.IdUsuario,
                    'Nombres', uf.Nombres,
                    'Apellidos', uf.Apellidos,
                    'Estado', uf.Estado
                ),
                "UsuariosRevisor", IF(ur.IdUsuario IS NULL, 
                    NULL, 
                    JSON_OBJECT(
                        'IdUsuario', ur.IdUsuario,
                        'Nombres', ur.Nombres,
                        'Apellidos', ur.Apellidos,
                        'Estado', ur.Estado
                    )
                )
            )
            FROM Tareas t
            INNER JOIN Usuarios uf ON(uf.IdUsuario = t.IdUsuarioFabricante)
            LEFT JOIN Usuarios ur ON(ur.IdUsuario = t.IdUsuarioRevisor)
            WHERE IdTarea = pIdTarea
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT; 
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_borrar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite borrar una tela. Controla que no este siendo utilizada por un ProductoFinal.
        Devuelve null en respuesta o el error en error.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SET SQL_SAFE_UPDATES = 1;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdProductoFinal FROM ProductosFinales WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_PRODUCTOFINAL_TELA", NULL);
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        -- Para poder borrar en la tabla precios
        SET SQL_SAFE_UPDATES = 0;
        DELETE FROM Telas WHERE IdTela = pIdTela;
        DELETE FROM Precios WHERE Tipo = 'T' AND  IdReferencia = pIdTela;

        SELECT f_generarRespuesta(NULL, NULL) pOut;
        SET SQL_SAFE_UPDATES = 1;
    COMMIT;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_crear`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_crear`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una tela. Control que no exista otra tela con el mismo nombre y que el precio sea mayor que cero.
        Devuelve un json con la tela y el precio en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;
    DECLARE pTela varchar(60);
    DECLARE pObservaciones varchar(255);

    -- Precio de la tela
    DECLARE pPrecios JSON;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pTela = pTelas ->> "$.Tela";
    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";

    IF pTela IS NULL OR pTela = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTela FROM Telas WHERE Tela = pTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Telas (IdTela, Tela, FechaAlta, FechaBaja, Observaciones, Estado) VALUES(0, pTela, NOW(), NULL, NULLIF(pObservaciones, ''), 'A');
    SET pIdTela = (SELECT IdTela FROM Telas WHERE Tela = pTela);
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'T', pIdTela, NOW());

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_dame` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que devuelve una tela y su precio a partir del IdTela.
        Devuelve la Tela y el ultimo precio en respuesta o error en error.
    */

    -- Tela
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Precio
    DECLARE pIdPrecio int;


    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela AND p.IdPrecio = pIdPrecio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_dar_alta`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de alta una tela que se encontraba en estado "Baja". Controla que la tela exista
        Devuelve un json con la tela en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Telas WHERE IdTela = pIdTela) = 'A' THEN
        SELECT f_generarRespuesta("ERROR_TELA_ESTA_ALTA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Telas
        SET Estado = 'A'
        WHERE IdTela = pIdTela;

            SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        )
                )
             AS JSON)
			FROM	Telas t
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_dar_baja`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite dar de baja una tela que se encontraba en estado "Alta". Controla que la tela exista
        Devuelve un json con la tela en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Telas WHERE IdTela = pIdTela) = 'B' THEN
        SELECT f_generarRespuesta("ERROR_TELA_ESTA_BAJA", NULL) pOut;
        LEAVE SALIR; 
    END IF;

    START TRANSACTION;
        UPDATE Telas
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdTela = pIdTela;

            SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        )
                )
             AS JSON)
			FROM	Telas t
			WHERE	t.IdTela = pIdTela
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS`zsp_tela_listar_precios`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_listar_precios`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar el historico de precios de una tela.
        Devuelve una lista de precios en respuesta o el error en error.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Tela de la cual se desea conocer el historico de precios
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_listar_precios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "Precios",
            JSON_OBJECT(
                'IdPrecio', IdPrecio,
                'Precio', Precio,
                'FechaAlta', FechaAlta
            )
        )
    ) 
    FROM Precios 
    WHERE Tipo = 'T' AND IdReferencia = pIdTela
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_tela_modificar_precio`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_modificar_precio`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el precio de una tela. Controla que el precio sea mayor que cero.
        Devuelve un json con la tela y el precio en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;

    -- Precio de la tela
    DECLARE pPrecios JSON;
    DECLARE pIdPrecio int;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_modificar_precio', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";
    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";


    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    IF pPrecio = (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
    INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'T', pIdTela, NOW());

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela AND p.IdPrecio = pIdPrecio
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tela_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tela_modificar`(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una tela. Control que no exista otra tela con el mismo nombre.
        Devuelve un json con la tela y el precio en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Tela a crear
    DECLARE pTelas JSON;
    DECLARE pIdTela smallint;
    DECLARE pTela varchar(60);
    DECLARE pObservaciones varchar(255);

    -- Precio de la tela
    DECLARE pPrecios JSON;
    DECLARE pIdPrecio int;
    DECLARE pPrecio decimal(10,2);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    -- Extraigo atributos de Tela
    SET pTelas = pIn ->> "$.Telas";
    SET pIdTela = pTelas ->> "$.IdTela";
    SET pTela = pTelas ->> "$.Tela";
    

    IF pTela IS NULL OR pTela = '' THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdTela IS NULL OR NOT EXISTS (SELECT IdTela FROM Telas WHERE IdTela = pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdTela FROM Telas WHERE Tela = pTela AND IdTela <> pIdTela) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_TELA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de Precio
    SET pPrecios = pIn ->> "$.Precios";
    SET pPrecio = pPrecios ->> "$.Precio";

    IF pPrecio IS NULL OR pPrecio = 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pPrecio < 0.00 THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_PRECIO", NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    IF pPrecio <> (SELECT Precio FROM Precios WHERE IdPrecio = pIdPrecio) THEN
        -- Si modificó el precio revisamos que pueda hacerlo y lo modificamos
        CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tela_modificar_precio', pIdUsuarioEjecuta, pMensaje);
        IF pMensaje != 'OK' THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;

        INSERT INTO Precios (IdPrecio, Precio, Tipo, IdReferencia, FechaAlta) VALUES(0, pPrecio, 'T', pIdTela, NOW());

        SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;
    END IF;

    UPDATE Telas
    SET Tela = pTela,
        Observaciones = NULLIF(pObservaciones, '')
    WHERE IdTela = pIdTela;

    SELECT f_dameUltimoPrecio('T', pIdTela) INTO pIdPrecio;

    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Telas",  JSON_OBJECT(
                        'IdTela', t.IdTela,
                        'Tela', t.Tela,
                        'FechaAlta', t.FechaAlta,
                        'FechaBaja', t.FechaBaja,
                        'Observaciones', t.Observaciones,
                        'Estado', t.Estado
                        ),
                    "Precios", JSON_OBJECT(
                        'IdPrecio', p.IdPrecio,
                        'Precio', p.Precio,
                        'FechaAlta', p.FechaAlta
                    ) 
                )
             AS JSON)
			FROM	Telas t
            INNER JOIN Precios p ON (p.Tipo = 'T' AND t.IdTela = p.IdReferencia)
			WHERE	t.IdTela = pIdTela AND p.IdPrecio = pIdPrecio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_telas_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_telas_buscar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite buscar telas por su nombre y Estado (A:Activo - B:Baja - T:Todos)
        Devuelve un JSON con la lista de telas en respuesta o el error en error.
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;
    
    -- Tela de la cual se desea conocer el historico de precios
    DECLARE pTelas JSON;
    DECLARE pTela varchar(60);
    DECLARE pEstado char(1);

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_telas_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pTelas = pIn ->> "$.Telas";
    SET pTela = pTelas ->> "$.Tela";
    SET pEstado = pTelas ->> "$.Estado";

    -- Extraigo atributos de la paginacion
    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";

    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;

    SET pTela = COALESCE(pTela,'');

    DROP TEMPORARY TABLE IF EXISTS tmp_Telas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;    
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    -- Resultset completo
    CREATE TEMPORARY TABLE tmp_Telas 
    AS SELECT *
    FROM Telas 
    WHERE
	    Tela LIKE CONCAT(pTela, '%') AND
        (Estado = pEstado OR pEstado = 'T') 
	ORDER BY Tela;
    
    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_Telas);

    -- Resultset paginado
    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * 
    FROM tmp_Telas
    LIMIT pOffset, pLongitudPagina;

    CREATE TEMPORARY TABLE tmp_preciosTelas AS
    SELECT IdReferencia, MAX(IdPrecio) latestId 
    FROM Precios WHERE Tipo = 'T' GROUP BY IdReferencia;

    CREATE TEMPORARY TABLE tmp_ultimosPrecios AS
    SELECT pr.* 
    FROM tmp_preciosTelas tmp
    INNER JOIN Precios pr ON (pr.IdReferencia = tmp.IdReferencia AND pr.IdPrecio = tmp.latestId);



    SET pRespuesta = (SELECT
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado",
                JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "Telas",
                        JSON_OBJECT(
                            'IdTela', tt.IdTela,
                            'Tela', tt.Tela,
                            'FechaAlta', tt.FechaAlta,
                            'FechaBaja', tt.FechaBaja,
                            'Observaciones', tt.Observaciones,
                            'Estado',tt.Estado
                        ),
                        "Precios",
                        JSON_OBJECT(
                            'IdPrecio', tps.IdPrecio,
                            'Precio', tps.Precio,
                            'FechaAlta', tps.FechaAlta
                        )
                    )
                )
        ) 
            

	FROM tmp_ResultadosFinal tt
    INNER JOIN tmp_ultimosPrecios tps ON (tps.Tipo = 'T' AND tt.IdTela = tps.IdReferencia)
	);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_Telas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ultimosPrecios;
    DROP TEMPORARY TABLE IF EXISTS tmp_preciosTelas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tiposDocumento_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_tiposDocumento_listar`()
BEGIN
	/*
		Lista todos los tipos de documento existentes y devuelve la lista de tipos documento en 'respuesta' o el codigo de error en 'error'.
	*/

    DECLARE pRespuesta TEXT;

    SET pRespuesta = (SELECT 
        COALESCE(
            JSON_ARRAYAGG(
                JSON_OBJECT('TiposDocumento',
                    JSON_OBJECT(
                        'IdTipoDocumento', IdTipoDocumento, 
                        'TipoDocumento', TipoDocumento,
                        'Descripcion', Descripcion
                    )
                )
            )
        ,'')
	FROM TiposDocumento
    ORDER BY TipoDocumento);

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_tiposProducto_listar`;

DELIMITER $$
CREATE PROCEDURE `zsp_tiposProducto_listar`(pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que permite listar los tipos de producto.
        Devuelve una lista de tipos de producto en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Para la respuesta
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_tiposProducto_listar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pRespuesta = (SELECT 
    JSON_ARRAYAGG(
        JSON_OBJECT(
            "TiposProducto",
            JSON_OBJECT(
                'IdTipoProducto', IdTipoProducto,
                'TipoProducto', TipoProducto,
                'Descripcion', Descripcion
            )
        )
    ) 
    FROM TiposProducto
    );
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;


END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ubicacion_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar una ubicación.
        Debe controlar que no haya sido utilizado en un presupuesto, venta, linea de producto, remito y que no tenga un Usuario. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    
    
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;

    -- Ubicacion a borrar
    DECLARE pUbicaciones JSON;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdDomicilio int;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicaciones = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicaciones ->> "$.IdUbicacion";

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT Ubicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Presupuestos p USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_PRESUPUESTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Ventas v USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_VENTA' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Remitos r USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_REMITO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUbicacion FROM Ubicaciones u INNER JOIN Usuarios us USING(IdUbicacion) WHERE u.IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_UBICACION_USUARIO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

START TRANSACTION;
    SET pIdDomicilio = (SELECT IdDomicilio FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion);
	DELETE FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion;
    DELETE FROM Domicilios WHERE IdDomicilio = pIdDomicilio;
    SELECT f_generarRespuesta(NULL, NULL)pOut;
COMMIT ;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_ubicacion_crear`;
DELIMITER $$
CREATE PROCEDURE  `zsp_ubicacion_crear` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite crear una ubicación, crea el domicilio primero. 
        Llama al zsp_domicilio_crear
        Devuelve un json con la ubicación y el domicilio creados en respuesta o el codigo de error en error.
    */
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    -- Domicilio creado
    DECLARE pIdDomicilio int;
    -- Ubicacion a crear
    DECLARE pUbicaciones JSON;
    DECLARE pUbicacion varchar(40);
    DECLARE pObservacionesUbicacion varchar(255);

    -- 
    DECLARE pRespuestaSP JSON;


    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo el domicilio del JSON
    -- SET pDomicilios = pIn ->> "$.Domicilios";
    -- SET pIdCiudad = pDomicilios ->> "$.IdCiudad";
    -- SET pIdProvincia = pDomicilios ->> "$.IdProvincia";
    -- SET pIdPais = pDomicilios ->> "$.IdPais";
    -- SET pDomicilio = pDomicilios ->> "$.Domicilio";
    -- SET pCodigoPostal = pDomicilios ->> "$.CodigoPostal";
    -- SET pObservacionesDomicilio = pDomicilios ->> "$.Observaciones";

    -- Extraigo la ubicacion del JSON
    SET pUbicaciones = pIn ->> "$.Ubicaciones";
    SET pUbicacion = pUbicaciones ->> "$.Ubicacion";
    SET pObservacionesUbicacion = pUbicaciones ->> "$.Observaciones";

    IF pUbicacion IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE Ubicacion = pUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF; 


    START TRANSACTION;
        
        CALL zsp_domicilio_crear_comun(pIn, pIdDomicilio, pRespuestaSP);

        IF pIdDomicilio IS NULL THEN
            SELECT pRespuestaSP pOut;
            ROLLBACK;
            LEAVE SALIR;
        END IF;

        INSERT INTO Ubicaciones (IdUbicacion, IdDomicilio, Ubicacion, FechaAlta, FechaBaja, Observaciones, Estado) VALUES (0, pIdDomicilio, pUbicacion, NOW(), NULL, NULLIF(pObservacionesUbicacion, ''), 'A');

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', u.IdUbicacion,
                        'IdDomicilio', u.IdDomicilio,
                        'Ubicacion', u.Ubicacion,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Observaciones', u.Observaciones,
                        'Estado', u.Estado
                        ),
                    "Domicilios", JSON_OBJECT(
                        'IdDomicilio', d.IdDomicilio,
                        'IdCiudad', d.IdCiudad,
                        'IdProvincia', d.IdProvincia,
                        'IdPais', d.IdPais,
                        'Domicilio', d.Domicilio,
                        'CodigoPostal', d.CodigoPostal,
                        'FechaAlta', d.FechaAlta,
                        'Observaciones', d.Observaciones
                    ) 
                )
             AS JSON)
			FROM	Ubicaciones u
            INNER JOIN Domicilios d USING(IdDomicilio)
			WHERE	u.IdDomicilio = pIdDomicilio
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ubicacion_dame`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_dame` (pIn JSON)
SALIR:BEGIN
    /*
        Procedimiento que devuelve una ubicacion y su domicilio a partir del IdUbicacion.
        Devuelve la Ubicacio y la direccion en 'respuesta' o error en 'error'.
    */

    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    -- Ubicacion en cuestion
    DECLARE pUbicacion JSON;
    DECLARE pIdUbicacion tinyint;
    
    -- Respuesta generada
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicacion = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicacion ->> "$.IdUbicacion";

    IF pIdUbicacion IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_UBICACION', NULL)pOut;
        LEAVE SALIR;
	END IF;

    IF (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) IS NULL THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;


    SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', u.IdUbicacion,
                        'IdDomicilio', u.IdDomicilio,
                        'Ubicacion', u.Ubicacion,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Observaciones', u.Observaciones,
                        'Estado', u.Estado
                        ),
                    "Domicilios", JSON_OBJECT(
                        'IdDomicilio', d.IdDomicilio,
                        'IdCiudad', d.IdCiudad,
                        'IdProvincia', d.IdProvincia,
                        'IdPais', d.IdPais,
                        'Domicilio', d.Domicilio,
                        'CodigoPostal', d.CodigoPostal,
                        'FechaAlta', d.FechaAlta,
                        'Observaciones', d.Observaciones
                    ),
                    "Ciudades", JSON_OBJECT(
                        'IdCiudad', c.IdCiudad,
                        'IdProvincia', c.IdProvincia,
                        'IdPais', c.IdPais,
                        'Ciudad', c.Ciudad
                    ),
                    "Provincias", JSON_OBJECT(
                        'IdProvincia', pr.IdProvincia,
                        'IdPais', pr.IdPais,
                        'Provincia', pr.Provincia
                    ),
                    "Paises", JSON_OBJECT(
                        'IdPais', p.IdPais,
                        'Pais', p.Pais
                    )
                )
             AS JSON)
			FROM	Ubicaciones u
            INNER JOIN Domicilios d USING(IdDomicilio)
            INNER JOIN Ciudades c ON d.IdCiudad = c.IdCiudad
            INNER JOIN Provincias pr ON pr.IdProvincia = c.IdProvincia
            INNER JOIN Paises p ON p.IdPais = pr.IdPais
			WHERE	u.IdUbicacion = pIdUbicacion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ubicacion_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_dar_alta`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado de una Ubicacion a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve la ubicacion en 'respuesta' o el codigo de error en 'error'.
	*/
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    -- Ubicacion en cuestion
    DECLARE pUbicacion JSON;
    DECLARE pIdUbicacion tinyint;
    
    -- Respuesta generada
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicacion = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicacion ->> "$.IdUbicacion";


    IF pIdUbicacion IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_UBICACION', NULL)pOut;
        LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (@pEstado = 'A') THEN
		SELECT f_generarRespuesta('ERROR_UBICACION_ESTA_ALTA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Ubicaciones
        SET Estado = 'A',
            FechaAlta = NOW()
        WHERE IdUbicacion = pIdUbicacion;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', u.IdUbicacion,
                        'IdDomicilio', u.IdDomicilio,
                        'Ubicacion', u.Ubicacion,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Observaciones', u.Observaciones,
                        'Estado', u.Estado
                        ),
                    "Domicilios", JSON_OBJECT(
                        'IdDomicilio', d.IdDomicilio,
                        'IdCiudad', d.IdCiudad,
                        'IdProvincia', d.IdProvincia,
                        'IdPais', d.IdPais,
                        'Domicilio', d.Domicilio,
                        'CodigoPostal', d.CodigoPostal,
                        'FechaAlta', d.FechaAlta,
                        'Observaciones', d.Observaciones
                    ) 
                )
             AS JSON)
			FROM	Ubicaciones u
            INNER JOIN Domicilios d USING(IdDomicilio)
			WHERE	u.IdUbicacion = pIdUbicacion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_ubicacion_dar_baja`;

DELIMITER $$
CREATE PROCEDURE `zsp_ubicacion_dar_baja`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado de una Ubicacion a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve la ubicacion en 'respuesta' o el codigo de error en 'error'.
	*/
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    -- Ubicacion en cuestion
    DECLARE pUbicacion JSON;
    DECLARE pIdUbicacion tinyint;
    
    -- Respuesta generada
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUbicacion = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicacion ->> "$.IdUbicacion";


    IF pIdUbicacion IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_UBICACION', NULL)pOut;
        LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (@pEstado = 'B') THEN
		SELECT f_generarRespuesta('ERROR_UBICACION_ESTA_BAJA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Ubicaciones
        SET Estado = 'B',
            FechaBaja = NOW()
        WHERE IdUbicacion = pIdUbicacion;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', u.IdUbicacion,
                        'IdDomicilio', u.IdDomicilio,
                        'Ubicacion', u.Ubicacion,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Observaciones', u.Observaciones,
                        'Estado', u.Estado
                        ),
                    "Domicilios", JSON_OBJECT(
                        'IdDomicilio', d.IdDomicilio,
                        'IdCiudad', d.IdCiudad,
                        'IdProvincia', d.IdProvincia,
                        'IdPais', d.IdPais,
                        'Domicilio', d.Domicilio,
                        'CodigoPostal', d.CodigoPostal,
                        'FechaAlta', d.FechaAlta,
                        'Observaciones', d.Observaciones
                    ) 
                )
             AS JSON)
			FROM	Ubicaciones u
            INNER JOIN Domicilios d USING(IdDomicilio)
			WHERE	u.IdUbicacion = pIdUbicacion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_ubicaciones_listar`;
DELIMITER $$
CREATE PROCEDURE `zsp_ubicaciones_listar`()
SALIR: BEGIN

    /*
        Devuele un json con el listado de las ubicaciones
    */
    DECLARE pRespuesta JSON;

    SET pRespuesta  = (SELECT
        JSON_ARRAYAGG(
            JSON_OBJECT(
                "Ubicaciones",  JSON_OBJECT(
                    'IdUbicacion', u.IdUbicacion,
                    'IdDomicilio', u.IdDomicilio,
                    'Ubicacion', u.Ubicacion,
                    'FechaAlta', u.FechaAlta,
                    'FechaBaja', u.FechaBaja,
                    'Observaciones', u.Observaciones,
                    'Estado', u.Estado
                    ),
                "Domicilios", JSON_OBJECT(
                    'IdDomicilio', d.IdDomicilio,
                    'IdCiudad', d.IdCiudad,
                    'IdProvincia', d.IdProvincia,
                    'IdPais', d.IdPais,
                    'Domicilio', d.Domicilio,
                    'CodigoPostal', d.CodigoPostal,
                    'FechaAlta', d.FechaAlta,
                    'Observaciones', d.Observaciones
                ),
                'Ciudades', JSON_OBJECT(
                        'IdCiudad', c.IdCiudad,
                        'IdProvincia', c.IdProvincia,
                        'IdPais', c.IdPais,
                        'Ciudad', c.Ciudad
                    ),
                'Provincias', JSON_OBJECT(
                        'IdProvincia', pr.IdProvincia,
                        'IdPais', pr.IdPais,
                        'Provincia', pr.Provincia
                ),
                'Paises', JSON_OBJECT(
                        'IdPais', p.IdPais,
                        'Pais', p.Pais
                )
            )
        )  
    FROM	Ubicaciones u
    INNER JOIN Domicilios d ON u.IdDomicilio = d.IdDomicilio
    INNER JOIN Ciudades c ON d.IdCiudad = c.IdCiudad
    INNER JOIN Provincias pr ON pr.IdProvincia = c.IdProvincia
    INNER JOIN Paises p ON p.IdPais = pr.IdPais
    );    
    
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_ubicacion_modificar`;
DELIMITER $$
CREATE PROCEDURE  `zsp_ubicacion_modificar` (pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite modificar una ubicación y su domicilio. 
        Debe existir el la ciudad, provincia y pais. Controla que no exista el mismo domicilio en la misma ciudad.
        Devuelve un json con la ubicación y el domicilio modificado en respuesta o el codigo de error en error.
    */
    -- Usuario que ejecuta
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;

    -- Domicilio a modificar
    DECLARE pDomicilios JSON;
    DECLARE pIdDomicilio int;
    DECLARE pIdCiudad int;
    DECLARE pIdProvincia int;
    DECLARE pIdPais char(2);
    DECLARE pDomicilio varchar(120);
    DECLARE pCodigoPostal varchar(10);
    DECLARE pFechaAlta datetime;
    DECLARE pObservacionesDomicilio varchar(255);

    -- Ubicacion a modificar
    DECLARE pUbicaciones JSON;
    DECLARE pIdUbicacion tinyint;
    DECLARE pUbicacion varchar(40);
    DECLARE pObservacionesUbicacion varchar(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ubicacion_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo el domicilio del JSON
    SET pDomicilios = pIn ->> "$.Domicilios";
    SET pIdDomicilio = pDomicilios ->> "$.IdDomicilio";
    SET pIdCiudad = pDomicilios ->> "$.IdCiudad";
    SET pIdProvincia = pDomicilios ->> "$.IdProvincia";
    SET pIdPais = pDomicilios ->> "$.IdPais";
    SET pDomicilio = pDomicilios ->> "$.Domicilio";
    SET pCodigoPostal = pDomicilios ->> "$.CodigoPostal";
    SET pObservacionesDomicilio = pDomicilios ->> "$.Observaciones";

    -- Extraigo la ubicacion del JSON
    SET pUbicaciones = pIn ->> "$.Ubicaciones";
    SET pIdUbicacion = pUbicaciones ->> "$.IdUbicacion";
    SET pUbicacion = pUbicaciones ->> "$.Ubicacion";
    SET pObservacionesUbicacion = pUbicaciones ->> "$.Observaciones";

    IF pIdUbicacion IS NULL OR NOT EXISTS (SELECT Ubicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pUbicacion IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE Ubicacion = pUbicacion AND IdUbicacion <> pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF; 

    IF (pIdPais IS NULL OR NOT EXISTS (SELECT IdPais FROM Paises WHERE IdPais = pIdPais)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PAIS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdProvincia IS NULL OR NOT EXISTS (SELECT IdProvincia FROM Provincias WHERE IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_PROVINCIA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdCiudad IS NULL OR NOT EXISTS (SELECT IdCiudad FROM Ciudades WHERE IdCiudad = pIdCiudad AND IdProvincia = pIdProvincia AND IdPais = pIdPais)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CIUDAD", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pCodigoPostal IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_CP", NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF EXISTS (SELECT IdDomicilio FROM Domicilios WHERE Domicilio = pDomicilio AND IdCiudad = pIdCiudad AND IdDomicilio <> pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_UBICACION_CIUDAD", NULL) pOut;
    END IF;



    START TRANSACTION;

        
        UPDATE Ubicaciones
        SET Ubicacion = pUbicacion,
            Observaciones = pObservacionesUbicacion
        WHERE IdUbicacion = pIdUbicacion;

        UPDATE Domicilios
        SET IdCiudad = pIdCiudad,
            IdProvincia = pIdProvincia,
            IdPais = pIdPais,
            Domicilio = pDomicilio,
            CodigoPostal = pCodigoPostal,
            Observaciones = pObservacionesDomicilio
        WHERE IdDomicilio = pIdDomicilio;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ubicaciones",  JSON_OBJECT(
                        'IdUbicacion', u.IdUbicacion,
                        'IdDomicilio', u.IdDomicilio,
                        'Ubicacion', u.Ubicacion,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Observaciones', u.Observaciones,
                        'Estado', u.Estado
                        ),
                    "Domicilios", JSON_OBJECT(
                        'IdDomicilio', d.IdDomicilio,
                        'IdCiudad', d.IdCiudad,
                        'IdProvincia', d.IdProvincia,
                        'IdPais', d.IdPais,
                        'Domicilio', d.Domicilio,
                        'CodigoPostal', d.CodigoPostal,
                        'FechaAlta', d.FechaAlta,
                        'Observaciones', d.Observaciones
                    ) 
                )
             AS JSON)
			FROM	Ubicaciones u
            INNER JOIN Domicilios d USING(IdDomicilio)
			WHERE	u.IdUbicacion = pIdUbicacion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS `zsp_usuario_borrar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_borrar`(pIn JSON)


SALIR: BEGIN
	/*
        Procedimiento que permite a un usuario borrar un usuario.
        Debe controlar que no haya creado un presupuesto, venta, orden de produccion, remito, comprobante, o que no se le 
        haya asignado o haya revisado alguna tarea. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pUsuarios JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";

	IF pIdUsuario = 1 THEN
		SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_ADAM', NULL)pOut;
		LEAVE SALIR;
	END IF;

    IF NOT EXISTS (SELECT Usuario FROM Usuarios WHERE IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Presupuestos p USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_PRESUPUESTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Ventas v USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_VENTA' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN OrdenesProduccion op USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_OP' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Comprobantes c USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_COMPROBANTE' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Remitos r USING(IdUsuario) WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_REMITO' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioFabricante WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_TAREA_F' , NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT u.IdUsuario FROM Usuarios u INNER JOIN Tareas t ON u.IdUsuario = t.IdUsuarioRevisor WHERE u.IdUsuario = pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_BORRAR_USUARIO_TAREA_R' , NULL)pOut;
        LEAVE SALIR;
    END IF;
    
	DELETE FROM Usuarios WHERE IdUsuario = pIdUsuario;
    SELECT f_generarRespuesta(NULL, NULL)pOut;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_crear`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_crear`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario crear un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
        Debe existir el Rol, TipoDocumento y la Ubicacion.
        Almacena el hash de la contraseña.
        Todos los campos son obligatorios.
        Devuelve un json con el usuario creado en respuesta o el codigo de error en error.
    */
    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuario smallint;
    DECLARE pToken varchar(256);
    DECLARE pIdRol tinyint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pEstadoCivil char(1);
    DECLARE pTelefono varchar(15);
    DECLARE pEmail varchar(120);
    DECLARE pCantidadHijos tinyint;
    DECLARE pUsuario varchar(40);
    DECLARE pPassword varchar(255);
    DECLARE pFechaNacimiento date;
    DECLARE pFechaInicio date;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pIdUbicacion = pUsuarios ->> "$.IdUbicacion";
    SET pIdTipoDocumento = pUsuarios ->> "$.IdTipoDocumento";
    SET pDocumento = pUsuarios ->> "$.Documento";
    SET pNombres = pUsuarios ->> "$.Nombres";
    SET pApellidos = pUsuarios ->> "$.Apellidos";
    SET pEstadoCivil = pUsuarios ->> "$.EstadoCivil";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pTelefono = pUsuarios ->> "$.Telefono";
    SET pEmail = pUsuarios ->> "$.Email";
    SET pCantidadHijos = pUsuarios ->> "$.CantidadHijos";
    SET pPassword = pUsuarios ->> "$.Password";
    SET pUsuario = pUsuarios ->> "$.Usuario";
    SET pFechaNacimiento = pUsuarios ->> "$.FechaNacimiento";
    SET pFechaInicio = pUsuarios ->> "$.FechaInicio";

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_ROL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_TIPODOC", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_DOCUMENTO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_USUARIO_TIPODOC_DOC", NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_NOMBRE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_APELLIDO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT f_generarRespuesta("ERROR_INVALIDO_ESTADOCIVIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_TELEFONO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT f_generarRespuesta("ERROR_INGRESAR_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_EMAIL", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_CANTIDADHIJOS", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pUsuario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_USUARIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT f_generarRespuesta("ERROR_ESPACIO_USUARIO", NULL) pOut;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario) THEN
        SELECT f_generarRespuesta("ERROR_EXISTE_USUARIO", NULL) pOut;
		LEAVE SALIR;
	END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_PASSWORD", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT f_generarRespuesta("ERROR_FECHANACIMIENTO_ANTERIOR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT f_generarRespuesta("ERROR_FECHAINICIO_ANTERIOR", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Usuarios (IdUsuario,IdRol,IdUbicacion,IdTipoDocumento,Documento,Nombres,Apellidos,EstadoCivil,Telefono,Email,CantidadHijos,Usuario,Password,Token,FechaUltIntento,Intentos,FechaNacimiento,FechaInicio,FechaAlta,FechaBaja,Estado) VALUES (0, pIdRol, pIdUbicacion, pIdTipoDocumento, pDocumento, pNombres, pApellidos, pEstadoCivil, pTelefono, pEmail, pCantidadHijos, pUsuario, pPassword, NULL, NULL, 0 ,pFechaNacimiento, pFechaInicio, NOW(), NULL,'A');
        SET pIdUsuario = (SELECT IdUsuario FROM Usuarios WHERE Email = pEmail);
        SET pRespuesta = (
        SELECT CAST(
				COALESCE(
					JSON_OBJECT(
						'IdUsuario', IdUsuario,
                        'IdRol', IdRol,
                        'IdUbicacion', IdUbicacion,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'EstadoCivil', EstadoCivil,
                        'Telefono', Telefono,
                        'Email', Email,
                        'CantidadHijos', CantidadHijos,
                        'Usuario', Usuario,
                        'FechaUltIntento', FechaUltIntento,
                        'FechaNacimiento', FechaNacimiento,
                        'FechaInicio', FechaInicio,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					)
				,'') AS JSON)
        FROM	Usuarios
        WHERE	IdUsuario = pIdUsuario
    );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_dame_por_token`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame_por_token`(pIn JSON)

SALIR: BEGIN

    /*
        Procedimiento que sirve para instanciar un usuario por token desde la base de datos.
    */	

    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuario int;
    DECLARE pRespuesta JSON;
    DECLARE pToken varchar(256);
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pIdUsuario = pUsuariosEjecuta ->> '$.IdUsuario';
    SET pToken = pUsuariosEjecuta ->> '$.Token';
    
    SET pRespuesta = (
        SELECT JSON_OBJECT(
                    "Usuarios",
                    JSON_OBJECT(
                        'IdUsuario', IdUsuario,
                        'IdRol', IdRol,
                        'IdUbicacion', IdUbicacion,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'EstadoCivil', EstadoCivil,
                        'Telefono', Telefono,
                        'Email', Email,
                        'CantidadHijos', CantidadHijos,
                        'Usuario', Usuario,
                        'FechaUltIntento', FechaUltIntento,
                        'FechaNacimiento', FechaNacimiento,
                        'FechaInicio', FechaInicio,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Estado', u.Estado
                    ),
                    "Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol,
                        'Rol', Rol
                    ),
                    "Ubicaciones",
                    JSON_OBJECT(
                        'IdUbicacion', IdUbicacion,
                        'Ubicacion', Ubicacion
                    ))
        FROM	Usuarios u
        INNER JOIN	Roles r USING (IdRol)
        INNER JOIN	Ubicaciones USING (IdUbicacion)
        WHERE	Token = pToken
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dame`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dame`(pIn JSON)

SALIR: BEGIN
    DECLARE pUsuarios, pUsuariosEjecuta JSON;
    DECLARE pIdUsuario smallint;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pRespuesta JSON;
    DECLARE pToken varchar(256);
    /*
        Procedimiento que sirve para instanciar un usuario por id desde la base de datos.
    */

    SET pUsuarios = pIn ->> '$.Usuarios';
    SET pUsuariosEjecuta = pIn ->> '$.UsuariosEjecuta';
    SET pToken = pUsuariosEjecuta ->> '$.Token';

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dame', pIdUsuarioEjecuta, pMensaje);
	IF pMensaje!='OK' THEN
		SELECT f_generarRespuesta(pMensaje, NULL) pOut;
		LEAVE SALIR;
	END IF;

    SET pIdUsuario = pUsuarios ->> '$.IdUsuario';

	SET pRespuesta = (
        SELECT JSON_OBJECT(
                    "Usuarios",
					JSON_OBJECT(
						'IdUsuario', IdUsuario,
                        'IdRol', IdRol,
                        'IdUbicacion', IdUbicacion,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'EstadoCivil', EstadoCivil,
                        'Telefono', Telefono,
                        'Email', Email,
                        'CantidadHijos', CantidadHijos,
                        'Usuario', Usuario,
                        'FechaUltIntento', FechaUltIntento,
                        'FechaNacimiento', FechaNacimiento,
                        'FechaInicio', FechaInicio,
                        'FechaAlta', u.FechaAlta,
                        'FechaBaja', u.FechaBaja,
                        'Estado', u.Estado
					),
                    "Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol,
                        'Rol', Rol
					),
                    "Ubicaciones",
                    JSON_OBJECT(
                        'IdUbicacion', IdUbicacion,
                        'Ubicacion', Ubicacion
					))
        FROM	Usuarios u
        INNER JOIN	Roles r USING (IdRol)
        INNER JOIN	Ubicaciones USING (IdUbicacion)
        WHERE	IdUsuario = pIdUsuario
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dar_alta`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_alta`(pIn JSON)
SALIR: BEGIN
	/*
        Permite cambiar el estado del Usuario a 'Alta' siempre y cuando no esté en estado 'Alta' ya.
        Devuelve el usuario en 'respuesta' o el codigo de error en 'error'.
	*/
	DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_alta', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";


    IF pIdUsuario IS NULL THEN
		SELECT f_generarRespuesta('ERROR_INGRESAR_USUARIO', NULL)pOut;
        LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (@pEstado = 'A') THEN
		SELECT f_generarRespuesta('ERROR_USUARIO_ESTA_ALTA', NULL)pOut;
        LEAVE SALIR;
	END IF;

    START TRANSACTION;

        UPDATE Usuarios
        SET Estado = 'A',
            Intentos = 0
        WHERE IdUsuario = pIdUsuario;

        SET pRespuesta = (
            SELECT CAST(
                    COALESCE(
                        JSON_OBJECT(
                            'IdUsuario', IdUsuario,
                            'IdRol', IdRol,
                            'IdUbicacion', IdUbicacion,
                            'IdTipoDocumento', IdTipoDocumento,
                            'Documento', Documento,
                            'Nombres', Nombres,
                            'Apellidos', Apellidos,
                            'EstadoCivil', EstadoCivil,
                            'Telefono', Telefono,
                            'Email', Email,
                            'CantidadHijos', CantidadHijos,
                            'Usuario', Usuario,
                            'FechaUltIntento', FechaUltIntento,
                            'FechaNacimiento', FechaNacimiento,
                            'FechaInicio', FechaInicio,
                            'FechaAlta', FechaAlta,
                            'FechaBaja', FechaBaja,
                            'Estado', Estado
                        )
                    ,'') AS JSON)
            FROM	Usuarios
            WHERE	IdUsuario = pIdUsuario
        );
        SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_dar_baja`;
DELIMITER $$
CREATE PROCEDURE `zsp_usuario_dar_baja`(pIn JSON)

SALIR: BEGIN
    /*
        Permite cambiar el estado del Usuario a 'Baja' siempre y cuando no esté en estado 'Baja' ya.
        Devuelve el usuario en 'respuesta' o el codigo de error en 'error.
    */
    DECLARE pIdUsuarioEjecuta smallint;
	DECLARE pMensaje text;
    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pToken varchar(256);
    DECLARE pIdUsuario smallint;
    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_dar_baja', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";

    IF pIdUsuario = 1 THEN
		SELECT f_generarRespuesta('ERROR_DARBAJA_USUARIO_ADAM', NULL)pOut;
		LEAVE SALIR;
	END IF;

    SET @pEstado = (SELECT Estado FROM Usuarios WHERE IdUsuario = pIdUsuario);

    IF (@pEstado IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

     IF (@pEstado = 'B') THEN
        SELECT f_generarRespuesta('ERROR_USUARIO_ESTA_BAJA', NULL)pOut;
        LEAVE SALIR;
    END IF;
		
    START TRANSACTION;
        UPDATE Usuarios 
        SET Estado = 'B',
            Token = NULL 
        WHERE IdUsuario = pIdUsuario;
        SET pRespuesta = (
                SELECT CAST(
                        COALESCE(
                            JSON_OBJECT(
                                'IdUsuario', IdUsuario,
                                'IdRol', IdRol,
                                'IdUbicacion', IdUbicacion,
                                'IdTipoDocumento', IdTipoDocumento,
                                'Documento', Documento,
                                'Nombres', Nombres,
                                'Apellidos', Apellidos,
                                'EstadoCivil', EstadoCivil,
                                'Telefono', Telefono,
                                'Email', Email,
                                'CantidadHijos', CantidadHijos,
                                'Usuario', Usuario,
                                'FechaUltIntento', FechaUltIntento,
                                'FechaNacimiento', FechaNacimiento,
                                'FechaInicio', FechaInicio,
                                'FechaAlta', FechaAlta,
                                'FechaBaja', FechaBaja,
                                'Estado', Estado
                            )
                        ,'') AS JSON)
                FROM	Usuarios
                WHERE	IdUsuario = pIdUsuario
            );
            SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_modificar_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar_pass`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar su contraseña comprobando que la contraseña actual ingresada sea correcta.
        Devuelve 'OK' o el mensaje de error en Mensaje
    */
    DECLARE pMensaje text;

    DECLARE pUsuariosEjecuta, pUsuariosActual, pUsuariosNuevo, pRespuesta JSON;

    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pPasswordActual varchar(255);
    DECLARE pPasswordNueva varchar(255);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar_pass', pIdUsuarioEjecuta, pMensaje);

    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuariosActual = pIn ->> "$.UsuariosActual";
    SET pPasswordActual = pUsuariosActual ->> "$.Password";

    IF NOT EXISTS(SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuarioEjecuta AND Password = pPasswordActual) THEN
        SELECT f_generarRespuesta('ERROR_PASSWORD_INCORRECTA', NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuariosNuevo = pIn ->> "$.UsuariosNuevo";
    SET pPasswordNueva = pUsuariosNuevo ->> "$.Password";

    IF (pPasswordActual = pPasswordNueva) THEN
        SELECT f_generarRespuesta('ERROR_PASSWORDS_IGUALES', NULL) pOut;
        LEAVE SALIR;
    END IF;


    IF(pPasswordNueva IS NULL OR pPasswordNueva = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_PASSWORD', NULL) pOut;
        LEAVE SALIR;
    END IF;
    

    START TRANSACTION;  
        UPDATE  Usuarios 
        SET Password = pPasswordNueva
        WHERE IdUsuario = pIdUsuarioEjecuta;

        SET pRespuesta = (
            SELECT CAST(
                    COALESCE(
                        JSON_OBJECT(
                            'IdUsuario', IdUsuario,
                            'IdRol', IdRol,
                            'IdUbicacion', IdUbicacion,
                            'IdTipoDocumento', IdTipoDocumento,
                            'Documento', Documento,
                            'Nombres', Nombres,
                            'Apellidos', Apellidos,
                            'EstadoCivil', EstadoCivil,
                            'Telefono', Telefono,
                            'Email', Email,
                            'CantidadHijos', CantidadHijos,
                            'Usuario', Usuario,
                            'FechaUltIntento', FechaUltIntento,
                            'FechaNacimiento', FechaNacimiento,
                            'FechaInicio', FechaInicio,
                            'FechaAlta', FechaAlta,
                            'FechaBaja', FechaBaja,
                            'Estado', Estado
                        )
                    ,'') AS JSON)
            FROM	Usuarios
            WHERE	IdUsuario = pIdUsuarioEjecuta
        );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;
END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_modificar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_modificar`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario modifcar un usuario controlando que no exista un usuario con el mismo email, usuario y tipo y número de documento. 
        Debe existir el Rol, TipoDocumento y la Ubicacion.
        Almacena el hash de la contraseña.
        Todos los campos son obligatorios.
        Devuelve 'OK' + IdUsuario o el mensaje de error en  Mensaje.
    */

    DECLARE pUsuarios JSON;
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pMensaje text;
    DECLARE pIdUsuario smallint;
    DECLARE pToken varchar(256);
    DECLARE pIdRol tinyint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pNombres varchar(40);
    DECLARE pApellidos varchar(40);
    DECLARE pEstadoCivil char(1);
    DECLARE pTelefono varchar(15);
    DECLARE pEmail varchar(120);
    DECLARE pCantidadHijos tinyint;
    DECLARE pUsuario varchar(40);
    DECLARE pPassword varchar(255);
    DECLARE pFechaNacimiento date;
    DECLARE pFechaInicio date;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;


    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pIdUbicacion = pUsuarios ->> "$.IdUbicacion";
    SET pIdTipoDocumento = pUsuarios ->> "$.IdTipoDocumento";
    SET pDocumento = pUsuarios ->> "$.Documento";
    SET pNombres = pUsuarios ->> "$.Nombres";
    SET pApellidos = pUsuarios ->> "$.Apellidos";
    SET pEstadoCivil = pUsuarios ->> "$.EstadoCivil";
    SET pTelefono = pUsuarios ->> "$.Telefono";
    SET pEmail = pUsuarios ->> "$.Email";
    SET pCantidadHijos = pUsuarios ->> "$.CantidadHijos";
    SET pPassword = pUsuarios ->> "$.Password";
    SET pUsuario = pUsuarios ->> "$.Usuario";
    SET pFechaNacimiento = pUsuarios ->> "$.FechaNacimiento";
    SET pFechaInicio = pUsuarios ->> "$.FechaInicio";


    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdRol IS NULL OR NOT EXISTS (SELECT IdRol FROM Roles WHERE IdRol = pIdRol)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_ROL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUbicacion IS NULL OR NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_UBICACION', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdTipoDocumento IS NULL OR NOT EXISTS (SELECT IdTipoDocumento FROM TiposDocumento WHERE IdTipoDocumento = pIdTipoDocumento)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_TIPODOC', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pDocumento IS NULL OR pDocumento = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_DOCUMENTO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdTipoDocumento = pIdTipoDocumento AND Documento = pDocumento AND IdUsuario != pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_EXISTE_USUARIO_TIPODOC_DOC', NULL)pOut;
        LEAVE SALIR;
    END IF;
    
    IF (pNombres IS NULL OR pNombres = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_NOMBRE', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pApellidos IS NULL OR pApellidos = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_APELLIDO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pEstadoCivil NOT IN ('C', 'S', 'D')) THEN
        SELECT f_generarRespuesta('ERROR_INVALIDO_ESTADOCIVIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pTelefono IS NULL OR pTelefono = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_TELEFONO', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pEmail IS NULL OR pEmail = '') THEN 
        SELECT f_generarRespuesta('ERROR_INGRESAR_EMAIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS (SELECT Email FROM Usuarios WHERE Email = pEmail AND IdUsuario != pIdUsuario) THEN
        SELECT f_generarRespuesta('ERROR_EXISTE_EMAIL', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF (pCantidadHijos IS NULL) THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_CANTIDADHIJOS', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF pUsuario IS NULL THEN
        SELECT f_generarRespuesta("ERROR_INGRESAR_USUARIO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (LENGTH(pUsuario) <> LENGTH(REPLACE(pUsuario,' ',''))) THEN
        SELECT f_generarRespuesta('ERROR_ESPACIO_USUARIO', NULL)pOut;
        LEAVE SALIR;
	END IF;

    IF EXISTS(SELECT Usuario FROM Usuarios WHERE Usuario = pUsuario AND IdUsuario != pIdUsuario) THEN
		SELECT f_generarRespuesta('ERROR_EXISTE_USUARIO', NULL)pOut;
		LEAVE SALIR;
	END IF;

    IF(pFechaNacimiento IS NULL OR pFechaNacimiento > NOW()) THEN
        SELECT f_generarRespuesta('ERROR_FECHANACIMIENTO_ANTERIOR', NULL)pOut;
        LEAVE SALIR;
    END IF;

    IF(pFechaInicio IS NULL OR pFechaInicio > NOW()) THEN
        SELECT f_generarRespuesta('ERROR_FECHAINICIO_ANTERIOR', NULL)pOut;
        LEAVE SALIR;
    END IF;
    START TRANSACTION;  
    
        UPDATE  Usuarios 
        SET IdUsuario = pIdUsuario,
            IdRol = pIdRol,
            IdUbicacion = pIdUbicacion,
            IdTipoDocumento = pIdTipoDocumento,
            Documento = pDocumento,
            Nombres = pNombres, 
            Apellidos = pApellidos,
            EstadoCivil =  pEstadoCivil,
            Telefono = pTelefono,
            Email = pEmail,
            CantidadHijos = pCantidadHijos,
            Usuario = pUsuario,
            FechaNacimiento = pFechaNacimiento,
            FechaInicio = pFechaInicio
        WHERE IdUsuario = pIdUsuario;

        SET pRespuesta = (
            SELECT CAST(
                    COALESCE(
                        JSON_OBJECT(
                            'IdUsuario', IdUsuario,
                            'IdRol', IdRol,
                            'IdUbicacion', IdUbicacion,
                            'IdTipoDocumento', IdTipoDocumento,
                            'Documento', Documento,
                            'Nombres', Nombres,
                            'Apellidos', Apellidos,
                            'EstadoCivil', EstadoCivil,
                            'Telefono', Telefono,
                            'Email', Email,
                            'CantidadHijos', CantidadHijos,
                            'Usuario', Usuario,
                            'FechaUltIntento', FechaUltIntento,
                            'FechaNacimiento', FechaNacimiento,
                            'FechaInicio', FechaInicio,
                            'FechaAlta', FechaAlta,
                            'FechaBaja', FechaBaja,
                            'Estado', Estado
                        )
                    ,'') AS JSON)
            FROM	Usuarios
            WHERE	IdUsuario = pIdUsuario
        );
		SELECT f_generarRespuesta(NULL, JSON_OBJECT("Usuarios", pRespuesta)) AS pOut;
    COMMIT;

END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuario_restablecer_pass`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_restablecer_pass`(pIn JSON)

SALIR:BEGIN
    /*
        Procedimiento que permite a un usuario restablecer la contraseña de otro usuario. 
        Devuelve NULL en 'respuesta' o el codigo de error en 'error'.
    */
    DECLARE pMensaje text;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pIdUsuario smallint;
    DECLARE pPassword varchar(255);
    DECLARE pToken varchar(256);
    DECLARE pUsuarios, pUsuariosEjecuta, pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		SELECT 'ERROR_TRANSACCION' Mensaje;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuario_restablecer_pass', pIdUsuarioEjecuta, pMensaje);

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdUsuario = pUsuarios ->> "$.IdUsuario";
    SET pPassword = pUsuarios ->> "$.Password";
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (pIdUsuario IS NULL OR NOT EXISTS (SELECT IdUsuario FROM Usuarios WHERE IdUsuario = pIdUsuario)) THEN
        SELECT f_generarRespuesta('ERROR_NOEXISTE_USUARIO', NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF(pPassword IS NULL OR pPassword = '') THEN
        SELECT f_generarRespuesta('ERROR_INGRESAR_PASSWORD', NULL) pOut;
        LEAVE SALIR;
    END IF;

    UPDATE  Usuarios 
    SET Password = pPassword
    WHERE IdUsuario = pIdUsuario;
    
    SELECT f_generarRespuesta(NULL, NULL) pOut;

END $$
DELIMITER ;


DROP PROCEDURE IF EXISTS `zsp_usuarios_buscar`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuarios_buscar`(pIn JSON)
SALIR: BEGIN
	/*
		Permite buscar los usuarios por una cadena, o bien, por sus nombres y apellidos, nombre de usuario, email, documento, telefono,
        estado civil (C:Casado - S:Soltero - D:Divorciado - T:Todos), estado (A:Activo - B:Baja - T:Todos), rol (0:Todos los roles),
        ubicacion en la que trabaja (0:Todas las ubicaciones) y si tiene hijos o no (S:Si - N:No - T:Todos).
	*/
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Usuarios
    DECLARE pUsuarios JSON;
    DECLARE pRespuesta JSON;
    DECLARE pIdUsuario smallint;
    DECLARE pIdRol tinyint;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdTipoDocumento tinyint;
    DECLARE pDocumento varchar(15);
    DECLARE pNombres varchar(60);
    DECLARE pApellidos varchar(60);
    DECLARE pEstadoCivil char(1);
    DECLARE pTelefono varchar(15);
    DECLARE pEmail varchar(120);
    DECLARE pCantidadHijos tinyint;
    DECLARE pUsuario varchar(40);
    DECLARE pPassword varchar(255);
    DECLARE pFechaNacimiento date;
    DECLARE pFechaInicio date;
    DECLARE pNombresApellidos varchar(120);
    DECLARE pEstado char(1);
    DECLARE pTieneHijos char(1);

    -- Paginacion
    DECLARE pPaginaciones JSON;
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
	END;

    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_usuarios_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pUsuarios = pIn ->> "$.Usuarios";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pIdUbicacion = pUsuarios ->> "$.IdUbicacion";
    SET pIdTipoDocumento = pUsuarios ->> "$.IdTipoDocumento";
    SET pDocumento = pUsuarios ->> "$.Documento";
    SET pNombres = pUsuarios ->> "$.Nombres";
    SET pApellidos = pUsuarios ->> "$.Apellidos";
    SET pEstadoCivil = pUsuarios ->> "$.EstadoCivil";
    SET pIdRol = pUsuarios ->> "$.IdRol";
    SET pTelefono = pUsuarios ->> "$.Telefono";
    SET pEmail = pUsuarios ->> "$.Email";
    SET pCantidadHijos = pUsuarios ->> "$.CantidadHijos";
    SET pPassword = pUsuarios ->> "$.Password";
    SET pUsuario = pUsuarios ->> "$.Usuario";
    SET pFechaNacimiento = pUsuarios ->> "$.FechaNacimiento";
    SET pFechaInicio = pUsuarios ->> "$.FechaInicio";
    SET pEstado = pUsuarios ->> "$.Estado";
    SET pNombresApellidos = CONCAT(pNombres, pApellidos);

    SET pPaginaciones = pIn ->>"$.Paginaciones";
    SET pPagina = pPaginaciones ->> "$.Pagina";
    SET pLongitudPagina = pPaginaciones ->> "$.LongitudPagina";


    IF pEstado IS NULL OR pEstado = '' OR pEstado NOT IN ('A','B') THEN
		SET pEstado = 'T';
	END IF;

    IF pEstadoCivil IS NULL OR pEstadoCivil = '' OR pEstadoCivil NOT IN ('C','S','D') THEN
		SET pEstadoCivil = 'T';
	END IF;

    -- IF pTieneHijos IS NULL OR pTieneHijos = '' OR pTieneHijos NOT IN ('S','N') THEN
		SET pTieneHijos = 'T';
	-- END IF;

    IF pPagina IS NULL OR pPagina = 0 THEN
        SET pPagina = 1;
    END IF;

    IF pLongitudPagina IS NULL OR pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT CAST(Valor AS UNSIGNED) FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;

    SET pOffset = (pPagina - 1) * pLongitudPagina;
    
    SET pNombresApellidos = COALESCE(pNombresApellidos,'');
    SET pUsuario = COALESCE(pUsuario,'');
    SET pEmail = COALESCE(pEmail,'');
    SET pDocumento = COALESCE(pDocumento,'');
    SET pTelefono = COALESCE(pTelefono,'');
    SET pIdRol = COALESCE(pIdRol,0);
    SET pIdUbicacion = COALESCE(pIdUbicacion,0);

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

    CREATE TEMPORARY TABLE tmp_ResultadosTotal AS
    SELECT  IdUsuario, u.IdRol , u.IdUbicacion, IdTipoDocumento, Documento, Nombres, Apellidos, EstadoCivil, Telefono, Email, Usuario, FechaUltIntento, 
            FechaNacimiento, CantidadHijos, FechaInicio, u.FechaAlta, u.FechaBaja, u.Estado , Rol, Ubicacion
    FROM		Usuarios u
	INNER JOIN	Roles r ON u.IdRol = r.IdRol
    INNER JOIN	Ubicaciones ub ON u.IdUbicacion = ub.IdUbicacion
	WHERE		u.IdRol IS NOT NULL AND 
				(
                    CONCAT(Apellidos,',',Nombres) LIKE CONCAT('%', pNombresApellidos, '%') AND
                    Usuario LIKE CONCAT(pUsuario, '%') AND
                    Email LIKE CONCAT(pEmail, '%') AND
                    Documento LIKE CONCAT(pDocumento, '%') AND
                    Telefono LIKE CONCAT(pTelefono, '%')
				) AND 
                (u.IdRol = pIdRol OR pIdRol = 0) AND
                (u.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0) AND
                (u.Estado = pEstado OR pEstado = 'T') AND
                (EstadoCivil = pEstadoCivil OR pEstadoCivil = 'T') AND
                IF(pTieneHijos = 'S', u.CantidadHijos > 0, IF(pTieneHijos = 'N', CantidadHijos = 0, pTieneHijos = 'T'))
	ORDER BY	CONCAT(Apellidos, ' ', Nombres), Usuario;

    -- Para devolver el total en paginaciones
    SET pCantidadTotal = (SELECT COUNT(*) FROM tmp_ResultadosTotal);

    CREATE TEMPORARY TABLE tmp_ResultadosFinal AS
    SELECT * FROM tmp_ResultadosTotal
    LIMIT pOffset, pLongitudPagina; 
    
	SET pRespuesta = (SELECT 
        JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", JSON_ARRAYAGG(
                JSON_OBJECT(
                    "Usuarios",
                    JSON_OBJECT(
						'IdUsuario', IdUsuario,
                        'IdRol', IdRol,
                        'IdUbicacion', IdUbicacion,
                        'IdTipoDocumento', IdTipoDocumento,
                        'Documento', Documento,
                        'Nombres', Nombres,
                        'Apellidos', Apellidos,
                        'EstadoCivil', EstadoCivil,
                        'Telefono', Telefono,
                        'Email', Email,
                        'CantidadHijos', CantidadHijos,
                        'Usuario', Usuario,
                        'FechaUltIntento', FechaUltIntento,
                        'FechaNacimiento', FechaNacimiento,
                        'FechaInicio', FechaInicio,
                        'FechaAlta', FechaAlta,
                        'FechaBaja', FechaBaja,
                        'Estado', Estado
					),
                    "Roles",
                    JSON_OBJECT(
                        'IdRol', IdRol,
                        'Rol', Rol
					),
                    "Ubicaciones",
                    JSON_OBJECT(
                        'IdUbicacion', IdUbicacion,
                        'Ubicacion', Ubicacion
					)
                )
            )
        )
	FROM		tmp_ResultadosFinal
    );

    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;

    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosTotal;
    DROP TEMPORARY TABLE IF EXISTS tmp_ResultadosFinal;

END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS `zsp_usuario_tiene_permiso`;

DELIMITER $$
CREATE PROCEDURE `zsp_usuario_tiene_permiso`(pToken varchar(256), pProcedimiento varchar(255), out pIdUsuario smallint, out pMensaje text)


BEGIN
    /*
        Permite determinar si un usuario, a traves de su Token, tiene los permisos necesarios para ejecutar cierto procedimiento.
    */

	SELECT  IdUsuario
    INTO    pIdUsuario
    FROM    Usuarios u
    INNER JOIN  PermisosRol pr USING(IdRol)
    INNER JOIN  Permisos p USING(IdPermiso)
    WHERE   u.Token = pToken AND u.Estado = 'A'
            AND p.Procedimiento = pProcedimiento;
    
    IF pIdUsuario IS NULL THEN
        SET pMensaje = 'ERROR_SIN_PERMISOS';
    ELSE
        SET pMensaje = 'OK';
    END IF;
END $$
DELIMITER ;

DROP PROCEDURE IF EXISTS zsp_venta_borrar;
DELIMITER $$
CREATE PROCEDURE zsp_venta_borrar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite borrar una venta.
        Controla que se encuentre en estado 'E'
        Devuelve NULL en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    DECLARE pFin tinyint;
    DECLARE pIdLineaPresupuesto bigint;

    DECLARE lineasPresupuestos_cursor CURSOR FOR
        SELECT lp.IdLineaProducto 
        FROM Presupuestos p
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'P' AND lp.IdReferencia = p.IdPresupuesto)
        WHERE p.IdVenta = pIdVenta AND lp.Estado IN ('U', 'N');
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pFin=1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        SET SQL_SAFE_UPDATES=1;
        ROLLBACK;
    END;

    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_borrar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pVentas = pIn ->> '$.Ventas';
    SET pIdVenta = COALESCE(pVentas ->> '$.IdVenta', 0);

    IF pIdVenta != 0 THEN
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
            SELECT f_generarRespuesta("ERROR_BORRAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        IF EXISTS(SELECT IdPresupuesto FROM Presupuestos WHERE IdVenta = pIdVenta) THEN
            SET SQL_SAFE_UPDATES=0;

            OPEN lineasPresupuestos_cursor;
                get_lineaPresupuesto: LOOP
                    FETCH lineasPresupuestos_cursor INTO pIdLineaPresupuesto;
                    IF pFin = 1 THEN
                        LEAVE get_lineaPresupuesto;
                    END IF;

                    UPDATE LineasProducto
                    SET Estado = 'P'
                    WHERE IdLineaProducto = pIdLineaPresupuesto;
                END LOOP get_lineaPresupuesto;
            CLOSE lineasPresupuestos_cursor;

            UPDATE Presupuestos
            SET Estado = 'C',
                IdVenta = NULL 
            WHERE IdVenta = pIdVenta;

            SET SQL_SAFE_UPDATES=1;
        END IF;


        DELETE
        FROM Ventas
        WHERE IdVenta = pIdVenta;

        SELECT f_generarRespuesta(NULL, NULL)pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_cancelar;
DELIMITER $$
CREATE PROCEDURE zsp_venta_cancelar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite cancelar una venta.
        Cancela todas las lineas de venta.
        Devuelve la venta en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    DECLARE pIdLineaProducto bigint;
    DECLARE fin int;

    DECLARE pRespuesta JSON;

    DECLARE lineasVenta_cursor CURSOR FOR
        SELECT IdLineaProducto 
        FROM Ventas v
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'V' AND lp.IdReferencia = v.IdVenta)
        WHERE v.IdVenta = pIdVenta;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
        SET SQL_SAFE_UPDATES = 1;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_cancelar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> "$.Ventas";
    SET pIdVenta = COALESCE(pVentas ->> "$.IdVenta", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT Estado FROM Ventas WHERE IdVenta = pIdVenta) NOT IN ('C', 'R') THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE Tipo = 'V' AND IdReferencia = pIdVenta AND Estado NOT IN ('P', 'C')) THEN
        SELECT f_generarRespuesta("ERROR_CANCELAR_LINEAVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'A') THEN
        IF (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'A') != (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'N') THEN
            SELECT f_generarRespuesta("ERROR_NOTACREDITOA_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF EXISTS(SELECT IdComprobante FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'B') THEN
        IF (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'B') != (SELECT SUM(Monto) FROM Comprobantes WHERE IdVenta = pIdVenta AND Tipo = 'M') THEN
            SELECT f_generarRespuesta("ERROR_NOTACREDITOB_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    START TRANSACTION;
        SET SQL_SAFE_UPDATES = 0;
        OPEN lineasVenta_cursor;
            get_lineaVenta: LOOP
                FETCH lineasVenta_cursor INTO pIdLineaProducto;
                IF fin = 1 THEN
                    LEAVE get_lineaVenta;
                END IF;

                IF EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R') THEN
                    SELECT IdLineaProducto, IdReferencia INTO @pIdLineaRemito, @pIdRemito FROM LineasProducto WHERE IdLineaProductoPadre = pIdLineaProducto AND Tipo = 'R';
                    
                    UPDATE LineasProducto
                    SET Estado = 'C',
                        FechaCancelacion = NOW()
                    WHERE IdLineaProducto = @pIdLineaRemito AND Tipo = 'R';

                    IF (SELECT Estado FROM Remitos WHERE IdRemito = @pIdRemito) = 'C' THEN
                        UPDATE Remitos
                        SET Estado = 'B'
                        WHERE IdRemito = @pIdRemito;
                    END IF;
                END IF;

                SET @pIdLineaPresupuesto = (SELECT IdLineaProductoPadre FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto);
                IF @pIdLineaPresupuesto IS NOT NULL THEN
                    UPDATE LineasProducto
                    SET Estado = 'P'
                    WHERE IdLineaProducto = @pIdLineaPresupuesto;
                END IF;
            END LOOP get_lineaVenta;
        CLOSE lineasVenta_cursor;

        UPDATE LineasProducto
        SET Estado = 'C',
            FechaCancelacion = NOW()
        WHERE IdReferencia = pIdVenta AND Tipo = 'V';

        UPDATE Presupuestos
        SET Estado = 'C',
            IdVenta = NULL
        WHERE IdVenta = pIdVenta;

        IF (SELECT Estado FROM Ventas WHERE IdVenta = pIdVenta) = 'R' THEN
            UPDATE Ventas
            SET Estado = 'C'
            WHERE IdVenta = pIdVenta;
        END IF;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ventas",  JSON_OBJECT(
                        'IdVenta', v.IdVenta,
                        'IdCliente', v.IdCliente,
                        'IdDomicilio', v.IdDomicilio,
                        'IdUbicacion', v.IdUbicacion,
                        'IdUsuario', v.IdUsuario,
                        'FechaAlta', v.FechaAlta,
                        'Observaciones', v.Observaciones,
                        'Estado', f_calcularEstadoVenta(v.IdVenta)
                    ) 
                )
             AS JSON)
			FROM	Ventas v
			WHERE	v.IdVenta = pIdVenta
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
        SET SQL_SAFE_UPDATES = 1;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_chequearPrecios;
DELIMITER $$
CREATE PROCEDURE zsp_venta_chequearPrecios(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que chequea los precios de una venta.
        En caso que los precios de las lineas de venta sean los actuales pone la venta en estado Pendiente 'C'
        caso contrario pone la venta en estado EnRevision 'R'
        Devuelve la venta en 'respuesta' o el error en 'error'
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;
    DECLARE pEstado char(1) DEFAULT 'C';

    -- Lineas Venta
    DECLARE pIdLineaProducto bigint;

    DECLARE fin tinyint;

    DECLARE pRespuesta JSON;
    
    DECLARE lineasVenta_cursor CURSOR FOR
        SELECT IdLineaProducto 
        FROM Ventas v
        INNER JOIN LineasProducto lp ON (lp.Tipo = 'V' AND lp.IdReferencia = v.IdVenta)
        WHERE v.IdVenta = pIdVenta AND lp.Estado = 'P';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET fin=1;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_chequearPrecios', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> "$.Ventas";
    SET pIdVenta = COALESCE(pVentas ->> "$.IdVenta", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    OPEN lineasVenta_cursor;
        get_lineaVenta: LOOP
            FETCH lineasVenta_cursor INTO pIdLineaProducto;
            IF fin = 1 THEN
                LEAVE get_lineaVenta;
            END IF;

            SET @pIdProductoFinal = (SELECT IdProductoFinal FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto);

            IF (SELECT PrecioUnitario FROM LineasProducto WHERE IdLineaProducto = pIdLineaProducto) != f_calcularPrecioProductoFinal(@pIdProductoFinal) THEN
                SET pEstado = 'R';
            END IF;
        END LOOP get_lineaVenta;
    CLOSE lineasVenta_cursor;

    START TRANSACTION;
        UPDATE Ventas
        SET Estado = pEstado
        WHERE IdVenta = pIdVenta;

        SET pRespuesta = (
        SELECT JSON_OBJECT(
            "Ventas",  JSON_OBJECT(
                'IdVenta', v.IdVenta,
                'IdCliente', v.IdCliente,
                'IdDomicilio', v.IdDomicilio,
                'IdUbicacion', v.IdUbicacion,
                'IdUsuario', v.IdUsuario,
                'FechaAlta', v.FechaAlta,
                'Observaciones', v.Observaciones,
                'Estado', v.Estado
            )
        )
        FROM Ventas v
        WHERE	v.IdVenta = pIdVenta
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_crear;
DELIMITER $$
CREATE PROCEDURE zsp_venta_crear(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear una venta para un cliente, especificando una direccion para el mismo. 
        Controla que exista el cliente y su direccion, y la ubicacion desde la cual se creo.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdCliente int;
    DECLARE pIdDomicilio int;
    DECLARE pObservaciones varchar(255);

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
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_crear', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> '$.Ventas';
    SET pIdCliente = COALESCE(pVentas ->> '$.IdCliente', 0);
    SET pIdDomicilio = COALESCE(pVentas ->> '$.IdDomicilio', 0);
    SET pIdUbicacion = COALESCE(pVentas ->> '$.IdUbicacion', 0);
    SET pObservaciones = COALESCE(pVentas ->> '$.Observaciones', '');

    IF NOT EXISTS (SELECT IdCliente FROM Clientes WHERE IdCliente = pIdCliente AND Estado = 'A') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdDomicilio > 0 THEN
        IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion AND Estado = 'A') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        INSERT INTO Ventas (IdVenta, IdCliente, IdDomicilio, IdUbicacion, IdUsuario, FechaAlta, Observaciones, Estado) VALUES (0, pIdCliente, NULLIF(pIdDomicilio, 0), pIdUbicacion, pIdUsuarioEjecuta, NOW(), NULLIF(pObservaciones, ''), 'E');

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ventas",  JSON_OBJECT(
                        'IdVenta', v.IdVenta,
                        'IdCliente', v.IdCliente,
                        'IdDomicilio', v.IdDomicilio,
                        'IdUbicacion', v.IdUbicacion,
                        'IdUsuario', v.IdUsuario,
                        'FechaAlta', v.FechaAlta,
                        'Observaciones', v.Observaciones,
                        'Estado', v.Estado
                        ) 
                )
             AS JSON)
			FROM	Ventas v
			WHERE	v.IdVenta = LAST_INSERT_ID()
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;    
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_dame;
DELIMITER $$
CREATE PROCEDURE zsp_venta_dame(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite pasar instanciar una venta a partir de su Id. 
        Devuelve la venta con sus lineas de venta en 'respuesta' o el error en 'error'.

    */-- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Ventas
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

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

    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_dame', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Extraigo atributos de la venta
    SET pVentas = pIn ->> "$.Ventas";
    SET pIdVenta = COALESCE(pVentas ->> "$.IdVenta", 0);

    CALL zsp_usuario_tiene_permiso(pToken, 'dame_venta_ajena', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND IdUsuario = @pIdUsuarioEjecuta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    SET @pFacturado = (
        SELECT SUM(IF(Tipo IN ('A', 'B'), Monto, -1 * Monto)) 
        FROM Comprobantes 
        WHERE IdVenta = pIdVenta AND Estado = 'A' AND Tipo IN ('A', 'B', 'M', 'N')
    );

    SET @pPagado = (
        SELECT SUM(Monto) 
        FROM Comprobantes 
        WHERE IdVenta = pIdVenta AND Estado = 'A' AND Tipo = 'R'
    );

    SET pRespuesta = (
        SELECT DISTINCT JSON_OBJECT(
            "Ventas",  JSON_OBJECT(
                'IdVenta', v.IdVenta,
                'IdCliente', v.IdCliente,
                'IdDomicilio', v.IdDomicilio,
                'IdUbicacion', v.IdUbicacion,
                'IdUsuario', v.IdUsuario,
                'FechaAlta', v.FechaAlta,
                'Observaciones', v.Observaciones,
                'Estado', f_calcularEstadoVenta(v.IdVenta),
                '_PrecioTotal', SUM(IF(lp.Estado != 'C', lp.Cantidad * lp.PrecioUnitario, 0)),
                '_Facturado', COALESCE(@pFacturado, 0),
                '_Pagado', COALESCE(@pPagado, 0)
            ),
            "Clientes", JSON_OBJECT(
                'Nombres', c.Nombres,
                'Apellidos', c.Apellidos,
                'RazonSocial', c.RazonSocial
            ),
            "Domicilios", JSON_OBJECT(
                'Domicilio', d.Domicilio
            ),
            "Usuarios", JSON_OBJECT(
                "Nombres", u.Nombres,
                "Apellidos", u.Apellidos
            ),
            "Ubicaciones", JSON_OBJECT(
                "Ubicacion", ub.Ubicacion
            ),
            "LineasVenta", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                JSON_OBJECT(
                    "LineasProducto", JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario,
                        "Estado", f_dameEstadoLineaVenta(lp.IdLineaProducto),
                        "_IdRemito", (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProductoPadre = lp.IdLineaProducto AND Tipo = 'R'),
                        "_IdOrdenProduccion", (SELECT IdReferencia FROM LineasProducto WHERE IdLineaProductoPadre = lp.IdLineaProducto AND Tipo = 'O')
                    ),
                    "ProductosFinales", JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                    "Productos",JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "IdTipoProducto", pr.IdTipoProducto,
                        "Producto", pr.Producto
                    ),
                    "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                    "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
                )
            ), JSON_ARRAY())
        )
        FROM Ventas v
        INNER JOIN Usuarios u ON u.IdUsuario = v.IdUsuario
        INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
        LEFT JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
        INNER JOIN Ubicaciones ub ON ub.IdUbicacion = v.IdUbicacion
        LEFT JOIN LineasProducto lp ON v.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
        LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
        LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
        LEFT JOIN Telas te ON pf.IdTela = te.IdTela
        LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
        WHERE	v.IdVenta = pIdVenta
    );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_generarOrdenProduccion;
DELIMITER $$
CREATE PROCEDURE zsp_venta_generarOrdenProduccion(pIn JSON)
SALIR: BEGIN
    /*
        Permite a los usuarios generar una orden de producción para una venta

        pIn = {
            LineasVenta = [
                {
                    Cantidad,
                    IdProductoFinal,
                    IdLineasPadre,
                }
                ...
            ],
            LineasOrdenProduccion = [
                {
                    Cantidad,
                    IdProductoFinal,
                    IdLineasPadre,
                }
                ...
            ],
            Observaciones,
        }
    */
    
    -- Control de permisos
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    DECLARE pLineasVenta JSON;
    DECLARE pLineaOrdenProduccionVenta JSON;
    DECLARE pLineasOrdenProduccion JSON;
    DECLARE pCantidad INT;
    DECLARE pIdProductoFinal INT;
    DECLARE pObservaciones VARCHAR(255);
    DECLARE pIdLineasPadre JSON;

    DECLARE pLongitud INT UNSIGNED;
    DECLARE pIndex INT UNSIGNED DEFAULT 0;
    DECLARE pLongitudInterna INT UNSIGNED;
    DECLARE pInternalIndex INT UNSIGNED DEFAULT 0;
    DECLARE pCantidadRestante INT DEFAULT 0;
    DECLARE pCantidadActual INT DEFAULT 0;
    DECLARE pIdLineaVentaPadre BIGINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;

    SET pToken = pIn->>"$.UsuariosEjecuta.Token";
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_generarOrdenProduccion', pIdUsuarioEjecuta, pMensaje);
    
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pLineasVenta = COALESCE(pIn ->> "$.LineasVenta", JSON_ARRAY());
    SET pLineasOrdenProduccion = COALESCE(pIn ->> "$.LineasOrdenProduccion", JSON_ARRAY());
    SET pObservaciones = pIn ->> "$.Observaciones";
    SET pLongitud = JSON_LENGTH(pLineasVenta);

    START TRANSACTION;

        INSERT INTO OrdenesProduccion (IdOrdenProduccion, IdUsuario, FechaAlta, Observaciones, Estado)
        VALUES (0, pIdUsuarioEjecuta, NOW(), pObservaciones, 'P');
        SET @pIdOrdenProduccion = LAST_INSERT_ID();

        WHILE pIndex < pLongitud DO
            SET pLineaOrdenProduccionVenta = JSON_EXTRACT(pLineasVenta, CONCAT("$[", pIndex, "]"));
            SET pCantidad = COALESCE(pLineaOrdenProduccionVenta->>"$.Cantidad",-1);
            SET pIdProductoFinal = pLineaOrdenProduccionVenta->>"$.IdProductoFinal";
            SET pIdLineasPadre = COALESCE(pLineaOrdenProduccionVenta->>"$.IdLineasPadre",JSON_ARRAY());

            SET pLongitud = JSON_LENGTH(pIdLineasPadre);
            WHILE pInternalIndex < pLongitud DO
                SET pIdLineaVentaPadre = JSON_EXTRACT(pIdLineasPadre, CONCAT("$[", pInternalIndex, "]"));
                SET pCantidadActual = (
                    SELECT Cantidad
                    FROM LineasProducto 
                    WHERE 
                        Tipo = 'V' 
                        AND IdReferencia = pIdLineaVentaPadre
                        AND f_dameEstadoLineaVenta(IdLineaProducto) = 'P'
                );

                SET pCantidadRestante := pCantidadRestante - pCantidadActual;
                IF pCantidadRestante < 0 THEN
                    SELECT f_generarRespuesta("ERROR_ORDEN_PRODUCCION_CANTIDAD_LINEA_VENTA", NULL) pOut;
                    LEAVE SALIR;
                END IF;

                INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, pIdLineaVentaPadre, pIdProductoFinal, NULL, @pIdOrdenProduccion, 'O', NULL, pCantidad, NOW(), NULL, 'F');

                SET pInternalIndex := pInternalIndex + 1;
            END WHILE;

            IF pCantidadRestante > 0 THEN
                INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) 
                VALUES(0, NULL, pIdProductoFinal, NULL, @pIdOrdenProduccion, 'O', NULL, pCantidad, NOW(), NULL, 'F');
            END IF;
            
            SET pIndex := pIndex + 1;
        END WHILE;

        SET pRespuesta = (
            SELECT CAST( JSON_OBJECT(
                "OrdenesProduccion",  JSON_OBJECT(
                    'IdOrdenProduccion', op.IdOrdenProduccion,
                    'IdUsuario', op.IdUsuario,
                    'FechaAlta', op.FechaAlta,
                    'Observaciones', op.Observaciones,
                    'Estado', f_dameEstadoOrdenProduccion(op.IdOrdenProduccion)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "LineasOrdenProduccion", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "IdLineaProductoPadre", lp.IdLineaProductoPadre,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "Estado", f_dameEstadoLineaOrdenProduccion(lp.IdLineaProducto)
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            ) AS JSON)
            FROM OrdenesProduccion op
            INNER JOIN Usuarios u ON u.IdUsuario = op.IdUsuario
            LEFT JOIN LineasProducto lp ON op.IdOrdenProduccion = lp.IdReferencia AND lp.Tipo = 'O'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE IdOrdenProduccion = @pIdOrdenProduccion
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_generar_remito;
DELIMITER $$
CREATE PROCEDURE zsp_venta_generar_remito(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite crear un remito a partir de una venta.
        Deben especificarse las lineas de venta a utilizarse.
        Devuelve el remito en 'respuesta' o el error en 'error'.
        LineasVenta : [
            {
                IdLineaVenta,
                IdUbicacion,
            }
        ]
    */
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pIdVenta int;
    DECLARE pIdDomicilio int;
    DECLARE pLineasVenta JSON;
    DECLARE pLineaVenta JSON;
    DECLARE pIdLineaVenta bigint;
    DECLARE pIdProductoFinal int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pCantidadSolicitada tinyint;
    DECLARE pIdRemito int DEFAULT 0;
    DECLARE pCantidad tinyint;
    DECLARE pIndice tinyint DEFAULT 0;
    DECLARE pLongitud tinyint DEFAULT 0;
    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_generar_remito', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pIdVenta = COALESCE(pIn->>'$.Ventas.IdVenta', 0);
    SET pIdDomicilio = COALESCE(pIn->>'$.Ventas.IdDomicilio', 0);
    SET pLineasVenta = COALESCE(pIn->>'$.LineasVenta', JSON_ARRAY());
    
    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_VENTA_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Si la venta no se encuentra en estado 'Pendiente'
    IF (SELECT f_calcularEstadoVenta(pIdVenta)) != 'C' THEN
        SELECT f_generarRespuesta("ERROR_VENTA_REMITO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS(SELECT dc.IdDomicilio FROM DomiciliosCliente dc INNER JOIN Clientes c ON c.IdCliente = dc.IdCliente INNER JOIN Ventas v ON v.IdCliente = c.IdCliente WHERE v.IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_DOMICILIO_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF JSON_LENGTH(pLineasVenta) = 0 THEN
        SELECT f_generarRespuesta("ERROR_SIN_LINEASVENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
    
        WHILE pIndice < JSON_LENGTH(pLineasVenta) DO
            SET pLineaVenta = JSON_EXTRACT(pLineasVenta, CONCAT("$[", pIndice, "]"));
            SET pIdLineaVenta = COALESCE(pLineaVenta->>'$.IdLineaProducto', 0);
            SET pIdUbicacion = COALESCE(pLineaVenta->>'$.IdUbicacion', 0);
            SET pCantidadSolicitada = COALESCE(pLineaVenta->>'$.Cantidad', 0);

            IF NOT EXISTS(SELECT IdLineaProducto FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta AND IdReferencia = pIdVenta AND Tipo = 'V' AND Estado = 'P') THEN
                SELECT f_generarRespuesta("ERROR_LINEAVENTA_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF NOT EXISTS(SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
                SELECT f_generarRespuesta("ERROR_UBICACION_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pCantidadSolicitada = 0 THEN
                SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA", NULL) pOut;
                LEAVE SALIR;
            END IF;

            SELECT IdProductoFinal, Cantidad INTO pIdProductoFinal, pCantidad FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta;

            IF f_dameEstadoLineaVenta(pIdLineaVenta) != 'P' THEN
                SELECT f_generarRespuesta("ERROR_LINEAVENTA_ESTADO_REMITO", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pCantidadSolicitada > pCantidad THEN
                SELECT f_generarRespuesta("ERROR_CANTIDAD_INVALIDA_LINEASVENTA", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF NOT EXISTS(SELECT IdProductoFinal FROM ProductosFinales WHERE IdProductoFinal = pIdProductoFinal AND Estado = 'A') THEN
                SELECT f_generarRespuesta("ERROR_PRODUCTOFINAL_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            -- Creo un remito de salida en estado 'En Creación'
            IF pIndice = 0 THEN
                INSERT INTO Remitos (IdRemito, IdUbicacion, IdUsuario, Tipo, FechaEntrega, FechaAlta, Observaciones, Estado) VALUES(0, NULL, pIdUsuarioEjecuta, 'S', NULL, NOW(), NULL, 'E');
                SET pIdRemito = LAST_INSERT_ID();
            END IF;

            IF pIdRemito = 0 THEN
                SELECT f_generarRespuesta("ERROR_REMITO_NOEXISTE", NULL) pOut;
                LEAVE SALIR;
            END IF;

            IF pCantidadSolicitada < pCantidad THEN
                -- Debemos partir la linea de venta.
                UPDATE LineasProducto
                SET Cantidad = pCantidadSolicitada
                WHERE IdLineaProducto = pIdLineaVenta;

                INSERT INTO LineasProducto SELECT 0, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado FROM LineasProducto WHERE IdLineaProducto = pIdLineaVenta; 

                UPDATE LineasProducto
                SET Cantidad = pCantidad - pCantidadSolicitada
                WHERE IdLineaProducto = LAST_INSERT_ID();

            END IF;

            INSERT INTO LineasProducto (IdLineaProducto, IdLineaProductoPadre, IdProductoFinal, IdUbicacion, IdReferencia, Tipo, PrecioUnitario, Cantidad, FechaAlta, FechaCancelacion, Estado) VALUES(0, pIdLineaVenta, pIdProductoFinal, pIdUbicacion, pIdRemito, 'R', NULL, pCantidadSolicitada, NOW(), NULL, 'P');
            
            SET pIndice = pIndice + 1;
        END WHILE;

        SET @pIdDomicilio = (SELECT IdDomicilio FROM Ventas WHERE IdVenta = pIdVenta);

        IF @pIdDomicilio IS NULL OR @pIdDomicilio != pIdDomicilio THEN
            UPDATE Ventas
            SET IdDomicilio = pIdDomicilio
            WHERE IdVenta = pIdVenta;
        END IF;

        UPDATE Remitos
        SET Estado = 'C'
        WHERE IdRemito = pIdRemito;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Remitos",  JSON_OBJECT(
                    "IdRemito", r.IdRemito,
                    "IdUbicacion", r.IdUbicacion,
                    "IdUsuario", r.IdUsuario,
                    "Tipo", r.Tipo,
                    "FechaEntrega", r.FechaEntrega,
                    "FechaAlta", r.FechaAlta,
                    "Observaciones", r.Observaciones,
                    "Estado", f_calcularEstadoRemito(r.IdRemito)
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ue.Ubicacion
                ),
                "LineasRemito", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "IdUbicacion", lp.IdUbicacion,
                            "Estado", lp.Estado
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Ubicaciones", JSON_OBJECT(
                            "Ubicacion", us.Ubicacion
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            )
            FROM Remitos r
            INNER JOIN Usuarios u ON u.IdUsuario = r.IdUsuario
            LEFT JOIN Ubicaciones ue ON ue.IdUbicacion = r.IdUbicacion
            LEFT JOIN LineasProducto lp ON r.IdRemito = lp.IdReferencia AND lp.Tipo = 'R'
            LEFT JOIN Ubicaciones us ON lp.IdUbicacion = us.IdUbicacion
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	r.IdRemito = pIdRemito
        );

        SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_modificar_domicilio;
DELIMITER $$
CREATE PROCEDURE zsp_venta_modificar_domicilio(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar el domicilio de una venta.
        En caso que este en estado Pendiente, solamente modificara el domicilio si aún no tiene uno seteado.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */
    DECLARE pIdVenta int;
    DECLARE pIdDomicilio int;
    
    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pRespuesta JSON;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_modificar_domicilio', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pIdVenta = COALESCE(pIn->>"$.Ventas.IdVenta", 0);
    SET pIdDomicilio = COALESCE(pIn->>"$.Ventas.IdDomicilio", 0);

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF (SELECT IdDomicilio FROM Ventas WHERE IdVenta = pIdVenta) IS NOT NULL THEN
        IF (SELECT Estado FROM Ventas WHERE IdVenta = pIdVenta) != 'E' THEN
            SELECT f_generarRespuesta("ERROR_MODIFICAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        IF f_calcularEstadoVenta(pIdVenta) NOT IN('E', 'R', 'C') THEN
            SELECT f_generarRespuesta("ERROR_MODIFICAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF NOT EXISTS(SELECT dc.IdDomicilio FROM Ventas v INNER JOIN Clientes c ON c.IdCliente = v.IdCliente INNER JOIN DomiciliosCliente dc ON dc.IdCliente = c.IdCliente WHERE v.IdVenta = pIdVenta AND dc.IdDomicilio = pIdDomicilio) THEN
        SELECT f_generarRespuesta("ERROR_DOMICILIO_NOEXISTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;

        UPDATE Ventas
        SET IdDomicilio = pIdDomicilio
        WHERE IdVenta = pIdVenta;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ventas",  JSON_OBJECT(
                        'IdVenta', v.IdVenta,
                        'IdCliente', v.IdCliente,
                        'IdDomicilio', v.IdDomicilio,
                        'IdUbicacion', v.IdUbicacion,
                        'IdUsuario', v.IdUsuario,
                        'FechaAlta', v.FechaAlta,
                        'Observaciones', v.Observaciones,
                        'Estado', v.Estado
                    ) 
                )
             AS JSON)
			FROM	Ventas v
			WHERE	v.IdVenta = pIdVenta
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;

END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_modificar;
DELIMITER $$
CREATE PROCEDURE zsp_venta_modificar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite modificar una venta.
        Controla que se encuentre en estado E.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pVentas JSON;
    DECLARE pIdVenta int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pIdCliente int;
    DECLARE pIdDomicilio int;
    DECLARE pObservaciones varchar(255);

    -- Respuesta
    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_modificar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> '$.Ventas';
    SET pIdVenta = COALESCE(pVentas ->> '$.IdVenta', 0);
    SET pIdCliente = COALESCE(pVentas ->> '$.IdCliente', 0);
    SET pIdUbicacion = COALESCE(pVentas ->> '$.IdUbicacion', 0);
    SET pIdDomicilio = COALESCE(pVentas ->> '$.IdDomicilio', 0);
    SET pObservaciones = COALESCE(pVentas ->> '$.Observaciones', '');

    IF pIdVenta != 0 THEN
        IF NOT EXISTS (SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'E') THEN
            SELECT f_generarRespuesta("ERROR_MODIFICAR_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;
    ELSE
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF NOT EXISTS (SELECT c.IdCliente FROM Clientes c INNER JOIN Ventas v ON v.IdCliente = c.IdCliente WHERE c.IdCliente = pIdCliente AND v.IdVenta = pIdVenta) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_CLIENTE", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pIdDomicilio > 0 THEN
        IF NOT EXISTS (SELECT IdDomicilio FROM DomiciliosCliente WHERE IdDomicilio = pIdDomicilio AND IdCliente = pIdCliente) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_DOMICILIO", NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF NOT EXISTS (SELECT IdUbicacion FROM Ubicaciones WHERE IdUbicacion = pIdUbicacion) THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_UBICACION", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Ventas
        SET
            IdCliente = pIdCliente,
            IdDomicilio = NULLIF(pIdDomicilio, 0),
            IdUbicacion = pIdUbicacion,
            Observaciones = NULLIF(pObservaciones, '')
        WHERE IdVenta = pIdVenta;

        SET pRespuesta = (
			SELECT CAST(
                JSON_OBJECT(
                    "Ventas",  JSON_OBJECT(
                        'IdVenta', v.IdVenta,
                        'IdCliente', v.IdCliente,
                        'IdDomicilio', v.IdDomicilio,
                        'IdUbicacion', v.IdUbicacion,
                        'IdUsuario', v.IdUsuario,
                        'FechaAlta', v.FechaAlta,
                        'Observaciones', v.Observaciones,
                        'Estado', v.Estado
                        ) 
                )
             AS JSON)
			FROM	Ventas v
			WHERE	v.IdVenta = pIdVenta
        );
	
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_venta_revisar;
DELIMITER $$
CREATE PROCEDURE zsp_venta_revisar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite que aceptar una venta que esta en estado En Revisio.
        Cambia el estado de la venta de 'R' a 'C'.
        Devuelve la venta en 'respuesta' o el error en 'error'.
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    DECLARE pRespuesta JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_venta_revisar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;
    
    SET pVentas = pIn ->> "$.Ventas";
    SET pIdVenta = COALESCE(pVentas ->> "$.IdVenta");

    IF NOT EXISTS(SELECT IdVenta FROM Ventas WHERE IdVenta = pIdVenta AND Estado = 'R') THEN
        SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
        LEAVE SALIR;
    END IF;

    START TRANSACTION;
        UPDATE Ventas
        SET Estado = 'C'
        WHERE IdVenta = pIdVenta;

        SET pRespuesta = (
            SELECT JSON_OBJECT(
                "Ventas",  JSON_OBJECT(
                    'IdVenta', v.IdVenta,
                    'IdCliente', v.IdCliente,
                    'IdDomicilio', v.IdDomicilio,
                    'IdUbicacion', v.IdUbicacion,
                    'IdUsuario', v.IdUsuario,
                    'FechaAlta', v.FechaAlta,
                    'Observaciones', v.Observaciones,
                    'Estado', f_calcularEstadoVenta(v.IdVenta)
                ),
                "Clientes", JSON_OBJECT(
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial
                ),
                "Domicilios", JSON_OBJECT(
                    'Domicilio', d.Domicilio
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasVenta", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            )
            FROM Ventas v
            INNER JOIN Usuarios u ON u.IdUsuario = v.IdUsuario
            INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
            INNER JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
            INNER JOIN Ubicaciones ub ON ub.IdUbicacion = v.IdUbicacion
            LEFT JOIN LineasProducto lp ON v.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	v.IdVenta = pIdVenta
        );
		SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
    COMMIT;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_ventas_buscar;
DELIMITER $$
CREATE PROCEDURE zsp_ventas_buscar(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite buscar una venta
        - Usuario (0: Todos)
        - Cliente (0: Todos)
        - Estado (E:En Creación - C:Pendiente - R:En revisión - N: Entregado - A:Cancelado - T:Todos) //Revisar esto
        - Producto(0:Todos),
        - Telas(0:Todos),
        - Lustre (0: Todos),
        - Ubicación (0:Todas las ubicaciones)
        - Periodo de fechas
        Devuelve una lista de ventas en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    -- Venta
    DECLARE pIdUsuario smallint;
    DECLARE pIdCliente int;
    DECLARE pIdUbicacion tinyint;
    DECLARE pEstado char(1);

    -- Paginacion
    DECLARE pPagina int;
    DECLARE pLongitudPagina int;
    DECLARE pCantidadTotal int;
    DECLARE pOffset int;

    -- Parametros busqueda
    DECLARE pFechaInicio datetime;
    DECLARE pFechaFin datetime;
    DECLARE pFechaAux datetime;

    -- Productos Final
    DECLARE pIdProducto int;
    DECLARE pIdLustre tinyint;
    DECLARE pIdTela smallint;

    -- Para la respuesta
    DECLARE pRespuesta JSON;
    DECLARE pResultado JSON;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SHOW ERRORS;
        SELECT f_generarRespuesta("ERROR_TRANSACCION", NULL) pOut;
        ROLLBACK;
    END;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ventas_buscar', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    -- Atributos ventas
    SET pIdCliente = COALESCE(pIn ->> "$.Ventas.IdCliente", 0);
    SET pIdUsuario = COALESCE(pIn ->> "$.Ventas.IdUsuario", 0);
    SET pIdUbicacion = COALESCE(pIn ->> "$.Ventas.IdUbicacion", 0);
    SET pEstado = TRIM(COALESCE(pIn ->> "$.Ventas.Estado", "T"));

    -- Atributos productos finales
    SET pIdProducto = COALESCE(pIn ->> "$.ProductosFinales.IdProducto", 0);
    SET pIdTela = COALESCE(pIn ->> "$.ProductosFinales.IdTela", 0);
    SET pIdLustre = COALESCE(pIn ->> "$.ProductosFinales.IdLustre", 0);

    -- Atributos paginaciones
    SET pPagina = COALESCE(pIn ->> '$.Paginaciones.Pagina', 1);
    SET pLongitudPagina = COALESCE(pIn ->> '$.Paginaciones.LongitudPagina', 0);

    -- Atributos parametros de busqueda
    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaInicio", '')) > 0 THEN
        SET pFechaInicio = pIn ->> "$.ParametrosBusqueda.FechaInicio";
    END IF;
    IF CHAR_LENGTH(COALESCE(pIn ->>"$.ParametrosBusqueda.FechaFin", '')) = 0 THEN
        SET pFechaFin = NOW();
    ELSE
        SET pFechaFin = CONCAT(pIn ->>"$.ParametrosBusqueda.FechaFin"," 23:59:59");
    END IF;

    -- Arreglo el orden de las fechas
    IF pFechaInicio IS NOT NULL AND pFechaFin < pFechaInicio THEN
        SET pFechaAux = pFechaInicio;
        SET pFechaInicio = pFechaFin;
        SET pFechaFin = pFechaAux;
    END IF;

    CALL zsp_usuario_tiene_permiso(pToken, 'buscar_ventas_ajenas', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        IF pIdUsuarioEjecuta <> pIdUsuario THEN
            SELECT f_generarRespuesta(pMensaje, NULL) pOut;
            LEAVE SALIR;
        END IF;
    END IF;

    IF pEstado NOT IN ('E', 'C', 'R', 'N', 'A','T') THEN
        SELECT f_generarRespuesta("ERROR_ESTADO_INVALIDO", NULL) pOut;
        LEAVE SALIR;
    END IF;

    IF pLongitudPagina = 0 THEN
        SET pLongitudPagina = (SELECT Valor FROM Empresa WHERE Parametro = 'LONGITUDPAGINA');
    END IF;
    
    SET pOffset = (pPagina - 1) * pLongitudPagina;

    DROP TEMPORARY TABLE IF EXISTS tmp_Ventas;
    DROP TEMPORARY TABLE IF EXISTS tmp_VentasPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ventasPrecios;
    
    -- Ventas que cumplen con las condiciones sin paginar
    CREATE TEMPORARY TABLE tmp_Ventas
    AS SELECT v.*
    FROM Ventas v
    LEFT JOIN LineasProducto lp ON (lp.IdReferencia = v.IdVenta AND lp.Tipo = 'V')
    LEFT JOIN ProductosFinales pf ON (lp.IdProductoFinal = pf.IdProductoFinal)
	WHERE (v.IdUsuario = pIdUsuario OR pIdUsuario = 0)
    AND (v.IdCliente = pIdCliente OR pIdCliente = 0)
    AND (v.IdUbicacion = pIdUbicacion OR pIdUbicacion = 0)
    AND (
            f_calcularEstadoVenta(v.IdVenta) = pEstado
            OR pEstado = 'T'
        )
    AND ((pFechaInicio IS NULL AND v.FechaAlta <= pFechaFin) OR (pFechaInicio IS NOT NULL AND v.FechaAlta BETWEEN pFechaInicio AND pFechaFin))
    AND (pf.IdProducto = pIdProducto OR pIdProducto = 0)
    AND (pf.IdTela = pIdTela OR pIdTela = 0)
    AND (pf.IdLustre = pIdLustre OR pIdLustre = 0)
    ORDER BY v.IdVenta DESC;
    
    -- Para devolver CantidadTotal en Paginaciones
    SET pCantidadTotal = (SELECT COUNT(DISTINCT IdVenta) FROM tmp_Ventas);
    
    -- Ventas paginadas
    CREATE TEMPORARY TABLE tmp_VentasPaginadas AS
    SELECT DISTINCT IdVenta, IdCliente, IdDomicilio,IdUbicacion, IdUsuario, FechaAlta, Observaciones, Estado
    FROM tmp_Ventas
    ORDER BY IdVenta DESC
    LIMIT pOffset, pLongitudPagina;


    -- Resultset de las ventas con sus montos totales
    CREATE TEMPORARY TABLE tmp_ventasPrecios AS
    SELECT  
		tmpv.*, 
        SUM(IF(lp.Estado != 'C', lp.Cantidad * lp.PrecioUnitario, 0)) AS PrecioTotal, 
        IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
			JSON_OBJECT(
                "LineasProducto",  
                    JSON_OBJECT(
                        "IdLineaProducto", lp.IdLineaProducto,
                        "IdProductoFinal", lp.IdProductoFinal,
                        "Cantidad", lp.Cantidad,
                        "PrecioUnitario", lp.PrecioUnitario
                    ),
                "ProductosFinales",
                    JSON_OBJECT(
                        "IdProductoFinal", pf.IdProductoFinal,
                        "IdProducto", pf.IdProducto,
                        "IdTela", pf.IdTela,
                        "IdLustre", pf.IdLustre,
                        "FechaAlta", pf.FechaAlta
                    ),
                "Productos",
                    JSON_OBJECT(
                        "IdProducto", pr.IdProducto,
                        "Producto", pr.Producto
                    ),
                "Telas",IF (te.IdTela  IS NOT NULL,
                    JSON_OBJECT(
                        "IdTela", te.IdTela,
                        "Tela", te.Tela
                    ),NULL),
                "Lustres",IF (lu.IdLustre  IS NOT NULL,
                    JSON_OBJECT(
                        "IdLustre", lu.IdLustre,
                        "Lustre", lu.Lustre
                    ), NULL)
			)
		), JSON_ARRAY()) AS LineasVenta
    FROM    tmp_VentasPaginadas tmpv
    LEFT JOIN LineasProducto lp ON tmpv.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
    LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
    LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
    LEFT JOIN Telas te ON pf.IdTela = te.IdTela
    LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
    GROUP BY tmpv.IdVenta, tmpv.IdCliente, tmpv.IdDomicilio, tmpv.IdUbicacion, tmpv.IdUsuario, tmpv.FechaAlta, tmpv.Observaciones, tmpv.Estado;

    SET SESSION GROUP_CONCAT_MAX_LEN=150000;

    SET pRespuesta = JSON_OBJECT(
            "Paginaciones", JSON_OBJECT(
                "Pagina", pPagina,
                "LongitudPagina", pLongitudPagina,
                "CantidadTotal", pCantidadTotal
            ),
            "resultado", (
                SELECT CAST(CONCAT('[', COALESCE(GROUP_CONCAT(JSON_OBJECT(
                    "Ventas",  JSON_OBJECT(
                        'IdVenta', tmpv.IdVenta,
                        'IdCliente', tmpv.IdCliente,
                        'IdUbicacion', tmpv.IdUbicacion,
                        'IdUsuario', tmpv.IdUsuario,
                        'FechaAlta', tmpv.FechaAlta,
                        'Observaciones', tmpv.Observaciones,
                        'Estado', f_calcularEstadoVenta(tmpv.IdVenta),
                        '_PrecioTotal', tmpv.PrecioTotal
                    ),
                    "Clientes", JSON_OBJECT(
                        'Nombres', c.Nombres,
                        'Apellidos', c.Apellidos,
                        'RazonSocial', c.RazonSocial
                    ),
                    "Usuarios", JSON_OBJECT(
                        "Nombres", u.Nombres,
                        "Apellidos", u.Apellidos
                    ),
                    "Ubicaciones", JSON_OBJECT(
                        "Ubicacion", ub.Ubicacion
                    ),
                    "LineasVenta", tmpv.LineasVenta
                ) ORDER BY tmpv.FechaAlta DESC),''), ']') AS JSON)
                FROM tmp_ventasPrecios tmpv
                INNER JOIN Clientes c ON tmpv.IdCliente = c.IdCliente
                INNER JOIN Usuarios u ON tmpv.IdUsuario = u.IdUsuario
                INNER JOIN Ubicaciones ub ON tmpv.IdUbicacion = ub.IdUbicacion
            )
    );
    SET SESSION GROUP_CONCAT_MAX_LEN=15000;
        
    SELECT f_generarRespuesta(NULL, pRespuesta) pOut;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_Ventas;
    DROP TEMPORARY TABLE IF EXISTS tmp_VentasPaginadas;
    DROP TEMPORARY TABLE IF EXISTS tmp_ventasPrecios;
END $$
DELIMITER ;
DROP PROCEDURE IF EXISTS zsp_ventas_dame_multiple;
DELIMITER $$
CREATE PROCEDURE zsp_ventas_dame_multiple(pIn JSON)
SALIR: BEGIN
    /*
        Procedimiento que permite instancias mas de una venta a partir de sus Id.
        Devuelve las ventas con sus lineas de ventas en 'respuesta' o el error en 'error'
    */

    -- Control de permisos
    DECLARE pUsuariosEjecuta JSON;
    DECLARE pIdUsuarioEjecuta smallint;
    DECLARE pToken varchar(256);
    DECLARE pMensaje text;

    DECLARE pVentas JSON;
    DECLARE pIdVenta int;

    DECLARE pLongitud int unsigned;
    DECLARE pIndex int unsigned DEFAULT 0;

    DECLARE pRespuesta JSON;
    
    SET pUsuariosEjecuta = pIn ->> "$.UsuariosEjecuta";
    SET pToken = pUsuariosEjecuta ->> "$.Token";
    
    CALL zsp_usuario_tiene_permiso(pToken, 'zsp_ventas_dame_multiple', pIdUsuarioEjecuta, pMensaje);
    IF pMensaje != 'OK' THEN
        SELECT f_generarRespuesta(pMensaje, NULL) pOut;
        LEAVE SALIR;
    END IF;

    SET pVentas = pIn ->> "$.Ventas";
    SET pLongitud = JSON_LENGTH(pVentas);
    SET pRespuesta = JSON_ARRAY();

    WHILE pIndex < pLongitud DO
        SET pIdVenta = JSON_EXTRACT(pVentas, CONCAT("$[", pIndex, "]"));

        IF NOT EXISTS(SELECT pIdVenta FROM Ventas WHERE IdVenta = pIdVenta) THEN
            SELECT f_generarRespuesta("ERROR_NOEXISTE_VENTA", NULL) pOut;
            LEAVE SALIR;
        END IF;

        SET @pVenta = (
            SELECT JSON_OBJECT(
                "Ventas",  JSON_OBJECT(
                    'IdVenta', v.IdVenta,
                    'IdCliente', v.IdCliente,
                    'IdDomicilio', v.IdDomicilio,
                    'IdUbicacion', v.IdUbicacion,
                    'IdUsuario', v.IdUsuario,
                    'FechaAlta', v.FechaAlta,
                    'Observaciones', v.Observaciones,
                    'Estado', f_calcularEstadoVenta(v.IdVenta),
                    '_PrecioTotal', SUM(lp.Cantidad * lp.PrecioUnitario)
                ),
                "Clientes", JSON_OBJECT(
                    'Nombres', c.Nombres,
                    'Apellidos', c.Apellidos,
                    'RazonSocial', c.RazonSocial
                ),
                "Domicilios", JSON_OBJECT(
                    'Domicilio', d.Domicilio
                ),
                "Usuarios", JSON_OBJECT(
                    "Nombres", u.Nombres,
                    "Apellidos", u.Apellidos
                ),
                "Ubicaciones", JSON_OBJECT(
                    "Ubicacion", ub.Ubicacion
                ),
                "LineasVenta", IF(COUNT(lp.IdLineaProducto) > 0, JSON_ARRAYAGG(
                    JSON_OBJECT(
                        "LineasProducto", JSON_OBJECT(
                            "IdLineaProducto", lp.IdLineaProducto,
                            "IdProductoFinal", lp.IdProductoFinal,
                            "Cantidad", lp.Cantidad,
                            "PrecioUnitario", lp.PrecioUnitario,
                            "Estado", f_dameEstadoLineaVenta(lp.IdLineaProducto)
                        ),
                        "ProductosFinales", JSON_OBJECT(
                            "IdProductoFinal", pf.IdProductoFinal,
                            "IdProducto", pf.IdProducto,
                            "IdTela", pf.IdTela,
                            "IdLustre", pf.IdLustre,
                            "FechaAlta", pf.FechaAlta
                        ),
                        "Productos",JSON_OBJECT(
                            "IdProducto", pr.IdProducto,
                            "IdTipoProducto", pr.IdTipoProducto,
                            "Producto", pr.Producto
                        ),
                        "Telas",IF (te.IdTela  IS NOT NULL,
                        JSON_OBJECT(
                            "IdTela", te.IdTela,
                            "Tela", te.Tela
                        ),NULL),
                        "Lustres",IF (lu.IdLustre  IS NOT NULL,
                        JSON_OBJECT(
                            "IdLustre", lu.IdLustre,
                            "Lustre", lu.Lustre
                        ), NULL)
                    )
                ), JSON_ARRAY())
            )
            FROM Ventas v
            INNER JOIN Usuarios u ON u.IdUsuario = v.IdUsuario
            INNER JOIN Clientes c ON c.IdCliente = v.IdCliente
            LEFT JOIN Domicilios d ON d.IdDomicilio = v.IdDomicilio
            INNER JOIN Ubicaciones ub ON ub.IdUbicacion = v.IdUbicacion
            LEFT JOIN LineasProducto lp ON v.IdVenta = lp.IdReferencia AND lp.Tipo = 'V'
            LEFT JOIN ProductosFinales pf ON lp.IdProductoFinal = pf.IdProductoFinal
            LEFT JOIN Productos pr ON pf.IdProducto = pr.IdProducto
            LEFT JOIN Telas te ON pf.IdTela = te.IdTela
            LEFT JOIN Lustres lu ON pf.IdLustre = lu.IdLustre
            WHERE	v.IdVenta = pIdVenta
        );

        SET pRespuesta = JSON_ARRAY_INSERT(pRespuesta, CONCAT('$[', pIndex, ']'), CAST(@pVenta AS JSON));
        SET pIndex = pIndex + 1;
    END WHILE;
    SELECT f_generarRespuesta(NULL, pRespuesta) AS pOut;
END $$
DELIMITER ;
