--
-- ER/Studio 8.0 SQL Code Generation
-- Company :      ZMGestion
-- Project :      modeloRelacional.DM1
-- Author :       ZMGestion
--
-- Date Created : Monday, June 08, 2020 15:57:02
-- Target DBMS : MySQL 5.x
--

CREATE DATABASE IF NOT EXISTS `ZMGestion`;
USE `ZMGestion`;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS CategoriasProducto
;
DROP TABLE IF EXISTS Ciudades
;
DROP TABLE IF EXISTS Clientes
;
DROP TABLE IF EXISTS Comprobantes
;
DROP TABLE IF EXISTS Domicilios
;
DROP TABLE IF EXISTS DomiciliosCliente
;
DROP TABLE IF EXISTS Empresa
;
DROP TABLE IF EXISTS GruposProducto
;
DROP TABLE IF EXISTS LineasProducto
;
DROP TABLE IF EXISTS Lustres
;
DROP TABLE IF EXISTS Observaciones
;
DROP TABLE IF EXISTS OrdenesProduccion
;
DROP TABLE IF EXISTS Paises
;
DROP TABLE IF EXISTS Permisos
;
DROP TABLE IF EXISTS PermisosRol
;
DROP TABLE IF EXISTS Precios
;
DROP TABLE IF EXISTS Presupuestos
;
DROP TABLE IF EXISTS Productos
;
DROP TABLE IF EXISTS ProductosFinales
;
DROP TABLE IF EXISTS Provincias
;
DROP TABLE IF EXISTS Remitos
;
DROP TABLE IF EXISTS Roles
;
DROP TABLE IF EXISTS Tareas
;
DROP TABLE IF EXISTS Telas
;
DROP TABLE IF EXISTS TiposDocumento
;
DROP TABLE IF EXISTS TiposProducto
;
DROP TABLE IF EXISTS Ubicaciones
;
DROP TABLE IF EXISTS Usuarios
;
DROP TABLE IF EXISTS Ventas
;
-- 
-- TABLE: CategoriasProducto 
--

CREATE TABLE CategoriasProducto(
    IdCategoriaProducto    TINYINT         AUTO_INCREMENT,
    Categoria              VARCHAR(40)     NOT NULL,
    Descripcion            VARCHAR(255),
    PRIMARY KEY (IdCategoriaProducto)
)ENGINE=INNODB
COMMENT='Tabla que almacena las categorias de producto.'
;

-- 
-- TABLE: Ciudades 
--

CREATE TABLE Ciudades(
    IdCiudad       INT            NOT NULL,
    IdProvincia    INT            NOT NULL,
    IdPais         CHAR(2)        NOT NULL,
    Ciudad         VARCHAR(60)    NOT NULL,
    PRIMARY KEY (IdCiudad, IdProvincia, IdPais)
)ENGINE=INNODB
COMMENT='Tabla que almacena las ciudades.'
;

-- 
-- TABLE: Clientes 
--

CREATE TABLE Clientes(
    IdCliente          INT             AUTO_INCREMENT,
    IdPais             CHAR(2)         NOT NULL,
    IdTipoDocumento    TINYINT         NOT NULL,
    Documento          VARCHAR(15)     NOT NULL,
    Tipo               CHAR(1)         NOT NULL,
    FechaNacimiento    DATE            NOT NULL,
    Nombres            VARCHAR(40),
    Apellidos          VARCHAR(40),
    RazonSocial        VARCHAR(60),
    Email              VARCHAR(120),
    Telefono           VARCHAR(15),
    FechaAlta          DATETIME        NOT NULL,
    FechaBaja          DATETIME,
    Estado             CHAR(1)         NOT NULL,
    PRIMARY KEY (IdCliente)
)ENGINE=INNODB
COMMENT='Tabla que almacena los datos de los clientes de la empresa.'
;

-- 
-- TABLE: Comprobantes 
--

CREATE TABLE Comprobantes(
    IdComprobante        INT               AUTO_INCREMENT,
    IdVenta              INT               NOT NULL,
    IdUsuario            SMALLINT          NOT NULL,
    Tipo                 CHAR(1)           NOT NULL,
    NumeroComprobante    INT               NOT NULL,
    Monto                DECIMAL(10, 2)    NOT NULL,
    FechaAlta            DATETIME          NOT NULL,
    FechaBaja            DATETIME,
    Observaciones        VARCHAR(255),
    Estado               CHAR(1)           NOT NULL,
    PRIMARY KEY (IdComprobante)
)ENGINE=INNODB
COMMENT='Tabla que almacena los comprobantes.'
;

-- 
-- TABLE: Domicilios 
--

CREATE TABLE Domicilios(
    IdDomicilio      INT             AUTO_INCREMENT,
    IdCiudad         INT             NOT NULL,
    IdProvincia      INT             NOT NULL,
    IdPais           CHAR(2)         NOT NULL,
    Domicilio        VARCHAR(120)    NOT NULL,
    CodigoPostal     VARCHAR(10)     NOT NULL,
    FechaAlta        DATETIME        NOT NULL,
    Observaciones    VARCHAR(255),
    PRIMARY KEY (IdDomicilio)
)ENGINE=INNODB
COMMENT='Tabla que almacena los domicilios.'
;

-- 
-- TABLE: DomiciliosCliente 
--

CREATE TABLE DomiciliosCliente(
    IdDomicilio    INT         NOT NULL,
    IdCliente      INT         NOT NULL,
    FechaAlta      DATETIME    NOT NULL,
    PRIMARY KEY (IdDomicilio, IdCliente)
)ENGINE=INNODB
;



-- 
-- TABLE: Empresa 
--

CREATE TABLE Empresa(
    IdParametro    SMALLINT        AUTO_INCREMENT,
    Parametro      VARCHAR(40)     NOT NULL,
    Valor          VARCHAR(60)     NOT NULL,
    Descripcion    VARCHAR(255),
    PRIMARY KEY (IdParametro)
)ENGINE=INNODB
COMMENT='Tabla que almacena los parámetos de la empresa.'
;

-- 
-- TABLE: GruposProducto 
--

CREATE TABLE GruposProducto(
    IdGrupoProducto    TINYINT         AUTO_INCREMENT,
    Grupo              VARCHAR(40)     NOT NULL,
    FechaAlta          DATETIME        NOT NULL,
    FechaBaja          DATETIME,
    Descripcion        VARCHAR(255),
    Estado             CHAR(1)         NOT NULL,
    PRIMARY KEY (IdGrupoProducto)
)ENGINE=INNODB
COMMENT='Tabla que almacena los grupos de productos.'
;

-- 
-- TABLE: LineasProducto 
--

CREATE TABLE LineasProducto(
    IdLineaProducto         BIGINT            AUTO_INCREMENT,
    IdLineaProductoPadre    BIGINT,
    IdProductoFinal         INT               NOT NULL,
    IdUbicacion             TINYINT,
    IdReferencia            INT               NOT NULL,
    Tipo                    CHAR(1)           NOT NULL,
    PrecioUnitario          DECIMAL(10, 2),
    Cantidad                TINYINT           NOT NULL,
    FechaAlta               DATETIME          NOT NULL,
    FechaCancelacion        DATETIME,
    Estado                  CHAR(1)           NOT NULL,
    PRIMARY KEY (IdLineaProducto)
)ENGINE=INNODB
COMMENT='Tabla que almacena las líneas de producto.'
;

-- 
-- TABLE: Lustres 
--

CREATE TABLE Lustres(
    IdLustre         TINYINT         AUTO_INCREMENT,
    Lustre           VARCHAR(40)     NOT NULL,
    Observaciones    VARCHAR(255),
    PRIMARY KEY (IdLustre)
)ENGINE=INNODB
COMMENT='Tabla que almacena los lustres.'
;

-- 
-- TABLE: Observaciones 
--

CREATE TABLE Observaciones(
    IdObservacion      BIGINT          AUTO_INCREMENT,
    IdLineaProducto    BIGINT          NOT NULL,
    Observacion        VARCHAR(255)    NOT NULL,
    FechaAlta          DATETIME        NOT NULL,
    PRIMARY KEY (IdObservacion)
)ENGINE=INNODB
COMMENT='Tabla que almacena las observaciones de una línea de producto.'
;

-- 
-- TABLE: OrdenesProduccion 
--

CREATE TABLE OrdenesProduccion(
    IdOrdenProduccion    INT             AUTO_INCREMENT,
    IdUsuario            SMALLINT        NOT NULL,
    FechaAlta            DATETIME        NOT NULL,
    Observaciones        VARCHAR(255),
    Estado               CHAR(1)         NOT NULL,
    PRIMARY KEY (IdOrdenProduccion)
)ENGINE=INNODB
COMMENT='Tablas que almacena las ordenes de producción.'
;

-- 
-- TABLE: Paises 
--

CREATE TABLE Paises(
    IdPais    CHAR(2)        NOT NULL,
    Pais      VARCHAR(40),
    PRIMARY KEY (IdPais)
)ENGINE=INNODB
COMMENT='Tabla que almacena los países.'
;

-- 
-- TABLE: Permisos 
--

CREATE TABLE Permisos(
    IdPermiso        SMALLINT        NOT NULL,
    Permiso          VARCHAR(40)     NOT NULL,
    Procedimiento    VARCHAR(255)    NOT NULL,
    Descripcion      VARCHAR(255),
    PRIMARY KEY (IdPermiso)
)ENGINE=INNODB
COMMENT='Tabla que almacena los permisos.'
;

-- 
-- TABLE: PermisosRol 
--

CREATE TABLE PermisosRol(
    IdPermiso    SMALLINT    NOT NULL,
    IdRol        TINYINT     NOT NULL,
    PRIMARY KEY (IdPermiso, IdRol)
)ENGINE=INNODB
COMMENT='Tabla que almacena los permisos por rol.'
;

-- 
-- TABLE: Precios 
--

CREATE TABLE Precios(
    IdPrecio        INT               AUTO_INCREMENT,
    Precio          DECIMAL(10, 2)    NOT NULL,
    Tipo            CHAR(1)           NOT NULL,
    IdReferencia    INT,
    FechaAlta       DATETIME          NOT NULL,
    PRIMARY KEY (IdPrecio)
)ENGINE=INNODB
COMMENT='Tabla que almacena el historico de precios para un mismo producto.'
;

-- 
-- TABLE: Presupuestos 
--

CREATE TABLE Presupuestos(
    IdPresupuesto     INT             AUTO_INCREMENT,
    IdCliente         INT             NOT NULL,
    IdVenta           INT,
    IdUbicacion       TINYINT         NOT NULL,
    IdUsuario         SMALLINT        NOT NULL,
    PeriodoValidez    TINYINT         NOT NULL,
    FechaAlta         DATETIME        NOT NULL,
    Observaciones     VARCHAR(255),
    Estado            CHAR(1)         NOT NULL,
    PRIMARY KEY (IdPresupuesto)
)ENGINE=INNODB
COMMENT='Tabla que almacena los presupuestos.'
;

-- 
-- TABLE: Productos 
--

CREATE TABLE Productos(
    IdProducto             INT              AUTO_INCREMENT,
    IdCategoriaProducto    TINYINT          NOT NULL,
    IdGrupoProducto        TINYINT          NOT NULL,
    IdTipoProducto         CHAR(1)          NOT NULL,
    Producto               VARCHAR(80)      NOT NULL,
    LongitudTela           DECIMAL(3, 2)    NOT NULL,
    FechaAlta              DATETIME         NOT NULL,
    FechaBaja              DATETIME,
    Observaciones          VARCHAR(255),
    Estado                 CHAR(1)          NOT NULL,
    PRIMARY KEY (IdProducto)
)ENGINE=INNODB
COMMENT='Tabla que almacena los productos.'
;

-- 
-- TABLE: ProductosFinales 
--

CREATE TABLE ProductosFinales(
    IdProductoFinal    INT         AUTO_INCREMENT,
    IdProducto         INT         NOT NULL,
    IdLustre           TINYINT,
    IdTela             SMALLINT,
    FechaAlta          DATETIME    NOT NULL,
    FechaBaja          DATETIME,
    Estado             CHAR(1)     NOT NULL,
    PRIMARY KEY (IdProductoFinal)
)ENGINE=INNODB
COMMENT='Tabla que almacena los productos finales.'
;

-- 
-- TABLE: Provincias 
--

CREATE TABLE Provincias(
    IdProvincia    INT            NOT NULL,
    IdPais         CHAR(2)        NOT NULL,
    Provincia      VARCHAR(40)    NOT NULL,
    PRIMARY KEY (IdProvincia, IdPais)
)ENGINE=INNODB
COMMENT='Tabla que almacena las provincias.'
;

-- 
-- TABLE: Remitos 
--

CREATE TABLE Remitos(
    IdRemito         INT             AUTO_INCREMENT,
    IdUbicacion      TINYINT,
    IdUsuario        SMALLINT        NOT NULL,
    Tipo             CHAR(1)         NOT NULL,
    FechaEntrega     DATETIME,
    FechaAlta        DATETIME        NOT NULL,
    Observaciones    VARCHAR(255),
    Estado           CHAR(1)         NOT NULL,
    PRIMARY KEY (IdRemito)
)ENGINE=INNODB
COMMENT='Tabla que almacena los remitos.'
;

-- 
-- TABLE: Roles 
--

CREATE TABLE Roles(
    IdRol          TINYINT         AUTO_INCREMENT,
    Rol            VARCHAR(40),
    FechaAlta      DATETIME        NOT NULL,
    Descripcion    VARCHAR(255),
    PRIMARY KEY (IdRol)
)ENGINE=INNODB
COMMENT='Tabla que almacena los roles.'
;

-- 
-- TABLE: Tareas 
--

CREATE TABLE Tareas(
    IdTarea                BIGINT          AUTO_INCREMENT,
    IdLineaProducto        BIGINT          NOT NULL,
    IdTareaSiguiente       BIGINT,
    IdUsuarioFabricante    SMALLINT        NOT NULL,
    IdUsuarioRevisor       SMALLINT,
    Tarea                  VARCHAR(255)    NOT NULL,
    FechaInicio            DATETIME,
    FechaPausa             DATETIME,
    FechaFinalizacion      DATETIME,
    FechaRevision          DATETIME,
    FechaAlta              DATETIME        NOT NULL,
    FechaCancelacion       DATETIME,
    Observaciones          TEXT,
    Estado                 CHAR(1)         NOT NULL,
    PRIMARY KEY (IdTarea)
)ENGINE=INNODB
COMMENT='Tabla que almacena las tareas asignadas a un usuario para una determinada linea de producto.'
;

-- 
-- TABLE: Telas 
--

CREATE TABLE Telas(
    IdTela           SMALLINT        AUTO_INCREMENT,
    Tela             VARCHAR(60)     NOT NULL,
    FechaAlta        DATETIME        NOT NULL,
    FechaBaja        DATETIME,
    Observaciones    VARCHAR(255),
    Estado           CHAR(1)         NOT NULL,
    PRIMARY KEY (IdTela)
)ENGINE=INNODB
COMMENT='Tabla que almacena las telas.'
;

-- 
-- TABLE: TiposDocumento 
--

CREATE TABLE TiposDocumento(
    IdTipoDocumento    TINYINT         NOT NULL,
    TipoDocumento      VARCHAR(40)     NOT NULL,
    Descripcion        VARCHAR(255),
    PRIMARY KEY (IdTipoDocumento)
)ENGINE=INNODB
COMMENT='Tabla que almacena los tipos de documento.'
;

-- 
-- TABLE: TiposProducto 
--

CREATE TABLE TiposProducto(
    IdTipoProducto    CHAR(1)         NOT NULL,
    TipoProducto      VARCHAR(30)     NOT NULL,
    Descripcion       VARCHAR(255),
    PRIMARY KEY (IdTipoProducto)
)ENGINE=INNODB
COMMENT='Tabla que almacena los tipos de producto.'
;

-- 
-- TABLE: Ubicaciones 
--

CREATE TABLE Ubicaciones(
    IdUbicacion      TINYINT         AUTO_INCREMENT,
    IdDomicilio      INT             NOT NULL,
    Ubicacion        VARCHAR(40)     NOT NULL,
    FechaAlta        DATETIME        NOT NULL,
    FechaBaja        DATETIME,
    Observaciones    VARCHAR(255),
    Estado           CHAR(1)         NOT NULL,
    PRIMARY KEY (IdUbicacion)
)ENGINE=INNODB
COMMENT='Tabla que almacena las ubicaciones.'
;

-- 
-- TABLE: Usuarios 
--

CREATE TABLE Usuarios(
    IdUsuario          SMALLINT        AUTO_INCREMENT,
    IdRol              TINYINT         NOT NULL,
    IdUbicacion        TINYINT         NOT NULL,
    IdTipoDocumento    TINYINT         NOT NULL,
    Documento          VARCHAR(15)     NOT NULL,
    Nombres            VARCHAR(40)     NOT NULL,
    Apellidos          VARCHAR(40)     NOT NULL,
    EstadoCivil        CHAR(1)         NOT NULL,
    Telefono           VARCHAR(15)     NOT NULL,
    Email              VARCHAR(120)    NOT NULL,
    CantidadHijos      TINYINT         NOT NULL,
    Usuario            VARCHAR(40)     NOT NULL,
    Password           VARCHAR(255)    NOT NULL,
    Token              VARCHAR(256),
    FechaUltIntento    DATETIME,
    Intentos           SMALLINT        NOT NULL,
    FechaNacimiento    DATE            NOT NULL,
    FechaInicio        DATE            NOT NULL,
    FechaAlta          DATETIME        NOT NULL,
    FechaBaja          DATETIME,
    Estado             CHAR(1)         NOT NULL,
    PRIMARY KEY (IdUsuario)
)ENGINE=INNODB
COMMENT='Tabla que almacena los usuarios.'
;

-- 
-- TABLE: Ventas 
--

CREATE TABLE Ventas(
    IdVenta          INT             AUTO_INCREMENT,
    IdCliente        INT             NOT NULL,
    IdDomicilio      INT,
    IdUbicacion      TINYINT         NOT NULL,
    IdUsuario        SMALLINT        NOT NULL,
    FechaAlta        DATETIME        NOT NULL,
    Observaciones    VARCHAR(255),
    Estado           CHAR(1)         NOT NULL,
    PRIMARY KEY (IdVenta)
)ENGINE=INNODB
COMMENT='Tabla que almacena las ventas.'
;

-- 
-- INDEX: UI_Categoria 
--

CREATE UNIQUE INDEX UI_Categoria ON CategoriasProducto(Categoria)
;
-- 
-- INDEX: UI_CiudadIdProvincia 
--

CREATE UNIQUE INDEX UI_CiudadIdProvincia ON Ciudades(Ciudad, IdProvincia)
;
-- 
-- INDEX: UI_IdCiudad 
--

CREATE UNIQUE INDEX UI_IdCiudad ON Ciudades(IdCiudad)
;
-- 
-- INDEX: Ref1615 
--

CREATE INDEX Ref1615 ON Ciudades(IdPais, IdProvincia)
;
-- 
-- INDEX: UI_Email 
--

CREATE UNIQUE INDEX UI_Email ON Clientes(Email)
;
-- 
-- INDEX: UI_Documento_IdTipoDocumento 
--

CREATE UNIQUE INDEX UI_Documento_IdTipoDocumento ON Clientes(Documento, IdTipoDocumento)
;
-- 
-- INDEX: Ref1411 
--

CREATE INDEX Ref1411 ON Clientes(IdPais)
;
-- 
-- INDEX: Ref1212 
--

CREATE INDEX Ref1212 ON Clientes(IdTipoDocumento)
;
-- 
-- INDEX: UI_NumeroComprobanteTipo 
--

CREATE UNIQUE INDEX UI_NumeroComprobanteTipo ON Comprobantes(NumeroComprobante, Tipo)
;
-- 
-- INDEX: Ref3242 
--

CREATE INDEX Ref3242 ON Comprobantes(IdVenta)
;
-- 
-- INDEX: Ref286 
--

CREATE INDEX Ref286 ON Comprobantes(IdUsuario)
;
-- 
-- INDEX: UI_Domicilio_IdCiudad 
--

CREATE UNIQUE INDEX UI_Domicilio_IdCiudad ON Domicilios(Domicilio, IdCiudad)
;
-- 
-- INDEX: Ref1716 
--

CREATE INDEX Ref1716 ON Domicilios(IdPais, IdProvincia, IdCiudad)
;
-- 
-- INDEX: Ref1587 
--

CREATE INDEX Ref1587 ON DomiciliosCliente(IdDomicilio)
;
-- 
-- INDEX: Ref1188 
--

CREATE INDEX Ref1188 ON DomiciliosCliente(IdCliente)
;
-- 
-- INDEX: UI_Parametro 
--

CREATE UNIQUE INDEX UI_Parametro ON Empresa(Parametro)
;
-- 
-- INDEX: UI_Grupo 
--

CREATE UNIQUE INDEX UI_Grupo ON GruposProducto(Grupo)
;
-- 
-- INDEX: Ref2149 
--

CREATE INDEX Ref2149 ON LineasProducto(IdProductoFinal)
;
-- 
-- INDEX: Ref3383 
--

CREATE INDEX Ref3383 ON LineasProducto(IdLineaProductoPadre)
;
-- 
-- INDEX: Ref2784 
--

CREATE INDEX Ref2784 ON LineasProducto(IdUbicacion)
;
-- 
-- INDEX: UI_Lustre 
--

CREATE UNIQUE INDEX UI_Lustre ON Lustres(Lustre)
;
-- 
-- INDEX: Ref3351 
--

CREATE INDEX Ref3351 ON Observaciones(IdLineaProducto)
;
-- 
-- INDEX: Ref256 
--

CREATE INDEX Ref256 ON OrdenesProduccion(IdUsuario)
;
-- 
-- INDEX: UI_Pais 
--

CREATE UNIQUE INDEX UI_Pais ON Paises(Pais)
;
-- 
-- INDEX: UI_Permiso 
--

CREATE UNIQUE INDEX UI_Permiso ON Permisos(Permiso)
;
-- 
-- INDEX: Ref74 
--

CREATE INDEX Ref74 ON PermisosRol(IdPermiso)
;
-- 
-- INDEX: Ref55 
--

CREATE INDEX Ref55 ON PermisosRol(IdRol)
;
-- 
-- INDEX: Ref3238 
--

CREATE INDEX Ref3238 ON Presupuestos(IdVenta)
;
-- 
-- INDEX: Ref1119 
--

CREATE INDEX Ref1119 ON Presupuestos(IdCliente)
;
-- 
-- INDEX: Ref271 
--

CREATE INDEX Ref271 ON Presupuestos(IdUsuario)
;
-- 
-- INDEX: Ref2781 
--

CREATE INDEX Ref2781 ON Presupuestos(IdUbicacion)
;
-- 
-- INDEX: UI_ProductoIdCategoriaProductoIdGrupoProducto 
--

CREATE UNIQUE INDEX UI_ProductoIdCategoriaProductoIdGrupoProducto ON Productos(Producto, IdCategoriaProducto, IdGrupoProducto)
;
-- 
-- INDEX: Ref3032 
--

CREATE INDEX Ref3032 ON Productos(IdCategoriaProducto)
;
-- 
-- INDEX: Ref3133 
--

CREATE INDEX Ref3133 ON Productos(IdGrupoProducto)
;
-- 
-- INDEX: Ref4280 
--

CREATE INDEX Ref4280 ON Productos(IdTipoProducto)
;
-- 
-- INDEX: UI_IdProducto_IdTela_IdLustre 
--

CREATE UNIQUE INDEX UI_IdProducto_IdTela_IdLustre ON ProductosFinales(IdProducto, IdTela, IdLustre)
;
-- 
-- INDEX: Ref2325 
--

CREATE INDEX Ref2325 ON ProductosFinales(IdLustre)
;
-- 
-- INDEX: Ref2426 
--

CREATE INDEX Ref2426 ON ProductosFinales(IdTela)
;
-- 
-- INDEX: Ref2627 
--

CREATE INDEX Ref2627 ON ProductosFinales(IdProducto)
;
-- 
-- INDEX: UI_IdPaisProvincia 
--

CREATE UNIQUE INDEX UI_IdPaisProvincia ON Provincias(IdPais, Provincia)
;
-- 
-- INDEX: UI_IdProvincia 
--

CREATE UNIQUE INDEX UI_IdProvincia ON Provincias(IdProvincia)
;
-- 
-- INDEX: Ref1414 
--

CREATE INDEX Ref1414 ON Provincias(IdPais)
;
-- 
-- INDEX: Ref2772 
--

CREATE INDEX Ref2772 ON Remitos(IdUbicacion)
;
-- 
-- INDEX: Ref285 
--

CREATE INDEX Ref285 ON Remitos(IdUsuario)
;
-- 
-- INDEX: UI_Rol 
--

CREATE UNIQUE INDEX UI_Rol ON Roles(Rol)
;
-- 
-- INDEX: Ref4375 
--

CREATE INDEX Ref4375 ON Tareas(IdTareaSiguiente)
;
-- 
-- INDEX: Ref3376 
--

CREATE INDEX Ref3376 ON Tareas(IdLineaProducto)
;
-- 
-- INDEX: Ref277 
--

CREATE INDEX Ref277 ON Tareas(IdUsuarioFabricante)
;
-- 
-- INDEX: Ref278 
--

CREATE INDEX Ref278 ON Tareas(IdUsuarioRevisor)
;
-- 
-- INDEX: UI_Tela 
--

CREATE UNIQUE INDEX UI_Tela ON Telas(Tela)
;
-- 
-- INDEX: UI_TipoDocumento 
--

CREATE UNIQUE INDEX UI_TipoDocumento ON TiposDocumento(TipoDocumento)
;
-- 
-- INDEX: UI_TipoProducto 
--

CREATE UNIQUE INDEX UI_TipoProducto ON TiposProducto(TipoProducto)
;
-- 
-- INDEX: UI_Ubicacion 
--

CREATE UNIQUE INDEX UI_Ubicacion ON Ubicaciones(Ubicacion)
;
-- 
-- INDEX: Ref1529 
--

CREATE INDEX Ref1529 ON Ubicaciones(IdDomicilio)
;
-- 
-- INDEX: UI_Email 
--

CREATE UNIQUE INDEX UI_Email ON Usuarios(Email)
;
-- 
-- INDEX: UI_Usuario 
--

CREATE UNIQUE INDEX UI_Usuario ON Usuarios(Usuario)
;
-- 
-- INDEX: UI_DocumentoIdTipoDocumento 
--

CREATE UNIQUE INDEX UI_DocumentoIdTipoDocumento ON Usuarios(Documento, IdTipoDocumento)
;
-- 
-- INDEX: IX_NombresApellidos 
--

CREATE INDEX IX_NombresApellidos ON Usuarios(Nombres, Apellidos)
;
-- 
-- INDEX: Ref52 
--

CREATE INDEX Ref52 ON Usuarios(IdRol)
;
-- 
-- INDEX: Ref2782 
--

CREATE INDEX Ref2782 ON Usuarios(IdUbicacion)
;
-- 
-- INDEX: Ref1210 
--

CREATE INDEX Ref1210 ON Usuarios(IdTipoDocumento)
;
-- 
-- INDEX: Ref1139 
--

CREATE INDEX Ref1139 ON Ventas(IdCliente)
;
-- 
-- INDEX: Ref1541 
--

CREATE INDEX Ref1541 ON Ventas(IdDomicilio)
;
-- 
-- INDEX: Ref2747 
--

CREATE INDEX Ref2747 ON Ventas(IdUbicacion)
;
-- 
-- INDEX: Ref248 
--

CREATE INDEX Ref248 ON Ventas(IdUsuario)
;
-- 
-- TABLE: Ciudades 
--

ALTER TABLE Ciudades ADD CONSTRAINT RefProvincias15 
    FOREIGN KEY (IdProvincia, IdPais)
    REFERENCES Provincias(IdProvincia, IdPais)
;


-- 
-- TABLE: Clientes 
--

ALTER TABLE Clientes ADD CONSTRAINT RefPaises11 
    FOREIGN KEY (IdPais)
    REFERENCES Paises(IdPais)
;

ALTER TABLE Clientes ADD CONSTRAINT RefTiposDocumento12 
    FOREIGN KEY (IdTipoDocumento)
    REFERENCES TiposDocumento(IdTipoDocumento)
;


-- 
-- TABLE: Comprobantes 
--

ALTER TABLE Comprobantes ADD CONSTRAINT RefVentas42 
    FOREIGN KEY (IdVenta)
    REFERENCES Ventas(IdVenta)
;

ALTER TABLE Comprobantes ADD CONSTRAINT RefUsuarios86 
    FOREIGN KEY (IdUsuario)
    REFERENCES Usuarios(IdUsuario)
;


-- 
-- TABLE: Domicilios 
--

ALTER TABLE Domicilios ADD CONSTRAINT RefCiudades16 
    FOREIGN KEY (IdCiudad, IdProvincia, IdPais)
    REFERENCES Ciudades(IdCiudad, IdProvincia, IdPais)
;


-- 
-- TABLE: DomiciliosCliente 
--

ALTER TABLE DomiciliosCliente ADD CONSTRAINT RefDomicilios87 
    FOREIGN KEY (IdDomicilio)
    REFERENCES Domicilios(IdDomicilio)
;

ALTER TABLE DomiciliosCliente ADD CONSTRAINT RefClientes88 
    FOREIGN KEY (IdCliente)
    REFERENCES Clientes(IdCliente)
;


-- 
-- TABLE: LineasProducto 
--

ALTER TABLE LineasProducto ADD CONSTRAINT RefProductosFinales49 
    FOREIGN KEY (IdProductoFinal)
    REFERENCES ProductosFinales(IdProductoFinal)
;

ALTER TABLE LineasProducto ADD CONSTRAINT RefLineasProducto83 
    FOREIGN KEY (IdLineaProductoPadre)
    REFERENCES LineasProducto(IdLineaProducto)
;

ALTER TABLE LineasProducto ADD CONSTRAINT RefUbicaciones84 
    FOREIGN KEY (IdUbicacion)
    REFERENCES Ubicaciones(IdUbicacion)
;


-- 
-- TABLE: Observaciones 
--

ALTER TABLE Observaciones ADD CONSTRAINT RefLineasProducto51 
    FOREIGN KEY (IdLineaProducto)
    REFERENCES LineasProducto(IdLineaProducto)
;


-- 
-- TABLE: OrdenesProduccion 
--

ALTER TABLE OrdenesProduccion ADD CONSTRAINT RefUsuarios56 
    FOREIGN KEY (IdUsuario)
    REFERENCES Usuarios(IdUsuario)
;


-- 
-- TABLE: PermisosRol 
--

ALTER TABLE PermisosRol ADD CONSTRAINT RefPermisos4 
    FOREIGN KEY (IdPermiso)
    REFERENCES Permisos(IdPermiso)
;

ALTER TABLE PermisosRol ADD CONSTRAINT RefRoles5 
    FOREIGN KEY (IdRol)
    REFERENCES Roles(IdRol)
;


-- 
-- TABLE: Presupuestos 
--

ALTER TABLE Presupuestos ADD CONSTRAINT RefVentas38 
    FOREIGN KEY (IdVenta)
    REFERENCES Ventas(IdVenta)
;

ALTER TABLE Presupuestos ADD CONSTRAINT RefClientes19 
    FOREIGN KEY (IdCliente)
    REFERENCES Clientes(IdCliente)
;

ALTER TABLE Presupuestos ADD CONSTRAINT RefUsuarios71 
    FOREIGN KEY (IdUsuario)
    REFERENCES Usuarios(IdUsuario)
;

ALTER TABLE Presupuestos ADD CONSTRAINT RefUbicaciones81 
    FOREIGN KEY (IdUbicacion)
    REFERENCES Ubicaciones(IdUbicacion)
;


-- 
-- TABLE: Productos 
--

ALTER TABLE Productos ADD CONSTRAINT RefCategoriasProducto32 
    FOREIGN KEY (IdCategoriaProducto)
    REFERENCES CategoriasProducto(IdCategoriaProducto)
;

ALTER TABLE Productos ADD CONSTRAINT RefGruposProducto33 
    FOREIGN KEY (IdGrupoProducto)
    REFERENCES GruposProducto(IdGrupoProducto)
;

ALTER TABLE Productos ADD CONSTRAINT RefTiposProducto80 
    FOREIGN KEY (IdTipoProducto)
    REFERENCES TiposProducto(IdTipoProducto)
;


-- 
-- TABLE: ProductosFinales 
--

ALTER TABLE ProductosFinales ADD CONSTRAINT RefLustres25 
    FOREIGN KEY (IdLustre)
    REFERENCES Lustres(IdLustre)
;

ALTER TABLE ProductosFinales ADD CONSTRAINT RefTelas26 
    FOREIGN KEY (IdTela)
    REFERENCES Telas(IdTela)
;

ALTER TABLE ProductosFinales ADD CONSTRAINT RefProductos27 
    FOREIGN KEY (IdProducto)
    REFERENCES Productos(IdProducto)
;


-- 
-- TABLE: Provincias 
--

ALTER TABLE Provincias ADD CONSTRAINT RefPaises14 
    FOREIGN KEY (IdPais)
    REFERENCES Paises(IdPais)
;


-- 
-- TABLE: Remitos 
--

ALTER TABLE Remitos ADD CONSTRAINT RefUbicaciones72 
    FOREIGN KEY (IdUbicacion)
    REFERENCES Ubicaciones(IdUbicacion)
;

ALTER TABLE Remitos ADD CONSTRAINT RefUsuarios85 
    FOREIGN KEY (IdUsuario)
    REFERENCES Usuarios(IdUsuario)
;


-- 
-- TABLE: Tareas 
--

ALTER TABLE Tareas ADD CONSTRAINT RefTareas75 
    FOREIGN KEY (IdTareaSiguiente)
    REFERENCES Tareas(IdTarea)
;

ALTER TABLE Tareas ADD CONSTRAINT RefLineasProducto76 
    FOREIGN KEY (IdLineaProducto)
    REFERENCES LineasProducto(IdLineaProducto)
;

ALTER TABLE Tareas ADD CONSTRAINT RefUsuarios77 
    FOREIGN KEY (IdUsuarioFabricante)
    REFERENCES Usuarios(IdUsuario)
;

ALTER TABLE Tareas ADD CONSTRAINT RefUsuarios78 
    FOREIGN KEY (IdUsuarioRevisor)
    REFERENCES Usuarios(IdUsuario)
;


-- 
-- TABLE: Ubicaciones 
--

ALTER TABLE Ubicaciones ADD CONSTRAINT RefDomicilios29 
    FOREIGN KEY (IdDomicilio)
    REFERENCES Domicilios(IdDomicilio)
;


-- 
-- TABLE: Usuarios 
--

ALTER TABLE Usuarios ADD CONSTRAINT RefRoles2 
    FOREIGN KEY (IdRol)
    REFERENCES Roles(IdRol)
;

ALTER TABLE Usuarios ADD CONSTRAINT RefUbicaciones82 
    FOREIGN KEY (IdUbicacion)
    REFERENCES Ubicaciones(IdUbicacion)
;

ALTER TABLE Usuarios ADD CONSTRAINT RefTiposDocumento10 
    FOREIGN KEY (IdTipoDocumento)
    REFERENCES TiposDocumento(IdTipoDocumento)
;


-- 
-- TABLE: Ventas 
--

ALTER TABLE Ventas ADD CONSTRAINT RefClientes39 
    FOREIGN KEY (IdCliente)
    REFERENCES Clientes(IdCliente)
;

ALTER TABLE Ventas ADD CONSTRAINT RefDomicilios41 
    FOREIGN KEY (IdDomicilio)
    REFERENCES Domicilios(IdDomicilio)
;

ALTER TABLE Ventas ADD CONSTRAINT RefUbicaciones47 
    FOREIGN KEY (IdUbicacion)
    REFERENCES Ubicaciones(IdUbicacion)
;

ALTER TABLE Ventas ADD CONSTRAINT RefUsuarios48 
    FOREIGN KEY (IdUsuario)
    REFERENCES Usuarios(IdUsuario)
;

SET FOREIGN_KEY_CHECKS = 1;
