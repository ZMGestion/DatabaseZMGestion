/* Limpieza de tablas */
SET FOREIGN_KEY_CHECKS = 0; 
TRUNCATE TABLE ZMGestion.PermisosRol;
TRUNCATE TABLE ZMGestion.Permisos;
TRUNCATE TABLE ZMGestion.Roles;
TRUNCATE TABLE ZMGestion.Usuarios;
TRUNCATE TABLE ZMGestion.Empresa;
TRUNCATE TABLE ZMGestion.Paises;
TRUNCATE TABLE ZMGestion.Provincias;
TRUNCATE TABLE ZMGestion.Ciudades;
TRUNCATE TABLE ZMGestion.Domicilios;
TRUNCATE TABLE ZMGestion.Ubicaciones;
TRUNCATE TABLE ZMGestion.TiposDocumento;

SET FOREIGN_KEY_CHECKS = 1; 

/* Carga inicial roles */
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`, `FechaAlta`) VALUES (1, 'Administradores', 'Rol para los administradores de ZMGestion.', NOW());
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`, `FechaAlta`) VALUES (2, 'Vendedores', 'Rol para los vendedores de ZMGestion.', NOW());
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`, `FechaAlta`) VALUES (3, 'Fabricantes', 'Rol para los fabricantes de ZMGestion.', NOW());

/* Carga inicial permisos */
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (1, 'Crear rol', 'Permite a un usuario crear un nuevo rol.', 'zsp_rol_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (2, 'Borrar rol', 'Permite a un usuario borrar un rol existente, siempre y cuando ningun usuario tenga ese rol.', 'zsp_rol_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (3, 'Asignar permisos a rol', 'Permite a un usuario asignar permisos a un rol existente.', 'zsp_rol_asignar_permisos');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (4, 'Crear empleado', 'Permite a un usuario crear nuevos usuarios.', 'zsp_usuario_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (5, 'Borrar empleado', 'Permite a un usuario borrar a otros usuarios siempre y cuando éste no tenga presupuestos, ventas, órdenes de producción, tareas o comprobantes asociados. Tampoco puede borrar al super administrador.', 'zsp_usuario_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (6, 'Modificar empleado', 'Permite a un usuario modificar a otros usuarios.', 'zsp_usuario_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (7, 'Buscar empleados', 'Permite a un usuario buscar a otros usuarios.', 'zsp_usuarios_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (8, 'Dar de baja empleados', 'Permite a un usuario dar de baja a otros usuarios.', 'zsp_usuario_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (9, 'Dar de alta empleados', 'Permite a un usuario dar de alta a otros usuarios que fueron dado de baja.', 'zsp_usuario_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (10, 'Restablecer contraseña', 'Permite a un usuario restablecer la contraseña de otro usuario. ', 'zsp_usuario_restablecer_pass');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (11, 'Modificar contraseña', 'Permite a un usuario cambiar su contraseña ingresando la contraseña actual.', 'zsp_usuario_modificar_pass');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (12, 'Cerrar sesion', 'Permite a un usuario cerrar la sesión de otro usuario.', 'zsp_sesion_cerrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (13, 'Ver empleado', 'Permite a un usuario instanciar a otro por Id', 'zsp_usuario_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (14, 'Crear domicilio', 'Permite crear un domicilio.', 'zsp_domicilio_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (15, 'Borrar domicilio', 'Permite un usuario borrar un domicilio.', 'zsp_domicilio_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (16, 'Crear ubicación', 'Permite a un usuario crear una ubicacion', 'zsp_ubicacion_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (17, 'Dar de alta ubicación', 'Permite a un usuario dar de alta una ubicación que fue dada de baja.', 'zsp_ubicacion_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (18, 'Dar de baja ubicación', 'Permite a un usuario dar de baja una ubicacion que esta en estado Alta.', 'zsp_ubicacion_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (19, 'Modificar ubicación', 'Permite a un usuario modificar una ubicación existente.', 'zsp_ubicacion_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (20, 'Borrar ubicacion', 'Permite a un usuario borrar una ubicación existente', 'zsp_ubicacion_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (21, 'Crear cliente', 'Permite a un usuario crear un cliente.', 'zsp_cliente_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (22, 'Modificar cliente', 'Permite a un usuario modificar un cliente.', 'zsp_cliente_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (23, 'Dar de alta cliente', 'Permite a usuario dar de alta un cliente', 'zsp_cliente_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (24, 'Dar de baja cliente', 'Permite a usuario dar de baja a un cliente.', 'zsp_cliente_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (25, 'Borrar cliente', 'Permite a un usuario borrar un cliente', 'zsp_cliente_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (26, 'Buscar clientes', 'Permite a un usuario buscar un cliente', 'zsp_clientes_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (27, 'Crear tela', 'Permite a un usuario crear una tela junto con su precio', 'zsp_tela_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (28, 'Modificar tela', 'Permite a un usuario modificar una tela.', 'zsp_tela_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (29, 'Modificar precio de tela', 'Permite a un usuario modificar el precio de una tela', 'zsp_tela_modificar_precio');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (30, 'Listar precios de una tela', 'Permite a un usuario listar los precios de una tela', 'zsp_tela_listar_precios');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (31, 'Dar de baja tela', 'Permite a un usuario dar de baja una tela', 'zsp_tela_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (32, 'Dar de alta tela', 'Permite a un usuario dar de alta una tela', 'zsp_tela_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (33, 'Borrar tela', 'Permite a un usuario borrar una tela', 'zsp_tela_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (34, 'Buscar telas', 'Permite a un usuario buscar una tela', 'zsp_telas_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (35, 'Crear grupo de productos', 'Permite a un usuario crear un grupo de productos', 'zsp_grupoProducto_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (36, 'Modificar grupo de productos', 'Permite a un usuario modificar un grupo de productos', 'zsp_grupoProducto_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (37, 'Dar de alta grupo de productos', 'Permite a un usuario dar de alta un grupo de productos', 'zsp_grupoProducto_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (38, 'Dar de baja grupo de productos', 'Permite a un usuario dar de baja un grupo de productos', 'zsp_grupoProducto_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (39, 'Borrar grupo de productos', 'Permite a un usuario borrar un grupo de productos', 'zsp_grupoProducto_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (40, 'Buscar grupos de productos', 'Permite a un usuario buscar grupos de productos', 'zsp_gruposProducto_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (41, 'Crear producto', 'Permite a un usuario crear un producto', 'zsp_producto_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (42, 'Modificar producto', 'Permite a un usuario modificar un producto', 'zsp_producto_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (43, 'Borrar producto', 'Permite a un usuario borrar un producto', 'zsp_producto_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (44, 'Dar de baja producto', 'Permite a un usuario dar de baja un producto', 'zsp_producto_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (45, 'Dar de alta producto', 'Permite a un usuario dar de alta un producto', 'zsp_producto_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (46, 'Buscar productos', 'Permite a un usuario buscar productos', 'zsp_productos_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (47, 'Listar precios de un producto', 'Permite a un usuario listar el historico de los precios de un producto', 'zsp_producto_listar_precios');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (48, 'Modificar precio producto', 'Permite a un usuario modificar el precio de un producto', 'zsp_producto_modificar_precio');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (49, 'Dame producto', 'Permite a un usuario instaciar un producto por su Id', 'zsp_producto_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (50, 'Listar lustres', 'Permite a un usuario listar los lustres', 'zsp_lustres_listar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (51, 'Listar tipos de producto', 'Permite a un usuario listar los tipos de producto', 'zsp_tiposProducto_listar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (52, 'Listar categorías', 'Permite a un usuario listar las CategoriasProducto de producto ', 'zsp_CategoriasProductoProducto_listar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (53, 'Crear mueble', 'Permite a un usuario crear un producto final', 'zsp_productoFinal_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (54, 'Ver cliente', 'Permite instanciar un cliente a partir de su Id', 'zsp_cliente_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (55, 'Ver ubicación', 'Permite instanciar una ubicacion a partir de su Id', 'zsp_ubicacion_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (56, 'Listar permisos', 'Permite listar todos los permisos existentes', 'zsp_permisos_listar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (57, 'Ver grupo de productos', 'Permite instanciar un grupo de producto a partir de su Id', 'zsp_grupoProducto_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (58, 'Modificar mueble', 'Permite modificar un producto final existente', 'zsp_productoFinal_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (59, 'Ver mueble', 'Permite instanciar un producto final', 'zsp_productoFinal_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (60, 'Dar de alta mueble', 'Permite a un usuario dar de alta un producto final', 'zsp_productoFinal_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (61, 'Dar de baja mueble', 'Permite a un usuario dar de baja un producto final', 'zsp_productoFinal_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (62, 'Buscar muebles', 'Permite a un usuario buscar productos finales', 'zsp_productosFinales_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (63, 'Borrar mueble', 'Permite a un usuario borrar un producto final', 'zsp_productoFinal_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (64, 'Crear presupuesto', 'Permite a un usuario crear un presupuesto', 'zsp_presupuesto_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (65, 'Modificar presupuesto', 'Permite a un usuario modificar un presupuesto', 'zsp_presupuesto_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (66, 'Pasar presupuesto a creado', 'Permite a un usuario confirmar un presupuesto', 'zsp_presupuesto_pasar_a_creado');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (67, 'Crear línea de presupuesto', 'Permitea un usuario crear una linea de presupuesto', 'zsp_lineaPresupuesto_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (68, 'Modificar precio de presupuesto', 'Permite a un usuario modificar el precio de un producto en un presupuesto', 'modificar_precio_presupuesto');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (69, 'Listar líneas de presupuesto', 'Permite a un usuario listar las lineas de un presupuesto', 'zsp_presupuesto_listar_lineasPresupuesto');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (70, 'Listar presupuestos ajenos', 'Permite a un usuario ver presupuestos que no fueron creados por el', 'buscar_presupuestos_ajenos');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (71, 'Buscar presupuestos', 'Permite a un usuario buscar presupuestos', 'zsp_presupuestos_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (72, 'Borrar línea de presupuesto', 'Permite a un usuario borrar una linea de presupuesto', 'zsp_lineaPresupuesto_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (73, 'Modificar precios grupo producto', 'Permite a un usuario modificar los precios de todos los productos pertenecientes a un determinado grupo en un porcentaje determinado', 'zsp_grupoProducto_modificar_precios');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (74, 'Ver presupuesto ajeno', 'Permite a un usuario visualizar un presupuesto ajeno', 'dame_presupuesto_ajeno');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (75, 'Ver presupuesto', 'Permite a un usuario instanciar un presupuesto', 'zsp_presupuesto_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (76, 'Ver línea presupuesto', 'Permite a un usuario instanciar una linea de presupuesto', 'zsp_lineaPresupuesto_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (77, 'Borrar presupuesto', 'Permite a un usuario borrar un presupuesto', 'zsp_presupuesto_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (78, 'Crear venta', 'Permite a un usuario crear una venta', 'zsp_venta_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (79, 'Modificar venta', 'Permite a un usuario modificar una venta', 'zsp_venta_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (80, 'Borrar venta', 'Permite a un usuario borrar una venta', 'zsp_venta_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (81, 'Modificar precio de venta', 'Permite a un usuario modificar el precio de una venta', 'modificar_precio_venta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (82, 'Crear línea de venta', 'Permite a un usuario crear una linea de venta', 'zsp_lineaVenta_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (83, 'Modificar línea de venta', 'Permite a un usuario modificar una linea de venta', 'zsp_lineaVenta_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (84, 'Borrar línea de venta', 'Permite a un usuario borrar una linea de venta', 'zsp_lineaVenta_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (85, 'Ver línea de venta', 'Permite a un ususario instanciar una linea de venta', 'zsp_lineaVenta_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (86, 'Ver venta ajena', 'Permite a un usuario visualizar una venta ajena', 'dame_venta_ajena');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (87, 'Ver venta', 'Permite a un usuario instanciar una venta', 'zsp_venta_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (88, 'Buscar ventas ajenas', 'Permite a un usuario buscar ventas de otro usuario', 'buscar_ventas_ajenas');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (89, 'Buscar ventas', 'Permite a un usuario buscar ventas', 'zsp_ventas_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (90, 'Transformar presupuestos en venta', 'Permite a un usuario crear una venta a partir de varios presupuestos', 'zsp_presupuestos_transformar_venta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (91, 'Revisar precios de venta', 'Permite a un usuario controlar si los precios de las lineas de venta son los actuales', 'zsp_venta_chequearPrecios');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (92, 'Aceptar venta', 'Permite a un usuario aceptar una venta que esta en Revision.', 'zsp_venta_revisar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (93, 'Cancelar línea de venta', 'Permite a un usuario cancelar una linea de venta', 'zsp_lineaVenta_cancelar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (94, 'Cancelar venta', 'Permite a un usuario cancelar una venta', 'zsp_venta_cancelar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (95, 'Ver multiples presupuestos', 'Permite a un usuario instanciar mas de un presupuesto a la vez', 'zsp_presupuestos_dame_multiple');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (96, 'Crear comprobante', 'Permite a un usuario crear un comprobante', 'zsp_comprobante_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (97, 'Modificar comprobante', 'Permite a un usuario modificar un comprobante', 'zsp_comprobante_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (98, 'Buscar comprobantes', 'Permite a un usuario buscar comprobantes', 'zsp_comprobantes_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (99, 'Dame comprobante', 'Permite a un usuario instanciar un comprobante', 'zsp_comprobante_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (100, 'Dar alta comprobante', 'Permite a un usuario dar de alta un comprobante', 'zsp_comprobante_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (101, 'Dar baja comprobante', 'Permite a un usuario dar de baja un comprobante', 'zsp_comprobante_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (102, 'Modificar línea de presupuesto', 'Permite a un usuario modificar una linea de presupuesto', 'zsp_lineaPresupuesto_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (103, 'Borrar comprobante', 'Permite a un usuario borrar un comprobante', 'zsp_comprobante_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (104, 'Crear remito', 'Permite a un usuario crear un remito', 'zsp_remito_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (105, 'Borrar remito', 'Permite a un usuario borrar un remito', 'zsp_remito_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (106, 'Pasar remito a creado', 'Pasar a remito a creado', 'zsp_remito_pasar_a_creado');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (107, 'Cancelar remito', 'Permite a un usuario cancelar un remito', 'zsp_remito_cancelar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (108, 'Descancelar remito', 'Permite a un usuario descancelar un remito', 'zsp_remito_descancelar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (109, 'Buscar remito', 'Permite a un usuario buscar un remito', 'zsp_remitos_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (110, 'Entregar remito', 'Permite a un usuario entregar un remito', 'zsp_remito_entregar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (111, 'Crear línea de remito', 'Permite a un usuario crear una linea de remito', 'zsp_lineaRemito_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (112, 'Borrar línea de remito', 'Permite a un usuario borrar una linea de remito', 'zsp_lineaRemito_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (113, 'Modificar línea de remito', 'Permite a un usuario modificar una linea de remito', 'zsp_lineaRemito_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (114, 'Buscar remito ajeno', 'Permite a un usuario buscar un remito de otro usuario', 'remitos_buscar_ajeno');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (115, 'Crear orden de producción', 'Permite a un usuario crear una orden de producción', 'zsp_ordenProduccion_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (116, 'Ver orden de producción', 'Permite a un usuario instanciar una orden de producción', 'zsp_ordenProduccion_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (117, 'Pasar a pendiente orden de producción', 'Permite a un usuario pasar a pendiente una orden de producción', 'zsp_ordenProduccion_pasarAPendiente');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (118, 'Buscar órdenes de producción', 'Permite a un usuario buscar órdenes de producción', 'zsp_ordenesProduccion_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (119, 'Modificar orden de producción', 'Permite a un usuario modificar una orden de producción', 'zsp_ordenesProduccion_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (120, 'Crear línea de orden de producción', 'Permite a un usuario crear una linea de orden de producción', 'zsp_lineaOrdenProduccion_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (121, 'Borrar línea de orden de producción', 'Permite a un usuario borrar una linea de orden de producción', 'zsp_lineaOrdenProduccion_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (122, 'Obtener stock de un mueble', 'Permite a un usuario conocer el stock de un producto final', 'zsp_productoFinal_stock');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (123, 'Ver remito', 'Permite a un usuario instanciar un remito a partir de su Id', 'zsp_remito_dame');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (124, 'Borrar orden de producción', 'Permite a un usuario borrar una orden de producción', 'zsp_ordenProduccion_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (125, 'Generar remito de venta', 'Permite a un usuario generar un remito a partir de una venta', 'zsp_venta_generar_remito');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (126, 'Modificar domicilio de una venta', 'Permite a un usuario modificar el domicilio de una venta', 'zsp_venta_modificar_domicilio');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (127, 'Dame multiple ventas', 'Permite a un usuario instanciar múltiple ventas desde la base de datos', 'zsp_ventas_dame_multiple');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (128, 'Generar orden de producción', 'Permite a un usuario generar una orden de producción a partir de una o más ventas', 'zsp_venta_generarOrdenProduccion');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (129, 'Cancelar línea de orden de producción', 'Permite a un usuario cancelar una linea de orden de producción', 'zsp_lineaOrdenProduccion_cancelar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (130, 'Reanudar línea de orden de producción', 'Permite a un usuarior reanudar una linea de orden de producción', 'zsp_lineaOrdenProduccion_reanudar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (131, 'Listar tareas línea orden de producción', 'Permite a un usuario listar las tareas de una linea de orden de producción', 'zsp_lineaOrdenProduccion_listar_tareas');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (132, 'Crear tarea', 'Permite a un usuario crear una tarea para una linea de orden de producción', 'zsp_tareas_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (133, 'Borrar tarea', 'Permite a un usuario borrar una tarea de una linea de orden de producción', 'zsp_tareas_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (134, 'Ejecutar tarea', 'Permite iniciar la ejecución de una tarea', 'zsp_tareas_ejecutar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (135, 'Pausar tarea', 'Permite pausar la ejecución de una tarea', 'zsp_tareas_pausar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (136, 'Reanudar tarea', 'Permite reanudar la ejecución de una tarea', 'zsp_tareas_reanudar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (137, 'Cancelar tarea', 'Permite cancelar la ejecución de una tarea', 'zsp_tareas_cancelar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (138, 'Finalizar tarea', 'Permite finalizar la ejecución de una tarea', 'zsp_tareas_finalizar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (139, 'Verificar tarea', 'Permite verificar la correcta ejecución de una tarea', 'zsp_tareas_verificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (140, 'Mover producto', 'Permite a un usuario mover un producto de una ubicación a otra', 'zsp_productoFinal_mover');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (141, 'Verificar línea de orden de producción', 'Permite a un usuario verificar que una o mas lineas de órden de producción estan verificadas', 'zsp_lineasOrdenProduccion_verificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (142, 'Reporte stock', 'Permite generar un reporte del stock total', 'zsp_reportes_stock');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (143, 'Generar lista de precios', 'Permite generar un documento con la lista de precios', 'zsp_reportes_listaPrecios');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (144, 'Generar lista de precios de telas', 'Permite generar un documento con la lista de precios de las telas', 'zsp_reportes_listaPreciosTelas');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (145, 'Generar lista de precios de productos', 'Permite generar un documento con la lista de precios de los productos', 'zsp_reportes_listaPreciosProductos');
/* Carga inicial PermisosRol Administradores */
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 1);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 2);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 3);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 4);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 5);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 6);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 7);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 8);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 9);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 10);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 11);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 12);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 13);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 14);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 15);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 16);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 17);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 18);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 19);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 20);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 21);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 22);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 23);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 24);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 25);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 26);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 27);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 28);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 29);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 30);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 31);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 32);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 33);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 34);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 35);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 36);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 37);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 38);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 39);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 40);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 41);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 42);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 43);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 44);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 45);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 46);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 47);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 48);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 49);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 50);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 51);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 52);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 53);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 54);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 55);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 56);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 57);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 58);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 59);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 60);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 61);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 62);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 63);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 64);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 65);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 66);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 67);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 68);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 69);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 70);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 71);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 72);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 73);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 74);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 75);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 76);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 77);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 78);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 79);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 80);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 81);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 82);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 83);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 84);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 85);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 86);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 87);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 88);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 89);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 90);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 91);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 92);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 93);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 94);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 95);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 96);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 97);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 98);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 99);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 100);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 101);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 102);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 103);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 104);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 105);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 106);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 107);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 108);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 109);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 110);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 111);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 112);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 113);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 114);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 115);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 116);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 117);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 118);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 119);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 120);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 121);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 122);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 123);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 124);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 125);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 126);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 127);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 128);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 129);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 130);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 131);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 132);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 133);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 134);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 135);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 136);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 137);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 138);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 139);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 140);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 141);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 142);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 143);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 144);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (1, 145);

/* Carga inicial PermisosRol Vendedores */
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 11);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 13);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 14);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 15);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 23);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 24);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 26);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 34);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 40);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 46);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 49);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 50);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 51);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 52);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 53);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 54);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 59);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 62);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 64);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 65);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 66);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 67);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 69);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 72);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 75);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 76);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 77);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 78);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 79);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 82);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 83);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 84);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 85);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 87);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 89);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 90);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 91);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 95);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 96);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 97);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 98);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 99);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 100);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 101);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 103);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 104);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 106);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 122);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 123);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 125);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 126);

/* Carga inicial PermisosRol Fabricantes */
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 11);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 13);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 50);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 59);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 131);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 134);
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 138);

/* Carga inicial parametros empresa */
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (1, 'MAXINTPASS', 'Maximo de intentos permitidos ingresando contrasena incorrecta, antes de bloquear al usuario', '3');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (2, 'TIEMPOINTENTOS', 'Tiempo desde el ultimo intento en minutos, si se supera en dicha cantidad el tiempo desde la fecha del ultimo intento, los intentos se vuelven a contar desde cero.', '30');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (3, 'IDROLADMINISTRADOR', 'Identificador del rol de administradores.', '1');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (4, 'IDROLVENDEDOR', 'Identificador del rol de vendedores.', '2');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (5, 'IDROLFABRICANTE', 'Identificador del rol de fabricantes.', '3');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (6, 'IDTIPODOCUMENTOCUIT', 'Identificar del tipo de documento CUIT', '3');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (7, 'LONGITUDPAGINA', 'Longitud de una pagina por defecto', '10');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (8, 'MAXIMALONGITUDPAGINA', 'Maxima longitud pagina', '24');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (9, 'PERIODOVALIDEZ', 'Periodo de validez en días de los presupuestos', '15');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (10, 'IDTIPOPRODUCTOFABRICABLE', 'Identidficador de los productos fabricable', 'P');

/* -------------------------------- RESTANTE ----------------------------- */

/*Carga inicial TiposDocumento*/
INSERT INTO `TiposDocumento` (`IdTipoDocumento`, `TipoDocumento`, `Descripcion`) VALUES (1, 'DNI', 'Documento Nacional de Identidad');
INSERT INTO `TiposDocumento` (`IdTipoDocumento`, `TipoDocumento`, `Descripcion`) VALUES (2, 'Pasaporte', 'Pasaporte');
INSERT INTO `TiposDocumento` (`IdTipoDocumento`, `TipoDocumento`, `Descripcion`) VALUES (3, 'CUIT', 'Clave Única de Identificación Tributaria');
INSERT INTO `TiposDocumento` (`IdTipoDocumento`, `TipoDocumento`, `Descripcion`) VALUES (4, 'CUIL', 'Clave Única de Identificación Laboral');

/* Carga inicial Países */
INSERT INTO Paises VALUES ('AR', 'Argentina');

/* Carga inicial Provincias */
INSERT INTO Provincias VALUES (1, 'AR', 'Buenos Aires'),
(2, 'AR', 'Buenos Aires-GBA'),
(3, 'AR', 'Capital Federal'),
(4, 'AR', 'Catamarca'),
(5, 'AR', 'Chaco'),
(6, 'AR', 'Chubut'),
(7, 'AR', 'Córdoba'),
(8, 'AR', 'Corrientes'),
(9, 'AR', 'Entre Ríos'),
(10, 'AR', 'Formosa'),
(11, 'AR', 'Jujuy'),
(12, 'AR', 'La Pampa'),
(13, 'AR', 'La Rioja'),
(14, 'AR', 'Mendoza'),
(15, 'AR', 'Misiones'),
(16, 'AR', 'Neuquén'),
(17, 'AR', 'Río Negro'),
(18, 'AR', 'Salta'),
(19, 'AR', 'San Juan'),
(20, 'AR', 'San Luis'),
(21, 'AR', 'Santa Cruz'),
(22, 'AR', 'Santa Fe'),
(23, 'AR', 'Santiago del Estero'),
(24, 'AR', 'Tierra del Fuego'),
(25, 'AR', 'Tucumán');

/* Carga inicial Ciudades */
INSERT INTO Ciudades VALUES
(1, 1, 'AR', '25 de Mayo'),
(2, 1, 'AR', '3 de febrero'),
(3, 1, 'AR', 'A. Alsina'),
(4, 1, 'AR', 'A. Gonzáles Cháves'),
(5, 1, 'AR', 'Aguas Verdes'),
(6, 1, 'AR', 'Alberti'),
(7, 1, 'AR', 'Arrecifes'),
(8, 1, 'AR', 'Ayacucho'),
(9, 1, 'AR', 'Azul'),
(10, 1, 'AR', 'Bahía Blanca'),
(11, 1, 'AR', 'Balcarce'),
(12, 1, 'AR', 'Baradero'),
(13, 1, 'AR', 'Benito Juárez'),
(14, 1, 'AR', 'Berisso'),
(15, 1, 'AR', 'Bolívar'),
(16, 1, 'AR', 'Bragado'),
(17, 1, 'AR', 'Brandsen'),
(18, 1, 'AR', 'Campana'),
(19, 1, 'AR', 'Cañuelas'),
(20, 1, 'AR', 'Capilla del Señor'),
(21, 1, 'AR', 'Capitán Sarmiento'),
(22, 1, 'AR', 'Carapachay'),
(23, 1, 'AR', 'Carhue'),
(24, 1, 'AR', 'Cariló'),
(25, 1, 'AR', 'Carlos Casares'),
(26, 1, 'AR', 'Carlos Tejedor'),
(27, 1, 'AR', 'Carmen de Areco'),
(28, 1, 'AR', 'Carmen de Patagones'),
(29, 1, 'AR', 'Castelli'),
(30, 1, 'AR', 'Chacabuco'),
(31, 1, 'AR', 'Chascomús'),
(32, 1, 'AR', 'Chivilcoy'),
(33, 1, 'AR', 'Colón'),
(34, 1, 'AR', 'Coronel Dorrego'),
(35, 1, 'AR', 'Coronel Pringles'),
(36, 1, 'AR', 'Coronel Rosales'),
(37, 1, 'AR', 'Coronel Suarez'),
(38, 1, 'AR', 'Costa Azul'),
(39, 1, 'AR', 'Costa Chica'),
(40, 1, 'AR', 'Costa del Este'),
(41, 1, 'AR', 'Costa Esmeralda'),
(42, 1, 'AR', 'Daireaux'),
(43, 1, 'AR', 'Darregueira'),
(44, 1, 'AR', 'Del Viso'),
(45, 1, 'AR', 'Dolores'),
(46, 1, 'AR', 'Don Torcuato'),
(47, 1, 'AR', 'Ensenada'),
(48, 1, 'AR', 'Escobar'),
(49, 1, 'AR', 'Exaltación de la Cruz'),
(50, 1, 'AR', 'Florentino Ameghino'),
(51, 1, 'AR', 'Garín'),
(52, 1, 'AR', 'Gral. Alvarado'),
(53, 1, 'AR', 'Gral. Alvear'),
(54, 1, 'AR', 'Gral. Arenales'),
(55, 1, 'AR', 'Gral. Belgrano'),
(56, 1, 'AR', 'Gral. Guido'),
(57, 1, 'AR', 'Gral. Lamadrid'),
(58, 1, 'AR', 'Gral. Las Heras'),
(59, 1, 'AR', 'Gral. Lavalle'),
(60, 1, 'AR', 'Gral. Madariaga'),
(61, 1, 'AR', 'Gral. Pacheco'),
(62, 1, 'AR', 'Gral. Paz'),
(63, 1, 'AR', 'Gral. Pinto'),
(64, 1, 'AR', 'Gral. Pueyrredón'),
(65, 1, 'AR', 'Gral. Rodríguez'),
(66, 1, 'AR', 'Gral. Viamonte'),
(67, 1, 'AR', 'Gral. Villegas'),
(68, 1, 'AR', 'Guaminí'),
(69, 1, 'AR', 'Guernica'),
(70, 1, 'AR', 'Hipólito Yrigoyen'),
(71, 1, 'AR', 'Ing. Maschwitz'),
(72, 1, 'AR', 'Junín'),
(73, 1, 'AR', 'La Plata'),
(74, 1, 'AR', 'Laprida'),
(75, 1, 'AR', 'Las Flores'),
(76, 1, 'AR', 'Las Toninas'),
(77, 1, 'AR', 'Leandro N. Alem'),
(78, 1, 'AR', 'Lincoln'),
(79, 1, 'AR', 'Loberia'),
(80, 1, 'AR', 'Lobos'),
(81, 1, 'AR', 'Los Cardales'),
(82, 1, 'AR', 'Los Toldos'),
(83, 1, 'AR', 'Lucila del Mar'),
(84, 1, 'AR', 'Luján'),
(85, 1, 'AR', 'Magdalena'),
(86, 1, 'AR', 'Maipú'),
(87, 1, 'AR', 'Mar Chiquita'),
(88, 1, 'AR', 'Mar de Ajó'),
(89, 1, 'AR', 'Mar de las Pampas'),
(90, 1, 'AR', 'Mar del Plata'),
(91, 1, 'AR', 'Mar del Tuyú'),
(92, 1, 'AR', 'Marcos Paz'),
(93, 1, 'AR', 'Mercedes'),
(94, 1, 'AR', 'Miramar'),
(95, 1, 'AR', 'Monte'),
(96, 1, 'AR', 'Monte Hermoso'),
(97, 1, 'AR', 'Munro'),
(98, 1, 'AR', 'Navarro'),
(99, 1, 'AR', 'Necochea'),
(100, 1, 'AR', 'Olavarría'),
(101, 1, 'AR', 'Partido de la Costa'),
(102, 1, 'AR', 'Pehuajó'),
(103, 1, 'AR', 'Pellegrini'),
(104, 1, 'AR', 'Pergamino'),
(105, 1, 'AR', 'Pigüé'),
(106, 1, 'AR', 'Pila'),
(107, 1, 'AR', 'Pilar'),
(108, 1, 'AR', 'Pinamar'),
(109, 1, 'AR', 'Pinar del Sol'),
(110, 1, 'AR', 'Polvorines'),
(111, 1, 'AR', 'Pte. Perón'),
(112, 1, 'AR', 'Puán'),
(113, 1, 'AR', 'Punta Indio'),
(114, 1, 'AR', 'Ramallo'),
(115, 1, 'AR', 'Rauch'),
(116, 1, 'AR', 'Rivadavia'),
(117, 1, 'AR', 'Rojas'),
(118, 1, 'AR', 'Roque Pérez'),
(119, 1, 'AR', 'Saavedra'),
(120, 1, 'AR', 'Saladillo'),
(121, 1, 'AR', 'Salliqueló'),
(122, 1, 'AR', 'Salto'),
(123, 1, 'AR', 'San Andrés de Giles'),
(124, 1, 'AR', 'San Antonio de Areco'),
(125, 1, 'AR', 'San Antonio de Padua'),
(126, 1, 'AR', 'San Bernardo'),
(127, 1, 'AR', 'San Cayetano'),
(128, 1, 'AR', 'San Clemente del Tuyú'),
(129, 1, 'AR', 'San Nicolás'),
(130, 1, 'AR', 'San Pedro'),
(131, 1, 'AR', 'San Vicente'),
(132, 1, 'AR', 'Santa Teresita'),
(133, 1, 'AR', 'Suipacha'),
(134, 1, 'AR', 'Tandil'),
(135, 1, 'AR', 'Tapalqué'),
(136, 1, 'AR', 'Tordillo'),
(137, 1, 'AR', 'Tornquist'),
(138, 1, 'AR', 'Trenque Lauquen'),
(139, 1, 'AR', 'Tres Lomas'),
(140, 1, 'AR', 'Villa Gesell'),
(141, 1, 'AR', 'Villarino'),
(142, 1, 'AR', 'Zárate'),
(143, 2, 'AR', '11 de Septiembre'),
(144, 2, 'AR', '20 de Junio'),
(145, 2, 'AR', '25 de Mayo'),
(146, 2, 'AR', 'Acassuso'),
(147, 2, 'AR', 'Adrogué'),
(148, 2, 'AR', 'Aldo Bonzi'),
(149, 2, 'AR', 'Área Reserva Cinturón Ecológico'),
(150, 2, 'AR', 'Avellaneda'),
(151, 2, 'AR', 'Banfield'),
(152, 2, 'AR', 'Barrio Parque'),
(153, 2, 'AR', 'Barrio Santa Teresita'),
(154, 2, 'AR', 'Beccar'),
(155, 2, 'AR', 'Bella Vista'),
(156, 2, 'AR', 'Berazategui'),
(157, 2, 'AR', 'Bernal Este'),
(158, 2, 'AR', 'Bernal Oeste'),
(159, 2, 'AR', 'Billinghurst'),
(160, 2, 'AR', 'Boulogne'),
(161, 2, 'AR', 'Burzaco'),
(162, 2, 'AR', 'Carapachay'),
(163, 2, 'AR', 'Caseros'),
(164, 2, 'AR', 'Castelar'),
(165, 2, 'AR', 'Churruca'),
(166, 2, 'AR', 'Ciudad Evita'),
(167, 2, 'AR', 'Ciudad Madero'),
(168, 2, 'AR', 'Ciudadela'),
(169, 2, 'AR', 'Claypole'),
(170, 2, 'AR', 'Crucecita'),
(171, 2, 'AR', 'Dock Sud'),
(172, 2, 'AR', 'Don Bosco'),
(173, 2, 'AR', 'Don Orione'),
(174, 2, 'AR', 'El Jagüel'),
(175, 2, 'AR', 'El Libertador'),
(176, 2, 'AR', 'El Palomar'),
(177, 2, 'AR', 'El Tala'),
(178, 2, 'AR', 'El Trébol'),
(179, 2, 'AR', 'Ezeiza'),
(180, 2, 'AR', 'Ezpeleta'),
(181, 2, 'AR', 'Florencio Varela'),
(182, 2, 'AR', 'Florida'),
(183, 2, 'AR', 'Francisco Álvarez'),
(184, 2, 'AR', 'Gerli'),
(185, 2, 'AR', 'Glew'),
(186, 2, 'AR', 'González Catán'),
(187, 2, 'AR', 'Gral. Lamadrid'),
(188, 2, 'AR', 'Grand Bourg'),
(189, 2, 'AR', 'Gregorio de Laferrere'),
(190, 2, 'AR', 'Guillermo Enrique Hudson'),
(191, 2, 'AR', 'Haedo'),
(192, 2, 'AR', 'Hurlingham'),
(193, 2, 'AR', 'Ing. Sourdeaux'),
(194, 2, 'AR', 'Isidro Casanova'),
(195, 2, 'AR', 'Ituzaingó'),
(196, 2, 'AR', 'José C. Paz'),
(197, 2, 'AR', 'José Ingenieros'),
(198, 2, 'AR', 'José Marmol'),
(199, 2, 'AR', 'La Lucila'),
(200, 2, 'AR', 'La Reja'),
(201, 2, 'AR', 'La Tablada'),
(202, 2, 'AR', 'Lanús'),
(203, 2, 'AR', 'Llavallol'),
(204, 2, 'AR', 'Loma Hermosa'),
(205, 2, 'AR', 'Lomas de Zamora'),
(206, 2, 'AR', 'Lomas del Millón'),
(207, 2, 'AR', 'Lomas del Mirador'),
(208, 2, 'AR', 'Longchamps'),
(209, 2, 'AR', 'Los Polvorines'),
(210, 2, 'AR', 'Luis Guillón'),
(211, 2, 'AR', 'Malvinas Argentinas'),
(212, 2, 'AR', 'Martín Coronado'),
(213, 2, 'AR', 'Martínez'),
(214, 2, 'AR', 'Merlo'),
(215, 2, 'AR', 'Ministro Rivadavia'),
(216, 2, 'AR', 'Monte Chingolo'),
(217, 2, 'AR', 'Monte Grande'),
(218, 2, 'AR', 'Moreno'),
(219, 2, 'AR', 'Morón'),
(220, 2, 'AR', 'Muñiz'),
(221, 2, 'AR', 'Olivos'),
(222, 2, 'AR', 'Pablo Nogués'),
(223, 2, 'AR', 'Pablo Podestá'),
(224, 2, 'AR', 'Paso del Rey'),
(225, 2, 'AR', 'Pereyra'),
(226, 2, 'AR', 'Piñeiro'),
(227, 2, 'AR', 'Plátanos'),
(228, 2, 'AR', 'Pontevedra'),
(229, 2, 'AR', 'Quilmes'),
(230, 2, 'AR', 'Rafael Calzada'),
(231, 2, 'AR', 'Rafael Castillo'),
(232, 2, 'AR', 'Ramos Mejía'),
(233, 2, 'AR', 'Ranelagh'),
(234, 2, 'AR', 'Remedios de Escalada'),
(235, 2, 'AR', 'Sáenz Peña'),
(236, 2, 'AR', 'San Antonio de Padua'),
(237, 2, 'AR', 'San Fernando'),
(238, 2, 'AR', 'San Francisco Solano'),
(239, 2, 'AR', 'San Isidro'),
(240, 2, 'AR', 'San José'),
(241, 2, 'AR', 'San Justo'),
(242, 2, 'AR', 'San Martín'),
(243, 2, 'AR', 'San Miguel'),
(244, 2, 'AR', 'Santos Lugares'),
(245, 2, 'AR', 'Sarandí'),
(246, 2, 'AR', 'Sourigues'),
(247, 2, 'AR', 'Tapiales'),
(248, 2, 'AR', 'Temperley'),
(249, 2, 'AR', 'Tigre'),
(250, 2, 'AR', 'Tortuguitas'),
(251, 2, 'AR', 'Tristán Suárez'),
(252, 2, 'AR', 'Trujui'),
(253, 2, 'AR', 'Turdera'),
(254, 2, 'AR', 'Valentín Alsina'),
(255, 2, 'AR', 'Vicente López'),
(256, 2, 'AR', 'Villa Adelina'),
(257, 2, 'AR', 'Villa Ballester'),
(258, 2, 'AR', 'Villa Bosch'),
(259, 2, 'AR', 'Villa Caraza'),
(260, 2, 'AR', 'Villa Celina'),
(261, 2, 'AR', 'Villa Centenario'),
(262, 2, 'AR', 'Villa de Mayo'),
(263, 2, 'AR', 'Villa Diamante'),
(264, 2, 'AR', 'Villa Domínico'),
(265, 2, 'AR', 'Villa España'),
(266, 2, 'AR', 'Villa Fiorito'),
(267, 2, 'AR', 'Villa Guillermina'),
(268, 2, 'AR', 'Villa Insuperable'),
(269, 2, 'AR', 'Villa José León Suárez'),
(270, 2, 'AR', 'Villa La Florida'),
(271, 2, 'AR', 'Villa Luzuriaga'),
(272, 2, 'AR', 'Villa Martelli'),
(273, 2, 'AR', 'Villa Obrera'),
(274, 2, 'AR', 'Villa Progreso'),
(275, 2, 'AR', 'Villa Raffo'),
(276, 2, 'AR', 'Villa Sarmiento'),
(277, 2, 'AR', 'Villa Tesei'),
(278, 2, 'AR', 'Villa Udaondo'),
(279, 2, 'AR', 'Virrey del Pino'),
(280, 2, 'AR', 'Wilde'),
(281, 2, 'AR', 'William Morris'),
(282, 3, 'AR', 'Agronomía'),
(283, 3, 'AR', 'Almagro'),
(284, 3, 'AR', 'Balvanera'),
(285, 3, 'AR', 'Barracas'),
(286, 3, 'AR', 'Belgrano'),
(287, 3, 'AR', 'Boca'),
(288, 3, 'AR', 'Boedo'),
(289, 3, 'AR', 'Caballito'),
(290, 3, 'AR', 'Chacarita'),
(291, 3, 'AR', 'Coghlan'),
(292, 3, 'AR', 'Colegiales'),
(293, 3, 'AR', 'Constitución'),
(294, 3, 'AR', 'Flores'),
(295, 3, 'AR', 'Floresta'),
(296, 3, 'AR', 'La Paternal'),
(297, 3, 'AR', 'Liniers'),
(298, 3, 'AR', 'Mataderos'),
(299, 3, 'AR', 'Monserrat'),
(300, 3, 'AR', 'Monte Castro'),
(301, 3, 'AR', 'Nueva Pompeya'),
(302, 3, 'AR', 'Núñez'),
(303, 3, 'AR', 'Palermo'),
(304, 3, 'AR', 'Parque Avellaneda'),
(305, 3, 'AR', 'Parque Chacabuco'),
(306, 3, 'AR', 'Parque Chas'),
(307, 3, 'AR', 'Parque Patricios'),
(308, 3, 'AR', 'Puerto Madero'),
(309, 3, 'AR', 'Recoleta'),
(310, 3, 'AR', 'Retiro'),
(311, 3, 'AR', 'Saavedra'),
(312, 3, 'AR', 'San Cristóbal'),
(313, 3, 'AR', 'San Nicolás'),
(314, 3, 'AR', 'San Telmo'),
(315, 3, 'AR', 'Vélez Sársfield'),
(316, 3, 'AR', 'Versalles'),
(317, 3, 'AR', 'Villa Crespo'),
(318, 3, 'AR', 'Villa del Parque'),
(319, 3, 'AR', 'Villa Devoto'),
(320, 3, 'AR', 'Villa Gral. Mitre'),
(321, 3, 'AR', 'Villa Lugano'),
(322, 3, 'AR', 'Villa Luro'),
(323, 3, 'AR', 'Villa Ortúzar'),
(324, 3, 'AR', 'Villa Pueyrredón'),
(325, 3, 'AR', 'Villa Real'),
(326, 3, 'AR', 'Villa Riachuelo'),
(327, 3, 'AR', 'Villa Santa Rita'),
(328, 3, 'AR', 'Villa Soldati'),
(329, 3, 'AR', 'Villa Urquiza'),
(330, 4, 'AR', 'Aconquija'),
(331, 4, 'AR', 'Ancasti'),
(332, 4, 'AR', 'Andalgalá'),
(333, 4, 'AR', 'Antofagasta'),
(334, 4, 'AR', 'Belén'),
(335, 4, 'AR', 'Capayán'),
(336, 4, 'AR', 'Capital'),
(337, 4, 'AR', '4'),
(338, 4, 'AR', 'Corral Quemado'),
(339, 4, 'AR', 'El Alto'),
(340, 4, 'AR', 'El Rodeo'),
(341, 4, 'AR', 'F.Mamerto Esquiú'),
(342, 4, 'AR', 'Fiambalá'),
(343, 4, 'AR', 'Hualfín'),
(344, 4, 'AR', 'Huillapima'),
(345, 4, 'AR', 'Icaño'),
(346, 4, 'AR', 'La Puerta'),
(347, 4, 'AR', 'Las Juntas'),
(348, 4, 'AR', 'Londres'),
(349, 4, 'AR', 'Los Altos'),
(350, 4, 'AR', 'Los Varela'),
(351, 4, 'AR', 'Mutquín'),
(352, 4, 'AR', 'Paclín'),
(353, 4, 'AR', 'Poman'),
(354, 4, 'AR', 'Pozo de La Piedra'),
(355, 4, 'AR', 'Puerta de Corral'),
(356, 4, 'AR', 'Puerta San José'),
(357, 4, 'AR', 'Recreo'),
(358, 4, 'AR', 'S.F.V de 4'),
(359, 4, 'AR', 'San Fernando'),
(360, 4, 'AR', 'San Fernando del Valle'),
(361, 4, 'AR', 'San José'),
(362, 4, 'AR', 'Santa María'),
(363, 4, 'AR', 'Santa Rosa'),
(364, 4, 'AR', 'Saujil'),
(365, 4, 'AR', 'Tapso'),
(366, 4, 'AR', 'Tinogasta'),
(367, 4, 'AR', 'Valle Viejo'),
(368, 4, 'AR', 'Villa Vil'),
(369, 5, 'AR', 'Aviá Teraí'),
(370, 5, 'AR', 'Barranqueras'),
(371, 5, 'AR', 'Basail'),
(372, 5, 'AR', 'Campo Largo'),
(373, 5, 'AR', 'Capital'),
(374, 5, 'AR', 'Capitán Solari'),
(375, 5, 'AR', 'Charadai'),
(376, 5, 'AR', 'Charata'),
(377, 5, 'AR', 'Chorotis'),
(378, 5, 'AR', 'Ciervo Petiso'),
(379, 5, 'AR', 'Cnel. Du Graty'),
(380, 5, 'AR', 'Col. Benítez'),
(381, 5, 'AR', 'Col. Elisa'),
(382, 5, 'AR', 'Col. Popular'),
(383, 5, 'AR', 'Colonias Unidas'),
(384, 5, 'AR', 'Concepción'),
(385, 5, 'AR', 'Corzuela'),
(386, 5, 'AR', 'Cote Lai'),
(387, 5, 'AR', 'El Sauzalito'),
(388, 5, 'AR', 'Enrique Urien'),
(389, 5, 'AR', 'Fontana'),
(390, 5, 'AR', 'Fte. Esperanza'),
(391, 5, 'AR', 'Gancedo'),
(392, 5, 'AR', 'Gral. Capdevila'),
(393, 5, 'AR', 'Gral. Pinero'),
(394, 5, 'AR', 'Gral. San Martín'),
(395, 5, 'AR', 'Gral. Vedia'),
(396, 5, 'AR', 'Hermoso Campo'),
(397, 5, 'AR', 'I. del Cerrito'),
(398, 5, 'AR', 'J.J. Castelli'),
(399, 5, 'AR', 'La Clotilde'),
(400, 5, 'AR', 'La Eduvigis'),
(401, 5, 'AR', 'La Escondida'),
(402, 5, 'AR', 'La Leonesa'),
(403, 5, 'AR', 'La Tigra'),
(404, 5, 'AR', 'La Verde'),
(405, 5, 'AR', 'Laguna Blanca'),
(406, 5, 'AR', 'Laguna Limpia'),
(407, 5, 'AR', 'Lapachito'),
(408, 5, 'AR', 'Las Breñas'),
(409, 5, 'AR', 'Las Garcitas'),
(410, 5, 'AR', 'Las Palmas'),
(411, 5, 'AR', 'Los Frentones'),
(412, 5, 'AR', 'Machagai'),
(413, 5, 'AR', 'Makallé'),
(414, 5, 'AR', 'Margarita Belén'),
(415, 5, 'AR', 'Miraflores'),
(416, 5, 'AR', 'Misión N. Pompeya'),
(417, 5, 'AR', 'Napenay'),
(418, 5, 'AR', 'Pampa Almirón'),
(419, 5, 'AR', 'Pampa del Indio'),
(420, 5, 'AR', 'Pampa del Infierno'),
(421, 5, 'AR', 'Pdcia. de La Plaza'),
(422, 5, 'AR', 'Pdcia. Roca'),
(423, 5, 'AR', 'Pdcia. Roque Sáenz Peña'),
(424, 5, 'AR', 'Pto. Bermejo'),
(425, 5, 'AR', 'Pto. Eva Perón'),
(426, 5, 'AR', 'Puero Tirol'),
(427, 5, 'AR', 'Puerto Vilelas'),
(428, 5, 'AR', 'Quitilipi'),
(429, 5, 'AR', 'Resistencia'),
(430, 5, 'AR', 'Sáenz Peña'),
(431, 5, 'AR', 'Samuhú'),
(432, 5, 'AR', 'San Bernardo'),
(433, 5, 'AR', 'Santa Sylvina'),
(434, 5, 'AR', 'Taco Pozo'),
(435, 5, 'AR', 'Tres Isletas'),
(436, 5, 'AR', 'Villa Ángela'),
(437, 5, 'AR', 'Villa Berthet'),
(438, 5, 'AR', 'Villa R. Bermejito'),
(439, 6, 'AR', 'Aldea Apeleg'),
(440, 6, 'AR', 'Aldea Beleiro'),
(441, 6, 'AR', 'Aldea Epulef'),
(442, 6, 'AR', 'Alto Río Sengerr'),
(443, 6, 'AR', 'Buen Pasto'),
(444, 6, 'AR', 'Camarones'),
(445, 6, 'AR', 'Carrenleufú'),
(446, 6, 'AR', 'Cholila'),
(447, 6, 'AR', 'Co. Centinela'),
(448, 6, 'AR', 'Colan Conhué'),
(449, 6, 'AR', 'Comodoro Rivadavia'),
(450, 6, 'AR', 'Corcovado'),
(451, 6, 'AR', 'Cushamen'),
(452, 6, 'AR', 'Dique F. Ameghino'),
(453, 6, 'AR', 'Dolavón'),
(454, 6, 'AR', 'Dr. R. Rojas'),
(455, 6, 'AR', 'El Hoyo'),
(456, 6, 'AR', 'El Maitén'),
(457, 6, 'AR', 'Epuyén'),
(458, 6, 'AR', 'Esquel'),
(459, 6, 'AR', 'Facundo'),
(460, 6, 'AR', 'Gaimán'),
(461, 6, 'AR', 'Gan Gan'),
(462, 6, 'AR', 'Gastre'),
(463, 6, 'AR', 'Gdor. Costa'),
(464, 6, 'AR', 'Gualjaina'),
(465, 6, 'AR', 'J. de San Martín'),
(466, 6, 'AR', 'Lago Blanco'),
(467, 6, 'AR', 'Lago Puelo'),
(468, 6, 'AR', 'Lagunita Salada'),
(469, 6, 'AR', 'Las Plumas'),
(470, 6, 'AR', 'Los Altares'),
(471, 6, 'AR', 'Paso de los Indios'),
(472, 6, 'AR', 'Paso del Sapo'),
(473, 6, 'AR', 'Pto. Madryn'),
(474, 6, 'AR', 'Pto. Pirámides'),
(475, 6, 'AR', 'Rada Tilly'),
(476, 6, 'AR', 'Rawson'),
(477, 6, 'AR', 'Río Mayo'),
(478, 6, 'AR', 'Río Pico'),
(479, 6, 'AR', 'Sarmiento'),
(480, 6, 'AR', 'Tecka'),
(481, 6, 'AR', 'Telsen'),
(482, 6, 'AR', 'Trelew'),
(483, 6, 'AR', 'Trevelin'),
(484, 6, 'AR', 'Veintiocho de Julio'),
(485, 7, 'AR', 'Achiras'),
(486, 7, 'AR', 'Adelia Maria'),
(487, 7, 'AR', 'Agua de Oro'),
(488, 7, 'AR', 'Alcira Gigena'),
(489, 7, 'AR', 'Aldea Santa Maria'),
(490, 7, 'AR', 'Alejandro Roca'),
(491, 7, 'AR', 'Alejo Ledesma'),
(492, 7, 'AR', 'Alicia'),
(493, 7, 'AR', 'Almafuerte'),
(494, 7, 'AR', 'Alpa Corral'),
(495, 7, 'AR', 'Alta Gracia'),
(496, 7, 'AR', 'Alto Alegre'),
(497, 7, 'AR', 'Alto de Los Quebrachos'),
(498, 7, 'AR', 'Altos de Chipion'),
(499, 7, 'AR', 'Amboy'),
(500, 7, 'AR', 'Ambul'),
(501, 7, 'AR', 'Ana Zumaran'),
(502, 7, 'AR', 'Anisacate'),
(503, 7, 'AR', 'Arguello'),
(504, 7, 'AR', 'Arias'),
(505, 7, 'AR', 'Arroyito'),
(506, 7, 'AR', 'Arroyo Algodon'),
(507, 7, 'AR', 'Arroyo Cabral'),
(508, 7, 'AR', 'Arroyo Los Patos'),
(509, 7, 'AR', 'Assunta'),
(510, 7, 'AR', 'Atahona'),
(511, 7, 'AR', 'Ausonia'),
(512, 7, 'AR', 'Avellaneda'),
(513, 7, 'AR', 'Ballesteros'),
(514, 7, 'AR', 'Ballesteros Sud'),
(515, 7, 'AR', 'Balnearia'),
(516, 7, 'AR', 'Bañado de Soto'),
(517, 7, 'AR', 'Bell Ville'),
(518, 7, 'AR', 'Bengolea'),
(519, 7, 'AR', 'Benjamin Gould'),
(520, 7, 'AR', 'Berrotaran'),
(521, 7, 'AR', 'Bialet Masse'),
(522, 7, 'AR', 'Bouwer'),
(523, 7, 'AR', 'Brinkmann'),
(524, 7, 'AR', 'Buchardo'),
(525, 7, 'AR', 'Bulnes'),
(526, 7, 'AR', 'Cabalango'),
(527, 7, 'AR', 'Calamuchita'),
(528, 7, 'AR', 'Calchin'),
(529, 7, 'AR', 'Calchin Oeste'),
(530, 7, 'AR', 'Calmayo'),
(531, 7, 'AR', 'Camilo Aldao'),
(532, 7, 'AR', 'Caminiaga'),
(533, 7, 'AR', 'Cañada de Luque'),
(534, 7, 'AR', 'Cañada de Machado'),
(535, 7, 'AR', 'Cañada de Rio Pinto'),
(536, 7, 'AR', 'Cañada del Sauce'),
(537, 7, 'AR', 'Canals'),
(538, 7, 'AR', 'Candelaria Sud'),
(539, 7, 'AR', 'Capilla de Remedios'),
(540, 7, 'AR', 'Capilla de Siton'),
(541, 7, 'AR', 'Capilla del Carmen'),
(542, 7, 'AR', 'Capilla del Monte'),
(543, 7, 'AR', 'Capital'),
(544, 7, 'AR', 'Capitan Gral B. O´Higgins'),
(545, 7, 'AR', 'Carnerillo'),
(546, 7, 'AR', 'Carrilobo'),
(547, 7, 'AR', 'Casa Grande'),
(548, 7, 'AR', 'Cavanagh'),
(549, 7, 'AR', 'Cerro Colorado'),
(550, 7, 'AR', 'Chaján'),
(551, 7, 'AR', 'Chalacea'),
(552, 7, 'AR', 'Chañar Viejo'),
(553, 7, 'AR', 'Chancaní'),
(554, 7, 'AR', 'Charbonier'),
(555, 7, 'AR', 'Charras'),
(556, 7, 'AR', 'Chazón'),
(557, 7, 'AR', 'Chilibroste'),
(558, 7, 'AR', 'Chucul'),
(559, 7, 'AR', 'Chuña'),
(560, 7, 'AR', 'Chuña Huasi'),
(561, 7, 'AR', 'Churqui Cañada'),
(562, 7, 'AR', 'Cienaga Del Coro'),
(563, 7, 'AR', 'Cintra'),
(564, 7, 'AR', 'Col. Almada'),
(565, 7, 'AR', 'Col. Anita'),
(566, 7, 'AR', 'Col. Barge'),
(567, 7, 'AR', 'Col. Bismark'),
(568, 7, 'AR', 'Col. Bremen'),
(569, 7, 'AR', 'Col. Caroya'),
(570, 7, 'AR', 'Col. Italiana'),
(571, 7, 'AR', 'Col. Iturraspe'),
(572, 7, 'AR', 'Col. Las Cuatro Esquinas'),
(573, 7, 'AR', 'Col. Las Pichanas'),
(574, 7, 'AR', 'Col. Marina'),
(575, 7, 'AR', 'Col. Prosperidad'),
(576, 7, 'AR', 'Col. San Bartolome'),
(577, 7, 'AR', 'Col. San Pedro'),
(578, 7, 'AR', 'Col. Tirolesa'),
(579, 7, 'AR', 'Col. Vicente Aguero'),
(580, 7, 'AR', 'Col. Videla'),
(581, 7, 'AR', 'Col. Vignaud'),
(582, 7, 'AR', 'Col. Waltelina'),
(583, 7, 'AR', 'Colazo'),
(584, 7, 'AR', 'Comechingones'),
(585, 7, 'AR', 'Conlara'),
(586, 7, 'AR', 'Copacabana'),
(587, 7, 'AR', '7'),
(588, 7, 'AR', 'Coronel Baigorria'),
(589, 7, 'AR', 'Coronel Moldes'),
(590, 7, 'AR', 'Corral de Bustos'),
(591, 7, 'AR', 'Corralito'),
(592, 7, 'AR', 'Cosquín'),
(593, 7, 'AR', 'Costa Sacate'),
(594, 7, 'AR', 'Cruz Alta'),
(595, 7, 'AR', 'Cruz de Caña'),
(596, 7, 'AR', 'Cruz del Eje'),
(597, 7, 'AR', 'Cuesta Blanca'),
(598, 7, 'AR', 'Dean Funes'),
(599, 7, 'AR', 'Del Campillo'),
(600, 7, 'AR', 'Despeñaderos'),
(601, 7, 'AR', 'Devoto'),
(602, 7, 'AR', 'Diego de Rojas'),
(603, 7, 'AR', 'Dique Chico'),
(604, 7, 'AR', 'El Arañado'),
(605, 7, 'AR', 'El Brete'),
(606, 7, 'AR', 'El Chacho'),
(607, 7, 'AR', 'El Crispín'),
(608, 7, 'AR', 'El Fortín'),
(609, 7, 'AR', 'El Manzano'),
(610, 7, 'AR', 'El Rastreador'),
(611, 7, 'AR', 'El Rodeo'),
(612, 7, 'AR', 'El Tío'),
(613, 7, 'AR', 'Elena'),
(614, 7, 'AR', 'Embalse'),
(615, 7, 'AR', 'Esquina'),
(616, 7, 'AR', 'Estación Gral. Paz'),
(617, 7, 'AR', 'Estación Juárez Celman'),
(618, 7, 'AR', 'Estancia de Guadalupe'),
(619, 7, 'AR', 'Estancia Vieja'),
(620, 7, 'AR', 'Etruria'),
(621, 7, 'AR', 'Eufrasio Loza'),
(622, 7, 'AR', 'Falda del Carmen'),
(623, 7, 'AR', 'Freyre'),
(624, 7, 'AR', 'Gral. Baldissera'),
(625, 7, 'AR', 'Gral. Cabrera'),
(626, 7, 'AR', 'Gral. Deheza'),
(627, 7, 'AR', 'Gral. Fotheringham'),
(628, 7, 'AR', 'Gral. Levalle'),
(629, 7, 'AR', 'Gral. Roca'),
(630, 7, 'AR', 'Guanaco Muerto'),
(631, 7, 'AR', 'Guasapampa'),
(632, 7, 'AR', 'Guatimozin'),
(633, 7, 'AR', 'Gutenberg'),
(634, 7, 'AR', 'Hernando'),
(635, 7, 'AR', 'Huanchillas'),
(636, 7, 'AR', 'Huerta Grande'),
(637, 7, 'AR', 'Huinca Renanco'),
(638, 7, 'AR', 'Idiazabal'),
(639, 7, 'AR', 'Impira'),
(640, 7, 'AR', 'Inriville'),
(641, 7, 'AR', 'Isla Verde'),
(642, 7, 'AR', 'Italó'),
(643, 7, 'AR', 'James Craik'),
(644, 7, 'AR', 'Jesús María'),
(645, 7, 'AR', 'Jovita'),
(646, 7, 'AR', 'Justiniano Posse'),
(647, 7, 'AR', 'Km 658'),
(648, 7, 'AR', 'L. V. Mansilla'),
(649, 7, 'AR', 'La Batea'),
(650, 7, 'AR', 'La Calera'),
(651, 7, 'AR', 'La Carlota'),
(652, 7, 'AR', 'La Carolina'),
(653, 7, 'AR', 'La Cautiva'),
(654, 7, 'AR', 'La Cesira'),
(655, 7, 'AR', 'La Cruz'),
(656, 7, 'AR', 'La Cumbre'),
(657, 7, 'AR', 'La Cumbrecita'),
(658, 7, 'AR', 'La Falda'),
(659, 7, 'AR', 'La Francia'),
(660, 7, 'AR', 'La Granja'),
(661, 7, 'AR', 'La Higuera'),
(662, 7, 'AR', 'La Laguna'),
(663, 7, 'AR', 'La Paisanita'),
(664, 7, 'AR', 'La Palestina'),
(665, 7, 'AR', '12'),
(666, 7, 'AR', 'La Paquita'),
(667, 7, 'AR', 'La Para'),
(668, 7, 'AR', 'La Paz'),
(669, 7, 'AR', 'La Playa'),
(670, 7, 'AR', 'La Playosa'),
(671, 7, 'AR', 'La Población'),
(672, 7, 'AR', 'La Posta'),
(673, 7, 'AR', 'La Puerta'),
(674, 7, 'AR', 'La Quinta'),
(675, 7, 'AR', 'La Rancherita'),
(676, 7, 'AR', 'La Rinconada'),
(677, 7, 'AR', 'La Serranita'),
(678, 7, 'AR', 'La Tordilla'),
(679, 7, 'AR', 'Laborde'),
(680, 7, 'AR', 'Laboulaye'),
(681, 7, 'AR', 'Laguna Larga'),
(682, 7, 'AR', 'Las Acequias'),
(683, 7, 'AR', 'Las Albahacas'),
(684, 7, 'AR', 'Las Arrias'),
(685, 7, 'AR', 'Las Bajadas'),
(686, 7, 'AR', 'Las Caleras'),
(687, 7, 'AR', 'Las Calles'),
(688, 7, 'AR', 'Las Cañadas'),
(689, 7, 'AR', 'Las Gramillas'),
(690, 7, 'AR', 'Las Higueras'),
(691, 7, 'AR', 'Las Isletillas'),
(692, 7, 'AR', 'Las Junturas'),
(693, 7, 'AR', 'Las Palmas'),
(694, 7, 'AR', 'Las Peñas'),
(695, 7, 'AR', 'Las Peñas Sud'),
(696, 7, 'AR', 'Las Perdices'),
(697, 7, 'AR', 'Las Playas'),
(698, 7, 'AR', 'Las Rabonas'),
(699, 7, 'AR', 'Las Saladas'),
(700, 7, 'AR', 'Las Tapias'),
(701, 7, 'AR', 'Las Varas'),
(702, 7, 'AR', 'Las Varillas'),
(703, 7, 'AR', 'Las Vertientes'),
(704, 7, 'AR', 'Leguizamón'),
(705, 7, 'AR', 'Leones'),
(706, 7, 'AR', 'Los Cedros'),
(707, 7, 'AR', 'Los Cerrillos'),
(708, 7, 'AR', 'Los Chañaritos (C.E)'),
(709, 7, 'AR', 'Los Chanaritos (R.S)'),
(710, 7, 'AR', 'Los Cisnes'),
(711, 7, 'AR', 'Los Cocos'),
(712, 7, 'AR', 'Los Cóndores'),
(713, 7, 'AR', 'Los Hornillos'),
(714, 7, 'AR', 'Los Hoyos'),
(715, 7, 'AR', 'Los Mistoles'),
(716, 7, 'AR', 'Los Molinos'),
(717, 7, 'AR', 'Los Pozos'),
(718, 7, 'AR', 'Los Reartes'),
(719, 7, 'AR', 'Los Surgentes'),
(720, 7, 'AR', 'Los Talares'),
(721, 7, 'AR', 'Los Zorros'),
(722, 7, 'AR', 'Lozada'),
(723, 7, 'AR', 'Luca'),
(724, 7, 'AR', 'Luque'),
(725, 7, 'AR', 'Luyaba'),
(726, 7, 'AR', 'Malagueño'),
(727, 7, 'AR', 'Malena'),
(728, 7, 'AR', 'Malvinas Argentinas'),
(729, 7, 'AR', 'Manfredi'),
(730, 7, 'AR', 'Maquinista Gallini'),
(731, 7, 'AR', 'Marcos Juárez'),
(732, 7, 'AR', 'Marull'),
(733, 7, 'AR', 'Matorrales'),
(734, 7, 'AR', 'Mattaldi'),
(735, 7, 'AR', 'Mayu Sumaj'),
(736, 7, 'AR', 'Media Naranja'),
(737, 7, 'AR', 'Melo'),
(738, 7, 'AR', 'Mendiolaza'),
(739, 7, 'AR', 'Mi Granja'),
(740, 7, 'AR', 'Mina Clavero'),
(741, 7, 'AR', 'Miramar'),
(742, 7, 'AR', 'Morrison'),
(743, 7, 'AR', 'Morteros'),
(744, 7, 'AR', 'Mte. Buey'),
(745, 7, 'AR', 'Mte. Cristo'),
(746, 7, 'AR', 'Mte. De Los Gauchos'),
(747, 7, 'AR', 'Mte. Leña'),
(748, 7, 'AR', 'Mte. Maíz'),
(749, 7, 'AR', 'Mte. Ralo'),
(750, 7, 'AR', 'Nicolás Bruzone'),
(751, 7, 'AR', 'Noetinger'),
(752, 7, 'AR', 'Nono'),
(753, 7, 'AR', 'Nueva 7'),
(754, 7, 'AR', 'Obispo Trejo'),
(755, 7, 'AR', 'Olaeta'),
(756, 7, 'AR', 'Oliva'),
(757, 7, 'AR', 'Olivares San Nicolás'),
(758, 7, 'AR', 'Onagolty'),
(759, 7, 'AR', 'Oncativo'),
(760, 7, 'AR', 'Ordoñez'),
(761, 7, 'AR', 'Pacheco De Melo'),
(762, 7, 'AR', 'Pampayasta N.'),
(763, 7, 'AR', 'Pampayasta S.'),
(764, 7, 'AR', 'Panaholma'),
(765, 7, 'AR', 'Pascanas'),
(766, 7, 'AR', 'Pasco'),
(767, 7, 'AR', 'Paso del Durazno'),
(768, 7, 'AR', 'Paso Viejo'),
(769, 7, 'AR', 'Pilar'),
(770, 7, 'AR', 'Pincén'),
(771, 7, 'AR', 'Piquillín'),
(772, 7, 'AR', 'Plaza de Mercedes'),
(773, 7, 'AR', 'Plaza Luxardo'),
(774, 7, 'AR', 'Porteña'),
(775, 7, 'AR', 'Potrero de Garay'),
(776, 7, 'AR', 'Pozo del Molle'),
(777, 7, 'AR', 'Pozo Nuevo'),
(778, 7, 'AR', 'Pueblo Italiano'),
(779, 7, 'AR', 'Puesto de Castro'),
(780, 7, 'AR', 'Punta del Agua'),
(781, 7, 'AR', 'Quebracho Herrado'),
(782, 7, 'AR', 'Quilino'),
(783, 7, 'AR', 'Rafael García'),
(784, 7, 'AR', 'Ranqueles'),
(785, 7, 'AR', 'Rayo Cortado'),
(786, 7, 'AR', 'Reducción'),
(787, 7, 'AR', 'Rincón'),
(788, 7, 'AR', 'Río Bamba'),
(789, 7, 'AR', 'Río Ceballos'),
(790, 7, 'AR', 'Río Cuarto'),
(791, 7, 'AR', 'Río de Los Sauces'),
(792, 7, 'AR', 'Río Primero'),
(793, 7, 'AR', 'Río Segundo'),
(794, 7, 'AR', 'Río Tercero'),
(795, 7, 'AR', 'Rosales'),
(796, 7, 'AR', 'Rosario del Saladillo'),
(797, 7, 'AR', 'Sacanta'),
(798, 7, 'AR', 'Sagrada Familia'),
(799, 7, 'AR', 'Saira'),
(800, 7, 'AR', 'Saladillo'),
(801, 7, 'AR', 'Saldán'),
(802, 7, 'AR', 'Salsacate'),
(803, 7, 'AR', 'Salsipuedes'),
(804, 7, 'AR', 'Sampacho'),
(805, 7, 'AR', 'San Agustín'),
(806, 7, 'AR', 'San Antonio de Arredondo'),
(807, 7, 'AR', 'San Antonio de Litín'),
(808, 7, 'AR', 'San Basilio'),
(809, 7, 'AR', 'San Carlos Minas'),
(810, 7, 'AR', 'San Clemente'),
(811, 7, 'AR', 'San Esteban'),
(812, 7, 'AR', 'San Francisco'),
(813, 7, 'AR', 'San Ignacio'),
(814, 7, 'AR', 'San Javier'),
(815, 7, 'AR', 'San Jerónimo'),
(816, 7, 'AR', 'San Joaquín'),
(817, 7, 'AR', 'San José de La Dormida'),
(818, 7, 'AR', 'San José de Las Salinas'),
(819, 7, 'AR', 'San Lorenzo'),
(820, 7, 'AR', 'San Marcos Sierras'),
(821, 7, 'AR', 'San Marcos Sud'),
(822, 7, 'AR', 'San Pedro'),
(823, 7, 'AR', 'San Pedro N.'),
(824, 7, 'AR', 'San Roque'),
(825, 7, 'AR', 'San Vicente'),
(826, 7, 'AR', 'Santa Catalina'),
(827, 7, 'AR', 'Santa Elena'),
(828, 7, 'AR', 'Santa Eufemia'),
(829, 7, 'AR', 'Santa Maria'),
(830, 7, 'AR', 'Sarmiento'),
(831, 7, 'AR', 'Saturnino M.Laspiur'),
(832, 7, 'AR', 'Sauce Arriba'),
(833, 7, 'AR', 'Sebastián Elcano'),
(834, 7, 'AR', 'Seeber'),
(835, 7, 'AR', 'Segunda Usina'),
(836, 7, 'AR', 'Serrano'),
(837, 7, 'AR', 'Serrezuela'),
(838, 7, 'AR', 'Sgo. Temple'),
(839, 7, 'AR', 'Silvio Pellico'),
(840, 7, 'AR', 'Simbolar'),
(841, 7, 'AR', 'Sinsacate'),
(842, 7, 'AR', 'Sta. Rosa de Calamuchita'),
(843, 7, 'AR', 'Sta. Rosa de Río Primero'),
(844, 7, 'AR', 'Suco'),
(845, 7, 'AR', 'Tala Cañada'),
(846, 7, 'AR', 'Tala Huasi'),
(847, 7, 'AR', 'Talaini'),
(848, 7, 'AR', 'Tancacha'),
(849, 7, 'AR', 'Tanti'),
(850, 7, 'AR', 'Ticino'),
(851, 7, 'AR', 'Tinoco'),
(852, 7, 'AR', 'Tío Pujio'),
(853, 7, 'AR', 'Toledo'),
(854, 7, 'AR', 'Toro Pujio'),
(855, 7, 'AR', 'Tosno'),
(856, 7, 'AR', 'Tosquita'),
(857, 7, 'AR', 'Tránsito'),
(858, 7, 'AR', 'Tuclame'),
(859, 7, 'AR', 'Tutti'),
(860, 7, 'AR', 'Ucacha'),
(861, 7, 'AR', 'Unquillo'),
(862, 7, 'AR', 'Valle de Anisacate'),
(863, 7, 'AR', 'Valle Hermoso'),
(864, 7, 'AR', 'Vélez Sarfield'),
(865, 7, 'AR', 'Viamonte'),
(866, 7, 'AR', 'Vicuña Mackenna'),
(867, 7, 'AR', 'Villa Allende'),
(868, 7, 'AR', 'Villa Amancay'),
(869, 7, 'AR', 'Villa Ascasubi'),
(870, 7, 'AR', 'Villa Candelaria N.'),
(871, 7, 'AR', 'Villa Carlos Paz'),
(872, 7, 'AR', 'Villa Cerro Azul'),
(873, 7, 'AR', 'Villa Ciudad de América'),
(874, 7, 'AR', 'Villa Ciudad Pque Los Reartes'),
(875, 7, 'AR', 'Villa Concepción del Tío'),
(876, 7, 'AR', 'Villa Cura Brochero'),
(877, 7, 'AR', 'Villa de Las Rosas'),
(878, 7, 'AR', 'Villa de María'),
(879, 7, 'AR', 'Villa de Pocho'),
(880, 7, 'AR', 'Villa de Soto'),
(881, 7, 'AR', 'Villa del Dique'),
(882, 7, 'AR', 'Villa del Prado'),
(883, 7, 'AR', 'Villa del Rosario'),
(884, 7, 'AR', 'Villa del Totoral'),
(885, 7, 'AR', 'Villa Dolores'),
(886, 7, 'AR', 'Villa El Chancay'),
(887, 7, 'AR', 'Villa Elisa'),
(888, 7, 'AR', 'Villa Flor Serrana'),
(889, 7, 'AR', 'Villa Fontana'),
(890, 7, 'AR', 'Villa Giardino'),
(891, 7, 'AR', 'Villa Gral. Belgrano'),
(892, 7, 'AR', 'Villa Gutierrez'),
(893, 7, 'AR', 'Villa Huidobro'),
(894, 7, 'AR', 'Villa La Bolsa'),
(895, 7, 'AR', 'Villa Los Aromos'),
(896, 7, 'AR', 'Villa Los Patos'),
(897, 7, 'AR', 'Villa María'),
(898, 7, 'AR', 'Villa Nueva'),
(899, 7, 'AR', 'Villa Pque. Santa Ana'),
(900, 7, 'AR', 'Villa Pque. Siquiman'),
(901, 7, 'AR', 'Villa Quillinzo'),
(902, 7, 'AR', 'Villa Rossi'),
(903, 7, 'AR', 'Villa Rumipal'),
(904, 7, 'AR', 'Villa San Esteban'),
(905, 7, 'AR', 'Villa San Isidro'),
(906, 7, 'AR', 'Villa 21'),
(907, 7, 'AR', 'Villa Sarmiento (G.R)'),
(908, 7, 'AR', 'Villa Sarmiento (S.A)'),
(909, 7, 'AR', 'Villa Tulumba'),
(910, 7, 'AR', 'Villa Valeria'),
(911, 7, 'AR', 'Villa Yacanto'),
(912, 7, 'AR', 'Washington'),
(913, 7, 'AR', 'Wenceslao Escalante'),
(914, 7, 'AR', 'Ycho Cruz Sierras'),
(915, 8, 'AR', 'Alvear'),
(916, 8, 'AR', 'Bella Vista'),
(917, 8, 'AR', 'Berón de Astrada'),
(918, 8, 'AR', 'Bonpland'),
(919, 8, 'AR', 'Caá Cati'),
(920, 8, 'AR', 'Capital'),
(921, 8, 'AR', 'Chavarría'),
(922, 8, 'AR', 'Col. C. Pellegrini'),
(923, 8, 'AR', 'Col. Libertad'),
(924, 8, 'AR', 'Col. Liebig'),
(925, 8, 'AR', 'Col. Sta Rosa'),
(926, 8, 'AR', 'Concepción'),
(927, 8, 'AR', 'Cruz de Los Milagros'),
(928, 8, 'AR', 'Curuzú-Cuatiá'),
(929, 8, 'AR', 'Empedrado'),
(930, 8, 'AR', 'Esquina'),
(931, 8, 'AR', 'Estación Torrent'),
(932, 8, 'AR', 'Felipe Yofré'),
(933, 8, 'AR', 'Garruchos'),
(934, 8, 'AR', 'Gdor. Agrónomo'),
(935, 8, 'AR', 'Gdor. Martínez'),
(936, 8, 'AR', 'Goya'),
(937, 8, 'AR', 'Guaviravi'),
(938, 8, 'AR', 'Herlitzka'),
(939, 8, 'AR', 'Ita-Ibate'),
(940, 8, 'AR', 'Itatí'),
(941, 8, 'AR', 'Ituzaingó'),
(942, 8, 'AR', 'José Rafael Gómez'),
(943, 8, 'AR', 'Juan Pujol'),
(944, 8, 'AR', 'La Cruz'),
(945, 8, 'AR', 'Lavalle'),
(946, 8, 'AR', 'Lomas de Vallejos'),
(947, 8, 'AR', 'Loreto'),
(948, 8, 'AR', 'Mariano I. Loza'),
(949, 8, 'AR', 'Mburucuyá'),
(950, 8, 'AR', 'Mercedes'),
(951, 8, 'AR', 'Mocoretá'),
(952, 8, 'AR', 'Mte. Caseros'),
(953, 8, 'AR', 'Nueve de Julio'),
(954, 8, 'AR', 'Palmar Grande'),
(955, 8, 'AR', 'Parada Pucheta'),
(956, 8, 'AR', 'Paso de La Patria'),
(957, 8, 'AR', 'Paso de Los Libres'),
(958, 8, 'AR', 'Pedro R. Fernandez'),
(959, 8, 'AR', 'Perugorría'),
(960, 8, 'AR', 'Pueblo Libertador'),
(961, 8, 'AR', 'Ramada Paso'),
(962, 8, 'AR', 'Riachuelo'),
(963, 8, 'AR', 'Saladas'),
(964, 8, 'AR', 'San Antonio'),
(965, 8, 'AR', 'San Carlos'),
(966, 8, 'AR', 'San Cosme'),
(967, 8, 'AR', 'San Lorenzo'),
(968, 8, 'AR', '20 del Palmar'),
(969, 8, 'AR', 'San Miguel'),
(970, 8, 'AR', 'San Roque'),
(971, 8, 'AR', 'Santa Ana'),
(972, 8, 'AR', 'Santa Lucía'),
(973, 8, 'AR', 'Santo Tomé'),
(974, 8, 'AR', 'Sauce'),
(975, 8, 'AR', 'Tabay'),
(976, 8, 'AR', 'Tapebicuá'),
(977, 8, 'AR', 'Tatacua'),
(978, 8, 'AR', 'Virasoro'),
(979, 8, 'AR', 'Yapeyú'),
(980, 8, 'AR', 'Yataití Calle'),
(981, 9, 'AR', 'Alarcón'),
(982, 9, 'AR', 'Alcaraz'),
(983, 9, 'AR', 'Alcaraz N.'),
(984, 9, 'AR', 'Alcaraz S.'),
(985, 9, 'AR', 'Aldea Asunción'),
(986, 9, 'AR', 'Aldea Brasilera'),
(987, 9, 'AR', 'Aldea Elgenfeld'),
(988, 9, 'AR', 'Aldea Grapschental'),
(989, 9, 'AR', 'Aldea Ma. Luisa'),
(990, 9, 'AR', 'Aldea Protestante'),
(991, 9, 'AR', 'Aldea Salto'),
(992, 9, 'AR', 'Aldea San Antonio (G)'),
(993, 9, 'AR', 'Aldea San Antonio (P)'),
(994, 9, 'AR', 'Aldea 19'),
(995, 9, 'AR', 'Aldea San Miguel'),
(996, 9, 'AR', 'Aldea San Rafael'),
(997, 9, 'AR', 'Aldea Spatzenkutter'),
(998, 9, 'AR', 'Aldea Sta. María'),
(999, 9, 'AR', 'Aldea Sta. Rosa'),
(1000, 9, 'AR', 'Aldea Valle María'),
(1001, 9, 'AR', 'Altamirano Sur'),
(1002, 9, 'AR', 'Antelo'),
(1003, 9, 'AR', 'Antonio Tomás'),
(1004, 9, 'AR', 'Aranguren'),
(1005, 9, 'AR', 'Arroyo Barú'),
(1006, 9, 'AR', 'Arroyo Burgos'),
(1007, 9, 'AR', 'Arroyo Clé'),
(1008, 9, 'AR', 'Arroyo Corralito'),
(1009, 9, 'AR', 'Arroyo del Medio'),
(1010, 9, 'AR', 'Arroyo Maturrango'),
(1011, 9, 'AR', 'Arroyo Palo Seco'),
(1012, 9, 'AR', 'Banderas'),
(1013, 9, 'AR', 'Basavilbaso'),
(1014, 9, 'AR', 'Betbeder'),
(1015, 9, 'AR', 'Bovril'),
(1016, 9, 'AR', 'Caseros'),
(1017, 9, 'AR', 'Ceibas'),
(1018, 9, 'AR', 'Cerrito'),
(1019, 9, 'AR', 'Chajarí'),
(1020, 9, 'AR', 'Chilcas'),
(1021, 9, 'AR', 'Clodomiro Ledesma'),
(1022, 9, 'AR', 'Col. Alemana'),
(1023, 9, 'AR', 'Col. Avellaneda'),
(1024, 9, 'AR', 'Col. Avigdor'),
(1025, 9, 'AR', 'Col. Ayuí'),
(1026, 9, 'AR', 'Col. Baylina'),
(1027, 9, 'AR', 'Col. Carrasco'),
(1028, 9, 'AR', 'Col. Celina'),
(1029, 9, 'AR', 'Col. Cerrito'),
(1030, 9, 'AR', 'Col. Crespo'),
(1031, 9, 'AR', 'Col. Elia'),
(1032, 9, 'AR', 'Col. Ensayo'),
(1033, 9, 'AR', 'Col. Gral. Roca'),
(1034, 9, 'AR', 'Col. La Argentina'),
(1035, 9, 'AR', 'Col. Merou'),
(1036, 9, 'AR', 'Col. Oficial Nª3'),
(1037, 9, 'AR', 'Col. Oficial Nº13'),
(1038, 9, 'AR', 'Col. Oficial Nº14'),
(1039, 9, 'AR', 'Col. Oficial Nº5'),
(1040, 9, 'AR', 'Col. Reffino'),
(1041, 9, 'AR', 'Col. Tunas'),
(1042, 9, 'AR', 'Col. Viraró'),
(1043, 9, 'AR', 'Colón'),
(1044, 9, 'AR', 'Concepción del Uruguay'),
(1045, 9, 'AR', 'Concordia'),
(1046, 9, 'AR', 'Conscripto Bernardi'),
(1047, 9, 'AR', 'Costa Grande'),
(1048, 9, 'AR', 'Costa San Antonio'),
(1049, 9, 'AR', 'Costa Uruguay N.'),
(1050, 9, 'AR', 'Costa Uruguay S.'),
(1051, 9, 'AR', 'Crespo'),
(1052, 9, 'AR', 'Crucecitas 3ª'),
(1053, 9, 'AR', 'Crucecitas 7ª'),
(1054, 9, 'AR', 'Crucecitas 8ª'),
(1055, 9, 'AR', 'Cuchilla Redonda'),
(1056, 9, 'AR', 'Curtiembre'),
(1057, 9, 'AR', 'Diamante'),
(1058, 9, 'AR', 'Distrito 6º'),
(1059, 9, 'AR', 'Distrito Chañar'),
(1060, 9, 'AR', 'Distrito Chiqueros'),
(1061, 9, 'AR', 'Distrito Cuarto'),
(1062, 9, 'AR', 'Distrito Diego López'),
(1063, 9, 'AR', 'Distrito Pajonal'),
(1064, 9, 'AR', 'Distrito Sauce'),
(1065, 9, 'AR', 'Distrito Tala'),
(1066, 9, 'AR', 'Distrito Talitas'),
(1067, 9, 'AR', 'Don Cristóbal 1ª Sección'),
(1068, 9, 'AR', 'Don Cristóbal 2ª Sección'),
(1069, 9, 'AR', 'Durazno'),
(1070, 9, 'AR', 'El Cimarrón'),
(1071, 9, 'AR', 'El Gramillal'),
(1072, 9, 'AR', 'El Palenque'),
(1073, 9, 'AR', 'El Pingo'),
(1074, 9, 'AR', 'El Quebracho'),
(1075, 9, 'AR', 'El Redomón'),
(1076, 9, 'AR', 'El Solar'),
(1077, 9, 'AR', 'Enrique Carbo'),
(1078, 9, 'AR', '9'),
(1079, 9, 'AR', 'Espinillo N.'),
(1080, 9, 'AR', 'Estación Campos'),
(1081, 9, 'AR', 'Estación Escriña'),
(1082, 9, 'AR', 'Estación Lazo'),
(1083, 9, 'AR', 'Estación Raíces'),
(1084, 9, 'AR', 'Estación Yerúa'),
(1085, 9, 'AR', 'Estancia Grande'),
(1086, 9, 'AR', 'Estancia Líbaros'),
(1087, 9, 'AR', 'Estancia Racedo'),
(1088, 9, 'AR', 'Estancia Solá'),
(1089, 9, 'AR', 'Estancia Yuquerí'),
(1090, 9, 'AR', 'Estaquitas'),
(1091, 9, 'AR', 'Faustino M. Parera'),
(1092, 9, 'AR', 'Febre'),
(1093, 9, 'AR', 'Federación'),
(1094, 9, 'AR', 'Federal'),
(1095, 9, 'AR', 'Gdor. Echagüe'),
(1096, 9, 'AR', 'Gdor. Mansilla'),
(1097, 9, 'AR', 'Gilbert'),
(1098, 9, 'AR', 'González Calderón'),
(1099, 9, 'AR', 'Gral. Almada'),
(1100, 9, 'AR', 'Gral. Alvear'),
(1101, 9, 'AR', 'Gral. Campos'),
(1102, 9, 'AR', 'Gral. Galarza'),
(1103, 9, 'AR', 'Gral. Ramírez'),
(1104, 9, 'AR', 'Gualeguay'),
(1105, 9, 'AR', 'Gualeguaychú'),
(1106, 9, 'AR', 'Gualeguaycito'),
(1107, 9, 'AR', 'Guardamonte'),
(1108, 9, 'AR', 'Hambis'),
(1109, 9, 'AR', 'Hasenkamp'),
(1110, 9, 'AR', 'Hernandarias'),
(1111, 9, 'AR', 'Hernández'),
(1112, 9, 'AR', 'Herrera'),
(1113, 9, 'AR', 'Hinojal'),
(1114, 9, 'AR', 'Hocker'),
(1115, 9, 'AR', 'Ing. Sajaroff'),
(1116, 9, 'AR', 'Irazusta'),
(1117, 9, 'AR', 'Isletas'),
(1118, 9, 'AR', 'J.J De Urquiza'),
(1119, 9, 'AR', 'Jubileo'),
(1120, 9, 'AR', 'La Clarita'),
(1121, 9, 'AR', 'La Criolla'),
(1122, 9, 'AR', 'La Esmeralda'),
(1123, 9, 'AR', 'La Florida'),
(1124, 9, 'AR', 'La Fraternidad'),
(1125, 9, 'AR', 'La Hierra'),
(1126, 9, 'AR', 'La Ollita'),
(1127, 9, 'AR', 'La Paz'),
(1128, 9, 'AR', 'La Picada'),
(1129, 9, 'AR', 'La Providencia'),
(1130, 9, 'AR', 'La Verbena'),
(1131, 9, 'AR', 'Laguna Benítez'),
(1132, 9, 'AR', 'Larroque'),
(1133, 9, 'AR', 'Las Cuevas'),
(1134, 9, 'AR', 'Las Garzas'),
(1135, 9, 'AR', 'Las Guachas'),
(1136, 9, 'AR', 'Las Mercedes'),
(1137, 9, 'AR', 'Las Moscas'),
(1138, 9, 'AR', 'Las Mulitas'),
(1139, 9, 'AR', 'Las Toscas'),
(1140, 9, 'AR', 'Laurencena'),
(1141, 9, 'AR', 'Libertador San Martín'),
(1142, 9, 'AR', 'Loma Limpia'),
(1143, 9, 'AR', 'Los Ceibos'),
(1144, 9, 'AR', 'Los Charruas'),
(1145, 9, 'AR', 'Los Conquistadores'),
(1146, 9, 'AR', 'Lucas González'),
(1147, 9, 'AR', 'Lucas N.'),
(1148, 9, 'AR', 'Lucas S. 1ª'),
(1149, 9, 'AR', 'Lucas S. 2ª'),
(1150, 9, 'AR', 'Maciá'),
(1151, 9, 'AR', 'María Grande'),
(1152, 9, 'AR', 'María Grande 2ª'),
(1153, 9, 'AR', 'Médanos'),
(1154, 9, 'AR', 'Mojones N.'),
(1155, 9, 'AR', 'Mojones S.'),
(1156, 9, 'AR', 'Molino Doll'),
(1157, 9, 'AR', 'Monte Redondo'),
(1158, 9, 'AR', 'Montoya'),
(1159, 9, 'AR', 'Mulas Grandes'),
(1160, 9, 'AR', 'Ñancay'),
(1161, 9, 'AR', 'Nogoyá'),
(1162, 9, 'AR', 'Nueva Escocia'),
(1163, 9, 'AR', 'Nueva Vizcaya'),
(1164, 9, 'AR', 'Ombú'),
(1165, 9, 'AR', 'Oro Verde'),
(1166, 9, 'AR', 'Paraná'),
(1167, 9, 'AR', 'Pasaje Guayaquil'),
(1168, 9, 'AR', 'Pasaje Las Tunas'),
(1169, 9, 'AR', 'Paso de La Arena'),
(1170, 9, 'AR', 'Paso de La Laguna'),
(1171, 9, 'AR', 'Paso de Las Piedras'),
(1172, 9, 'AR', 'Paso Duarte'),
(1173, 9, 'AR', 'Pastor Britos'),
(1174, 9, 'AR', 'Pedernal'),
(1175, 9, 'AR', 'Perdices'),
(1176, 9, 'AR', 'Picada Berón'),
(1177, 9, 'AR', 'Piedras Blancas'),
(1178, 9, 'AR', 'Primer Distrito Cuchilla'),
(1179, 9, 'AR', 'Primero de Mayo'),
(1180, 9, 'AR', 'Pronunciamiento'),
(1181, 9, 'AR', 'Pto. Algarrobo'),
(1182, 9, 'AR', 'Pto. Ibicuy'),
(1183, 9, 'AR', 'Pueblo Brugo'),
(1184, 9, 'AR', 'Pueblo Cazes'),
(1185, 9, 'AR', 'Pueblo Gral. Belgrano'),
(1186, 9, 'AR', 'Pueblo Liebig'),
(1187, 9, 'AR', 'Puerto Yeruá'),
(1188, 9, 'AR', 'Punta del Monte'),
(1189, 9, 'AR', 'Quebracho'),
(1190, 9, 'AR', 'Quinto Distrito'),
(1191, 9, 'AR', 'Raices Oeste'),
(1192, 9, 'AR', 'Rincón de Nogoyá'),
(1193, 9, 'AR', 'Rincón del Cinto'),
(1194, 9, 'AR', 'Rincón del Doll'),
(1195, 9, 'AR', 'Rincón del Gato'),
(1196, 9, 'AR', 'Rocamora'),
(1197, 9, 'AR', 'Rosario del Tala'),
(1198, 9, 'AR', 'San Benito'),
(1199, 9, 'AR', 'San Cipriano'),
(1200, 9, 'AR', 'San Ernesto'),
(1201, 9, 'AR', 'San Gustavo'),
(1202, 9, 'AR', 'San Jaime'),
(1203, 9, 'AR', 'San José'),
(1204, 9, 'AR', 'San José de Feliciano'),
(1205, 9, 'AR', 'San Justo'),
(1206, 9, 'AR', 'San Marcial'),
(1207, 9, 'AR', 'San Pedro'),
(1208, 9, 'AR', 'San Ramírez'),
(1209, 9, 'AR', 'San Ramón'),
(1210, 9, 'AR', 'San Roque'),
(1211, 9, 'AR', 'San Salvador'),
(1212, 9, 'AR', 'San Víctor'),
(1213, 9, 'AR', 'Santa Ana'),
(1214, 9, 'AR', 'Santa Anita'),
(1215, 9, 'AR', 'Santa Elena'),
(1216, 9, 'AR', 'Santa Lucía'),
(1217, 9, 'AR', 'Santa Luisa'),
(1218, 9, 'AR', 'Sauce de Luna'),
(1219, 9, 'AR', 'Sauce Montrull'),
(1220, 9, 'AR', 'Sauce Pinto'),
(1221, 9, 'AR', 'Sauce Sur'),
(1222, 9, 'AR', 'Seguí'),
(1223, 9, 'AR', 'Sir Leonard'),
(1224, 9, 'AR', 'Sosa'),
(1225, 9, 'AR', 'Tabossi'),
(1226, 9, 'AR', 'Tezanos Pinto'),
(1227, 9, 'AR', 'Ubajay'),
(1228, 9, 'AR', 'Urdinarrain'),
(1229, 9, 'AR', 'Veinte de Septiembre'),
(1230, 9, 'AR', 'Viale'),
(1231, 9, 'AR', 'Victoria'),
(1232, 9, 'AR', 'Villa Clara'),
(1233, 9, 'AR', 'Villa del Rosario'),
(1234, 9, 'AR', 'Villa Domínguez'),
(1235, 9, 'AR', 'Villa Elisa'),
(1236, 9, 'AR', 'Villa Fontana'),
(1237, 9, 'AR', 'Villa Gdor. Etchevehere'),
(1238, 9, 'AR', 'Villa Mantero'),
(1239, 9, 'AR', 'Villa Paranacito'),
(1240, 9, 'AR', 'Villa Urquiza'),
(1241, 9, 'AR', 'Villaguay'),
(1242, 9, 'AR', 'Walter Moss'),
(1243, 9, 'AR', 'Yacaré'),
(1244, 9, 'AR', 'Yeso Oeste'),
(1245, 10, 'AR', 'Buena Vista'),
(1246, 10, 'AR', 'Clorinda'),
(1247, 10, 'AR', 'Col. Pastoril'),
(1248, 10, 'AR', 'Cte. Fontana'),
(1249, 10, 'AR', 'El Colorado'),
(1250, 10, 'AR', 'El Espinillo'),
(1251, 10, 'AR', 'Estanislao Del Campo'),
(1252, 10, 'AR', '10'),
(1253, 10, 'AR', 'Fortín Lugones'),
(1254, 10, 'AR', 'Gral. Lucio V. Mansilla'),
(1255, 10, 'AR', 'Gral. Manuel Belgrano'),
(1256, 10, 'AR', 'Gral. Mosconi'),
(1257, 10, 'AR', 'Gran Guardia'),
(1258, 10, 'AR', 'Herradura'),
(1259, 10, 'AR', 'Ibarreta'),
(1260, 10, 'AR', 'Ing. Juárez'),
(1261, 10, 'AR', 'Laguna Blanca'),
(1262, 10, 'AR', 'Laguna Naick Neck'),
(1263, 10, 'AR', 'Laguna Yema'),
(1264, 10, 'AR', 'Las Lomitas'),
(1265, 10, 'AR', 'Los Chiriguanos'),
(1266, 10, 'AR', 'Mayor V. Villafañe'),
(1267, 10, 'AR', 'Misión San Fco.'),
(1268, 10, 'AR', 'Palo Santo'),
(1269, 10, 'AR', 'Pirané'),
(1270, 10, 'AR', 'Pozo del Maza'),
(1271, 10, 'AR', 'Riacho He-He'),
(1272, 10, 'AR', 'San Hilario'),
(1273, 10, 'AR', 'San Martín II'),
(1274, 10, 'AR', 'Siete Palmas'),
(1275, 10, 'AR', 'Subteniente Perín'),
(1276, 10, 'AR', 'Tres Lagunas'),
(1277, 10, 'AR', 'Villa Dos Trece'),
(1278, 10, 'AR', 'Villa Escolar'),
(1279, 10, 'AR', 'Villa Gral. Güemes'),
(1280, 11, 'AR', 'Abdon Castro Tolay'),
(1281, 11, 'AR', 'Abra Pampa'),
(1282, 11, 'AR', 'Abralaite'),
(1283, 11, 'AR', 'Aguas Calientes'),
(1284, 11, 'AR', 'Arrayanal'),
(1285, 11, 'AR', 'Barrios'),
(1286, 11, 'AR', 'Caimancito'),
(1287, 11, 'AR', 'Calilegua'),
(1288, 11, 'AR', 'Cangrejillos'),
(1289, 11, 'AR', 'Caspala'),
(1290, 11, 'AR', 'Catuá'),
(1291, 11, 'AR', 'Cieneguillas'),
(1292, 11, 'AR', 'Coranzulli'),
(1293, 11, 'AR', 'Cusi-Cusi'),
(1294, 11, 'AR', 'El Aguilar'),
(1295, 11, 'AR', 'El Carmen'),
(1296, 11, 'AR', 'El Cóndor'),
(1297, 11, 'AR', 'El Fuerte'),
(1298, 11, 'AR', 'El Piquete'),
(1299, 11, 'AR', 'El Talar'),
(1300, 11, 'AR', 'Fraile Pintado'),
(1301, 11, 'AR', 'Hipólito Yrigoyen'),
(1302, 11, 'AR', 'Huacalera'),
(1303, 11, 'AR', 'Humahuaca'),
(1304, 11, 'AR', 'La Esperanza'),
(1305, 11, 'AR', 'La Mendieta'),
(1306, 11, 'AR', 'La Quiaca'),
(1307, 11, 'AR', 'Ledesma'),
(1308, 11, 'AR', 'Libertador Gral. San Martin'),
(1309, 11, 'AR', 'Maimara'),
(1310, 11, 'AR', 'Mina Pirquitas'),
(1311, 11, 'AR', 'Monterrico'),
(1312, 11, 'AR', 'Palma Sola'),
(1313, 11, 'AR', 'Palpalá'),
(1314, 11, 'AR', 'Pampa Blanca'),
(1315, 11, 'AR', 'Pampichuela'),
(1316, 11, 'AR', 'Perico'),
(1317, 11, 'AR', 'Puesto del Marqués'),
(1318, 11, 'AR', 'Puesto Viejo'),
(1319, 11, 'AR', 'Pumahuasi'),
(1320, 11, 'AR', 'Purmamarca'),
(1321, 11, 'AR', 'Rinconada'),
(1322, 11, 'AR', 'Rodeitos'),
(1323, 11, 'AR', 'Rosario de Río Grande'),
(1324, 11, 'AR', 'San Antonio'),
(1325, 11, 'AR', 'San Francisco'),
(1326, 11, 'AR', 'San Pedro'),
(1327, 11, 'AR', 'San Rafael'),
(1328, 11, 'AR', 'San Salvador'),
(1329, 11, 'AR', 'Santa Ana'),
(1330, 11, 'AR', 'Santa Catalina'),
(1331, 11, 'AR', 'Santa Clara'),
(1332, 11, 'AR', 'Susques'),
(1333, 11, 'AR', 'Tilcara'),
(1334, 11, 'AR', 'Tres Cruces'),
(1335, 11, 'AR', 'Tumbaya'),
(1336, 11, 'AR', 'Valle Grande'),
(1337, 11, 'AR', 'Vinalito'),
(1338, 11, 'AR', 'Volcán'),
(1339, 11, 'AR', 'Yala'),
(1340, 11, 'AR', 'Yaví'),
(1341, 11, 'AR', 'Yuto'),
(1342, 12, 'AR', 'Abramo'),
(1343, 12, 'AR', 'Adolfo Van Praet'),
(1344, 12, 'AR', 'Agustoni'),
(1345, 12, 'AR', 'Algarrobo del Aguila'),
(1346, 12, 'AR', 'Alpachiri'),
(1347, 12, 'AR', 'Alta Italia'),
(1348, 12, 'AR', 'Anguil'),
(1349, 12, 'AR', 'Arata'),
(1350, 12, 'AR', 'Ataliva Roca'),
(1351, 12, 'AR', 'Bernardo Larroude'),
(1352, 12, 'AR', 'Bernasconi'),
(1353, 12, 'AR', 'Caleufú'),
(1354, 12, 'AR', 'Carro Quemado'),
(1355, 12, 'AR', 'Catriló'),
(1356, 12, 'AR', 'Ceballos'),
(1357, 12, 'AR', 'Chacharramendi'),
(1358, 12, 'AR', 'Col. Barón'),
(1359, 12, 'AR', 'Col. Santa María'),
(1360, 12, 'AR', 'Conhelo'),
(1361, 12, 'AR', 'Coronel Hilario Lagos'),
(1362, 12, 'AR', 'Cuchillo-Có'),
(1363, 12, 'AR', 'Doblas'),
(1364, 12, 'AR', 'Dorila'),
(1365, 12, 'AR', 'Eduardo Castex'),
(1366, 12, 'AR', 'Embajador Martini'),
(1367, 12, 'AR', 'Falucho'),
(1368, 12, 'AR', 'Gral. Acha'),
(1369, 12, 'AR', 'Gral. Manuel Campos'),
(1370, 12, 'AR', 'Gral. Pico'),
(1371, 12, 'AR', 'Guatraché'),
(1372, 12, 'AR', 'Ing. Luiggi'),
(1373, 12, 'AR', 'Intendente Alvear'),
(1374, 12, 'AR', 'Jacinto Arauz'),
(1375, 12, 'AR', 'La Adela'),
(1376, 12, 'AR', 'La Humada'),
(1377, 12, 'AR', 'La Maruja'),
(1378, 12, 'AR', '12'),
(1379, 12, 'AR', 'La Reforma'),
(1380, 12, 'AR', 'Limay Mahuida'),
(1381, 12, 'AR', 'Lonquimay'),
(1382, 12, 'AR', 'Loventuel'),
(1383, 12, 'AR', 'Luan Toro'),
(1384, 12, 'AR', 'Macachín'),
(1385, 12, 'AR', 'Maisonnave'),
(1386, 12, 'AR', 'Mauricio Mayer'),
(1387, 12, 'AR', 'Metileo'),
(1388, 12, 'AR', 'Miguel Cané'),
(1389, 12, 'AR', 'Miguel Riglos'),
(1390, 12, 'AR', 'Monte Nievas'),
(1391, 12, 'AR', 'Parera'),
(1392, 12, 'AR', 'Perú'),
(1393, 12, 'AR', 'Pichi-Huinca'),
(1394, 12, 'AR', 'Puelches'),
(1395, 12, 'AR', 'Puelén'),
(1396, 12, 'AR', 'Quehue'),
(1397, 12, 'AR', 'Quemú Quemú'),
(1398, 12, 'AR', 'Quetrequén'),
(1399, 12, 'AR', 'Rancul'),
(1400, 12, 'AR', 'Realicó'),
(1401, 12, 'AR', 'Relmo'),
(1402, 12, 'AR', 'Rolón'),
(1403, 12, 'AR', 'Rucanelo'),
(1404, 12, 'AR', 'Sarah'),
(1405, 12, 'AR', 'Speluzzi'),
(1406, 12, 'AR', 'Sta. Isabel'),
(1407, 12, 'AR', 'Sta. Rosa'),
(1408, 12, 'AR', 'Sta. Teresa'),
(1409, 12, 'AR', 'Telén'),
(1410, 12, 'AR', 'Toay'),
(1411, 12, 'AR', 'Tomas M. de Anchorena'),
(1412, 12, 'AR', 'Trenel'),
(1413, 12, 'AR', 'Unanue'),
(1414, 12, 'AR', 'Uriburu'),
(1415, 12, 'AR', 'Veinticinco de Mayo'),
(1416, 12, 'AR', 'Vertiz'),
(1417, 12, 'AR', 'Victorica'),
(1418, 12, 'AR', 'Villa Mirasol'),
(1419, 12, 'AR', 'Winifreda'),
(1420, 13, 'AR', 'Arauco'),
(1421, 13, 'AR', 'Capital'),
(1422, 13, 'AR', 'Castro Barros'),
(1423, 13, 'AR', 'Chamical'),
(1424, 13, 'AR', 'Chilecito'),
(1425, 13, 'AR', 'Coronel F. Varela'),
(1426, 13, 'AR', 'Famatina'),
(1427, 13, 'AR', 'Gral. A.V.Peñaloza'),
(1428, 13, 'AR', 'Gral. Belgrano'),
(1429, 13, 'AR', 'Gral. J.F. Quiroga'),
(1430, 13, 'AR', 'Gral. Lamadrid'),
(1431, 13, 'AR', 'Gral. Ocampo'),
(1432, 13, 'AR', 'Gral. San Martín'),
(1433, 13, 'AR', 'Independencia'),
(1434, 13, 'AR', 'Rosario Penaloza'),
(1435, 13, 'AR', 'San Blas de Los Sauces'),
(1436, 13, 'AR', 'Sanagasta'),
(1437, 13, 'AR', 'Vinchina'),
(1438, 14, 'AR', 'Capital'),
(1439, 14, 'AR', 'Chacras de Coria'),
(1440, 14, 'AR', 'Dorrego'),
(1441, 14, 'AR', 'Gllen'),
(1442, 14, 'AR', 'Godoy Cruz'),
(1443, 14, 'AR', 'Gral. Alvear'),
(1444, 14, 'AR', 'Guaymallén'),
(1445, 14, 'AR', 'Junín'),
(1446, 14, 'AR', 'La Paz'),
(1447, 14, 'AR', 'Las Heras'),
(1448, 14, 'AR', 'Lavalle'),
(1449, 14, 'AR', 'Luján'),
(1450, 14, 'AR', 'Luján De Cuyo'),
(1451, 14, 'AR', 'Maipú'),
(1452, 14, 'AR', 'Malargüe'),
(1453, 14, 'AR', 'Rivadavia'),
(1454, 14, 'AR', 'San Carlos'),
(1455, 14, 'AR', 'San Martín'),
(1456, 14, 'AR', 'San Rafael'),
(1457, 14, 'AR', 'Sta. Rosa'),
(1458, 14, 'AR', 'Tunuyán'),
(1459, 14, 'AR', 'Tupungato'),
(1460, 14, 'AR', 'Villa Nueva'),
(1461, 15, 'AR', 'Alba Posse'),
(1462, 15, 'AR', 'Almafuerte'),
(1463, 15, 'AR', 'Apóstoles'),
(1464, 15, 'AR', 'Aristóbulo Del Valle'),
(1465, 15, 'AR', 'Arroyo Del Medio'),
(1466, 15, 'AR', 'Azara'),
(1467, 15, 'AR', 'Bdo. De Irigoyen'),
(1468, 15, 'AR', 'Bonpland'),
(1469, 15, 'AR', 'Caá Yari'),
(1470, 15, 'AR', 'Campo Grande'),
(1471, 15, 'AR', 'Campo Ramón'),
(1472, 15, 'AR', 'Campo Viera'),
(1473, 15, 'AR', 'Candelaria'),
(1474, 15, 'AR', 'Capioví'),
(1475, 15, 'AR', 'Caraguatay'),
(1476, 15, 'AR', 'Cdte. Guacurarí'),
(1477, 15, 'AR', 'Cerro Azul'),
(1478, 15, 'AR', 'Cerro Corá'),
(1479, 15, 'AR', 'Col. Alberdi'),
(1480, 15, 'AR', 'Col. Aurora'),
(1481, 15, 'AR', 'Col. Delicia'),
(1482, 15, 'AR', 'Col. Polana'),
(1483, 15, 'AR', 'Col. Victoria'),
(1484, 15, 'AR', 'Col. Wanda'),
(1485, 15, 'AR', 'Concepción De La Sierra'),
(1486, 15, 'AR', 'Corpus'),
(1487, 15, 'AR', 'Dos Arroyos'),
(1488, 15, 'AR', 'Dos de Mayo'),
(1489, 15, 'AR', 'El Alcázar'),
(1490, 15, 'AR', 'El Dorado'),
(1491, 15, 'AR', 'El Soberbio'),
(1492, 15, 'AR', 'Esperanza'),
(1493, 15, 'AR', 'F. Ameghino'),
(1494, 15, 'AR', 'Fachinal'),
(1495, 15, 'AR', 'Garuhapé'),
(1496, 15, 'AR', 'Garupá'),
(1497, 15, 'AR', 'Gdor. López'),
(1498, 15, 'AR', 'Gdor. Roca'),
(1499, 15, 'AR', 'Gral. Alvear'),
(1500, 15, 'AR', 'Gral. Urquiza'),
(1501, 15, 'AR', 'Guaraní'),
(1502, 15, 'AR', 'H. Yrigoyen'),
(1503, 15, 'AR', 'Iguazú'),
(1504, 15, 'AR', 'Itacaruaré'),
(1505, 15, 'AR', 'Jardín América'),
(1506, 15, 'AR', 'Leandro N. Alem'),
(1507, 15, 'AR', 'Libertad'),
(1508, 15, 'AR', 'Loreto'),
(1509, 15, 'AR', 'Los Helechos'),
(1510, 15, 'AR', 'Mártires'),
(1511, 15, 'AR', '15'),
(1512, 15, 'AR', 'Mojón Grande'),
(1513, 15, 'AR', 'Montecarlo'),
(1514, 15, 'AR', 'Nueve de Julio'),
(1515, 15, 'AR', 'Oberá'),
(1516, 15, 'AR', 'Olegario V. Andrade'),
(1517, 15, 'AR', 'Panambí'),
(1518, 15, 'AR', 'Posadas'),
(1519, 15, 'AR', 'Profundidad'),
(1520, 15, 'AR', 'Pto. Iguazú'),
(1521, 15, 'AR', 'Pto. Leoni'),
(1522, 15, 'AR', 'Pto. Piray'),
(1523, 15, 'AR', 'Pto. Rico'),
(1524, 15, 'AR', 'Ruiz de Montoya'),
(1525, 15, 'AR', 'San Antonio'),
(1526, 15, 'AR', 'San Ignacio'),
(1527, 15, 'AR', 'San Javier'),
(1528, 15, 'AR', 'San José'),
(1529, 15, 'AR', 'San Martín'),
(1530, 15, 'AR', 'San Pedro'),
(1531, 15, 'AR', 'San Vicente'),
(1532, 15, 'AR', 'Santiago De Liniers'),
(1533, 15, 'AR', 'Santo Pipo'),
(1534, 15, 'AR', 'Sta. Ana'),
(1535, 15, 'AR', 'Sta. María'),
(1536, 15, 'AR', 'Tres Capones'),
(1537, 15, 'AR', 'Veinticinco de Mayo'),
(1538, 15, 'AR', 'Wanda'),
(1539, 16, 'AR', 'Aguada San Roque'),
(1540, 16, 'AR', 'Aluminé'),
(1541, 16, 'AR', 'Andacollo'),
(1542, 16, 'AR', 'Añelo'),
(1543, 16, 'AR', 'Bajada del Agrio'),
(1544, 16, 'AR', 'Barrancas'),
(1545, 16, 'AR', 'Buta Ranquil'),
(1546, 16, 'AR', 'Capital'),
(1547, 16, 'AR', 'Caviahué'),
(1548, 16, 'AR', 'Centenario'),
(1549, 16, 'AR', 'Chorriaca'),
(1550, 16, 'AR', 'Chos Malal'),
(1551, 16, 'AR', 'Cipolletti'),
(1552, 16, 'AR', 'Covunco Abajo'),
(1553, 16, 'AR', 'Coyuco Cochico'),
(1554, 16, 'AR', 'Cutral Có'),
(1555, 16, 'AR', 'El Cholar'),
(1556, 16, 'AR', 'El Huecú'),
(1557, 16, 'AR', 'El Sauce'),
(1558, 16, 'AR', 'Guañacos'),
(1559, 16, 'AR', 'Huinganco'),
(1560, 16, 'AR', 'Las Coloradas'),
(1561, 16, 'AR', 'Las Lajas'),
(1562, 16, 'AR', 'Las Ovejas'),
(1563, 16, 'AR', 'Loncopué'),
(1564, 16, 'AR', 'Los Catutos'),
(1565, 16, 'AR', 'Los Chihuidos'),
(1566, 16, 'AR', 'Los Miches'),
(1567, 16, 'AR', 'Manzano Amargo'),
(1568, 16, 'AR', '16'),
(1569, 16, 'AR', 'Octavio Pico'),
(1570, 16, 'AR', 'Paso Aguerre'),
(1571, 16, 'AR', 'Picún Leufú'),
(1572, 16, 'AR', 'Piedra del Aguila'),
(1573, 16, 'AR', 'Pilo Lil'),
(1574, 16, 'AR', 'Plaza Huincul'),
(1575, 16, 'AR', 'Plottier'),
(1576, 16, 'AR', 'Quili Malal'),
(1577, 16, 'AR', 'Ramón Castro'),
(1578, 16, 'AR', 'Rincón de Los Sauces'),
(1579, 16, 'AR', 'San Martín de Los Andes'),
(1580, 16, 'AR', 'San Patricio del Chañar'),
(1581, 16, 'AR', 'Santo Tomás'),
(1582, 16, 'AR', 'Sauzal Bonito'),
(1583, 16, 'AR', 'Senillosa'),
(1584, 16, 'AR', 'Taquimilán'),
(1585, 16, 'AR', 'Tricao Malal'),
(1586, 16, 'AR', 'Varvarco'),
(1587, 16, 'AR', 'Villa Curí Leuvu'),
(1588, 16, 'AR', 'Villa del Nahueve'),
(1589, 16, 'AR', 'Villa del Puente Picún Leuvú'),
(1590, 16, 'AR', 'Villa El Chocón'),
(1591, 16, 'AR', 'Villa La Angostura'),
(1592, 16, 'AR', 'Villa Pehuenia'),
(1593, 16, 'AR', 'Villa Traful'),
(1594, 16, 'AR', 'Vista Alegre'),
(1595, 16, 'AR', 'Zapala'),
(1596, 17, 'AR', 'Aguada Cecilio'),
(1597, 17, 'AR', 'Aguada de Guerra'),
(1598, 17, 'AR', 'Allén'),
(1599, 17, 'AR', 'Arroyo de La Ventana'),
(1600, 17, 'AR', 'Arroyo Los Berros'),
(1601, 17, 'AR', 'Bariloche'),
(1602, 17, 'AR', 'Calte. Cordero'),
(1603, 17, 'AR', 'Campo Grande'),
(1604, 17, 'AR', 'Catriel'),
(1605, 17, 'AR', 'Cerro Policía'),
(1606, 17, 'AR', 'Cervantes'),
(1607, 17, 'AR', 'Chelforo'),
(1608, 17, 'AR', 'Chimpay'),
(1609, 17, 'AR', 'Chinchinales'),
(1610, 17, 'AR', 'Chipauquil'),
(1611, 17, 'AR', 'Choele Choel'),
(1612, 17, 'AR', 'Cinco Saltos'),
(1613, 17, 'AR', 'Cipolletti'),
(1614, 17, 'AR', 'Clemente Onelli'),
(1615, 17, 'AR', 'Colán Conhue'),
(1616, 17, 'AR', 'Comallo'),
(1617, 17, 'AR', 'Comicó'),
(1618, 17, 'AR', 'Cona Niyeu'),
(1619, 17, 'AR', 'Coronel Belisle'),
(1620, 17, 'AR', 'Cubanea'),
(1621, 17, 'AR', 'Darwin'),
(1622, 17, 'AR', 'Dina Huapi'),
(1623, 17, 'AR', 'El Bolsón'),
(1624, 17, 'AR', 'El Caín'),
(1625, 17, 'AR', 'El Manso'),
(1626, 17, 'AR', 'Gral. Conesa'),
(1627, 17, 'AR', 'Gral. Enrique Godoy'),
(1628, 17, 'AR', 'Gral. Fernandez Oro'),
(1629, 17, 'AR', 'Gral. Roca'),
(1630, 17, 'AR', 'Guardia Mitre'),
(1631, 17, 'AR', 'Ing. Huergo'),
(1632, 17, 'AR', 'Ing. Jacobacci'),
(1633, 17, 'AR', 'Laguna Blanca'),
(1634, 17, 'AR', 'Lamarque'),
(1635, 17, 'AR', 'Las Grutas'),
(1636, 17, 'AR', 'Los Menucos'),
(1637, 17, 'AR', 'Luis Beltrán'),
(1638, 17, 'AR', 'Mainqué'),
(1639, 17, 'AR', 'Mamuel Choique'),
(1640, 17, 'AR', 'Maquinchao'),
(1641, 17, 'AR', 'Mencué'),
(1642, 17, 'AR', 'Mtro. Ramos Mexia'),
(1643, 17, 'AR', 'Nahuel Niyeu'),
(1644, 17, 'AR', 'Naupa Huen'),
(1645, 17, 'AR', 'Ñorquinco'),
(1646, 17, 'AR', 'Ojos de Agua'),
(1647, 17, 'AR', 'Paso de Agua'),
(1648, 17, 'AR', 'Paso Flores'),
(1649, 17, 'AR', 'Peñas Blancas'),
(1650, 17, 'AR', 'Pichi Mahuida'),
(1651, 17, 'AR', 'Pilcaniyeu'),
(1652, 17, 'AR', 'Pomona'),
(1653, 17, 'AR', 'Prahuaniyeu'),
(1654, 17, 'AR', 'Rincón Treneta'),
(1655, 17, 'AR', 'Río Chico'),
(1656, 17, 'AR', 'Río Colorado'),
(1657, 17, 'AR', 'Roca'),
(1658, 17, 'AR', 'San Antonio Oeste'),
(1659, 17, 'AR', 'San Javier'),
(1660, 17, 'AR', 'Sierra Colorada'),
(1661, 17, 'AR', 'Sierra Grande'),
(1662, 17, 'AR', 'Sierra Pailemán'),
(1663, 17, 'AR', 'Valcheta'),
(1664, 17, 'AR', 'Valle Azul'),
(1665, 17, 'AR', 'Viedma'),
(1666, 17, 'AR', 'Villa Llanquín'),
(1667, 17, 'AR', 'Villa Mascardi'),
(1668, 17, 'AR', 'Villa Regina'),
(1669, 17, 'AR', 'Yaminué'),
(1670, 18, 'AR', 'A. Saravia'),
(1671, 18, 'AR', 'Aguaray'),
(1672, 18, 'AR', 'Angastaco'),
(1673, 18, 'AR', 'Animaná'),
(1674, 18, 'AR', 'Cachi'),
(1675, 18, 'AR', 'Cafayate'),
(1676, 18, 'AR', 'Campo Quijano'),
(1677, 18, 'AR', 'Campo Santo'),
(1678, 18, 'AR', 'Capital'),
(1679, 18, 'AR', 'Cerrillos'),
(1680, 18, 'AR', 'Chicoana'),
(1681, 18, 'AR', 'Col. Sta. Rosa'),
(1682, 18, 'AR', 'Coronel Moldes'),
(1683, 18, 'AR', 'El Bordo'),
(1684, 18, 'AR', 'El Carril'),
(1685, 18, 'AR', 'El Galpón'),
(1686, 18, 'AR', 'El Jardín'),
(1687, 18, 'AR', 'El Potrero'),
(1688, 18, 'AR', 'El Quebrachal'),
(1689, 18, 'AR', 'El Tala'),
(1690, 18, 'AR', 'Embarcación'),
(1691, 18, 'AR', 'Gral. Ballivian'),
(1692, 18, 'AR', 'Gral. Güemes'),
(1693, 18, 'AR', 'Gral. Mosconi'),
(1694, 18, 'AR', 'Gral. Pizarro'),
(1695, 18, 'AR', 'Guachipas'),
(1696, 18, 'AR', 'Hipólito Yrigoyen'),
(1697, 18, 'AR', 'Iruyá'),
(1698, 18, 'AR', 'Isla De Cañas'),
(1699, 18, 'AR', 'J. V. Gonzalez'),
(1700, 18, 'AR', 'La Caldera'),
(1701, 18, 'AR', 'La Candelaria'),
(1702, 18, 'AR', 'La Merced'),
(1703, 18, 'AR', 'La Poma'),
(1704, 18, 'AR', 'La Viña'),
(1705, 18, 'AR', 'Las Lajitas'),
(1706, 18, 'AR', 'Los Toldos'),
(1707, 18, 'AR', 'Metán'),
(1708, 18, 'AR', 'Molinos'),
(1709, 18, 'AR', 'Nazareno'),
(1710, 18, 'AR', 'Orán'),
(1711, 18, 'AR', 'Payogasta'),
(1712, 18, 'AR', 'Pichanal'),
(1713, 18, 'AR', 'Prof. S. Mazza'),
(1714, 18, 'AR', 'Río Piedras'),
(1715, 18, 'AR', 'Rivadavia Banda Norte'),
(1716, 18, 'AR', 'Rivadavia Banda Sur'),
(1717, 18, 'AR', 'Rosario de La Frontera'),
(1718, 18, 'AR', 'Rosario de Lerma'),
(1719, 18, 'AR', 'Saclantás'),
(1720, 18, 'AR', '18'),
(1721, 18, 'AR', 'San Antonio'),
(1722, 18, 'AR', 'San Carlos'),
(1723, 18, 'AR', 'San José De Metán'),
(1724, 18, 'AR', 'San Ramón'),
(1725, 18, 'AR', 'Santa Victoria E.'),
(1726, 18, 'AR', 'Santa Victoria O.'),
(1727, 18, 'AR', 'Tartagal'),
(1728, 18, 'AR', 'Tolar Grande'),
(1729, 18, 'AR', 'Urundel'),
(1730, 18, 'AR', 'Vaqueros'),
(1731, 18, 'AR', 'Villa San Lorenzo'),
(1732, 19, 'AR', 'Albardón'),
(1733, 19, 'AR', 'Angaco'),
(1734, 19, 'AR', 'Calingasta'),
(1735, 19, 'AR', 'Capital'),
(1736, 19, 'AR', 'Caucete'),
(1737, 19, 'AR', 'Chimbas'),
(1738, 19, 'AR', 'Iglesia'),
(1739, 19, 'AR', 'Jachal'),
(1740, 19, 'AR', 'Nueve de Julio'),
(1741, 19, 'AR', 'Pocito'),
(1742, 19, 'AR', 'Rawson'),
(1743, 19, 'AR', 'Rivadavia'),
(1744, 19, 'AR', '19'),
(1745, 19, 'AR', 'San Martín'),
(1746, 19, 'AR', 'Santa Lucía'),
(1747, 19, 'AR', 'Sarmiento'),
(1748, 19, 'AR', 'Ullum'),
(1749, 19, 'AR', 'Valle Fértil'),
(1750, 19, 'AR', 'Veinticinco de Mayo'),
(1751, 19, 'AR', 'Zonda'),
(1752, 20, 'AR', 'Alto Pelado'),
(1753, 20, 'AR', 'Alto Pencoso'),
(1754, 20, 'AR', 'Anchorena'),
(1755, 20, 'AR', 'Arizona'),
(1756, 20, 'AR', 'Bagual'),
(1757, 20, 'AR', 'Balde'),
(1758, 20, 'AR', 'Batavia'),
(1759, 20, 'AR', 'Beazley'),
(1760, 20, 'AR', 'Buena Esperanza'),
(1761, 20, 'AR', 'Candelaria'),
(1762, 20, 'AR', 'Capital'),
(1763, 20, 'AR', 'Carolina'),
(1764, 20, 'AR', 'Carpintería'),
(1765, 20, 'AR', 'Concarán'),
(1766, 20, 'AR', 'Cortaderas'),
(1767, 20, 'AR', 'El Morro'),
(1768, 20, 'AR', 'El Trapiche'),
(1769, 20, 'AR', 'El Volcán'),
(1770, 20, 'AR', 'Fortín El Patria'),
(1771, 20, 'AR', 'Fortuna'),
(1772, 20, 'AR', 'Fraga'),
(1773, 20, 'AR', 'Juan Jorba'),
(1774, 20, 'AR', 'Juan Llerena'),
(1775, 20, 'AR', 'Juana Koslay'),
(1776, 20, 'AR', 'Justo Daract'),
(1777, 20, 'AR', 'La Calera'),
(1778, 20, 'AR', 'La Florida'),
(1779, 20, 'AR', 'La Punilla'),
(1780, 20, 'AR', 'La Toma'),
(1781, 20, 'AR', 'Lafinur'),
(1782, 20, 'AR', 'Las Aguadas'),
(1783, 20, 'AR', 'Las Chacras'),
(1784, 20, 'AR', 'Las Lagunas'),
(1785, 20, 'AR', 'Las Vertientes'),
(1786, 20, 'AR', 'Lavaisse'),
(1787, 20, 'AR', 'Leandro N. Alem'),
(1788, 20, 'AR', 'Los Molles'),
(1789, 20, 'AR', 'Luján'),
(1790, 20, 'AR', 'Mercedes'),
(1791, 20, 'AR', 'Merlo'),
(1792, 20, 'AR', 'Naschel'),
(1793, 20, 'AR', 'Navia'),
(1794, 20, 'AR', 'Nogolí'),
(1795, 20, 'AR', 'Nueva Galia'),
(1796, 20, 'AR', 'Papagayos'),
(1797, 20, 'AR', 'Paso Grande'),
(1798, 20, 'AR', 'Potrero de Los Funes'),
(1799, 20, 'AR', 'Quines'),
(1800, 20, 'AR', 'Renca'),
(1801, 20, 'AR', 'Saladillo'),
(1802, 20, 'AR', 'San Francisco'),
(1803, 20, 'AR', 'San Gerónimo'),
(1804, 20, 'AR', 'San Martín'),
(1805, 20, 'AR', 'San Pablo'),
(1806, 20, 'AR', 'Santa Rosa de Conlara'),
(1807, 20, 'AR', 'Talita'),
(1808, 20, 'AR', 'Tilisarao'),
(1809, 20, 'AR', 'Unión'),
(1810, 20, 'AR', 'Villa de La Quebrada'),
(1811, 20, 'AR', 'Villa de Praga'),
(1812, 20, 'AR', 'Villa del Carmen'),
(1813, 20, 'AR', 'Villa Gral. Roca'),
(1814, 20, 'AR', 'Villa Larca'),
(1815, 20, 'AR', 'Villa Mercedes'),
(1816, 20, 'AR', 'Zanjitas'),
(1817, 21, 'AR', 'Calafate'),
(1818, 21, 'AR', 'Caleta Olivia'),
(1819, 21, 'AR', 'Cañadón Seco'),
(1820, 21, 'AR', 'Comandante Piedrabuena'),
(1821, 21, 'AR', 'El Calafate'),
(1822, 21, 'AR', 'El Chaltén'),
(1823, 21, 'AR', 'Gdor. Gregores'),
(1824, 21, 'AR', 'Hipólito Yrigoyen'),
(1825, 21, 'AR', 'Jaramillo'),
(1826, 21, 'AR', 'Koluel Kaike'),
(1827, 21, 'AR', 'Las Heras'),
(1828, 21, 'AR', 'Los Antiguos'),
(1829, 21, 'AR', 'Perito Moreno'),
(1830, 21, 'AR', 'Pico Truncado'),
(1831, 21, 'AR', 'Pto. Deseado'),
(1832, 21, 'AR', 'Pto. San Julián'),
(1833, 21, 'AR', 'Pto. 21'),
(1834, 21, 'AR', 'Río Cuarto'),
(1835, 21, 'AR', 'Río Gallegos'),
(1836, 21, 'AR', 'Río Turbio'),
(1837, 21, 'AR', 'Tres Lagos'),
(1838, 21, 'AR', 'Veintiocho De Noviembre'),
(1839, 22, 'AR', 'Aarón Castellanos'),
(1840, 22, 'AR', 'Acebal'),
(1841, 22, 'AR', 'Aguará Grande'),
(1842, 22, 'AR', 'Albarellos'),
(1843, 22, 'AR', 'Alcorta'),
(1844, 22, 'AR', 'Aldao'),
(1845, 22, 'AR', 'Alejandra'),
(1846, 22, 'AR', 'Álvarez'),
(1847, 22, 'AR', 'Ambrosetti'),
(1848, 22, 'AR', 'Amenábar'),
(1849, 22, 'AR', 'Angélica'),
(1850, 22, 'AR', 'Angeloni'),
(1851, 22, 'AR', 'Arequito'),
(1852, 22, 'AR', 'Arminda'),
(1853, 22, 'AR', 'Armstrong'),
(1854, 22, 'AR', 'Arocena'),
(1855, 22, 'AR', 'Arroyo Aguiar'),
(1856, 22, 'AR', 'Arroyo Ceibal'),
(1857, 22, 'AR', 'Arroyo Leyes'),
(1858, 22, 'AR', 'Arroyo Seco'),
(1859, 22, 'AR', 'Arrufó'),
(1860, 22, 'AR', 'Arteaga'),
(1861, 22, 'AR', 'Ataliva'),
(1862, 22, 'AR', 'Aurelia'),
(1863, 22, 'AR', 'Avellaneda'),
(1864, 22, 'AR', 'Barrancas'),
(1865, 22, 'AR', 'Bauer Y Sigel'),
(1866, 22, 'AR', 'Bella Italia'),
(1867, 22, 'AR', 'Berabevú'),
(1868, 22, 'AR', 'Berna'),
(1869, 22, 'AR', 'Bernardo de Irigoyen'),
(1870, 22, 'AR', 'Bigand'),
(1871, 22, 'AR', 'Bombal'),
(1872, 22, 'AR', 'Bouquet'),
(1873, 22, 'AR', 'Bustinza'),
(1874, 22, 'AR', 'Cabal'),
(1875, 22, 'AR', 'Cacique Ariacaiquin'),
(1876, 22, 'AR', 'Cafferata'),
(1877, 22, 'AR', 'Calchaquí'),
(1878, 22, 'AR', 'Campo Andino'),
(1879, 22, 'AR', 'Campo Piaggio'),
(1880, 22, 'AR', 'Cañada de Gómez'),
(1881, 22, 'AR', 'Cañada del Ucle'),
(1882, 22, 'AR', 'Cañada Rica'),
(1883, 22, 'AR', 'Cañada Rosquín'),
(1884, 22, 'AR', 'Candioti'),
(1885, 22, 'AR', 'Capital'),
(1886, 22, 'AR', 'Capitán Bermúdez'),
(1887, 22, 'AR', 'Capivara'),
(1888, 22, 'AR', 'Carcarañá'),
(1889, 22, 'AR', 'Carlos Pellegrini'),
(1890, 22, 'AR', 'Carmen'),
(1891, 22, 'AR', 'Carmen Del Sauce'),
(1892, 22, 'AR', 'Carreras'),
(1893, 22, 'AR', 'Carrizales'),
(1894, 22, 'AR', 'Casalegno'),
(1895, 22, 'AR', 'Casas'),
(1896, 22, 'AR', 'Casilda'),
(1897, 22, 'AR', 'Castelar'),
(1898, 22, 'AR', 'Castellanos'),
(1899, 22, 'AR', 'Cayastá'),
(1900, 22, 'AR', 'Cayastacito'),
(1901, 22, 'AR', 'Centeno'),
(1902, 22, 'AR', 'Cepeda'),
(1903, 22, 'AR', 'Ceres'),
(1904, 22, 'AR', 'Chabás'),
(1905, 22, 'AR', 'Chañar Ladeado'),
(1906, 22, 'AR', 'Chapuy'),
(1907, 22, 'AR', 'Chovet'),
(1908, 22, 'AR', 'Christophersen'),
(1909, 22, 'AR', 'Classon'),
(1910, 22, 'AR', 'Cnel. Arnold'),
(1911, 22, 'AR', 'Cnel. Bogado'),
(1912, 22, 'AR', 'Cnel. Dominguez'),
(1913, 22, 'AR', 'Cnel. Fraga'),
(1914, 22, 'AR', 'Col. Aldao'),
(1915, 22, 'AR', 'Col. Ana'),
(1916, 22, 'AR', 'Col. Belgrano'),
(1917, 22, 'AR', 'Col. Bicha'),
(1918, 22, 'AR', 'Col. Bigand'),
(1919, 22, 'AR', 'Col. Bossi'),
(1920, 22, 'AR', 'Col. Cavour'),
(1921, 22, 'AR', 'Col. Cello'),
(1922, 22, 'AR', 'Col. Dolores'),
(1923, 22, 'AR', 'Col. Dos Rosas'),
(1924, 22, 'AR', 'Col. Durán'),
(1925, 22, 'AR', 'Col. Iturraspe'),
(1926, 22, 'AR', 'Col. Margarita'),
(1927, 22, 'AR', 'Col. Mascias'),
(1928, 22, 'AR', 'Col. Raquel'),
(1929, 22, 'AR', 'Col. Rosa'),
(1930, 22, 'AR', 'Col. San José'),
(1931, 22, 'AR', 'Constanza'),
(1932, 22, 'AR', 'Coronda'),
(1933, 22, 'AR', 'Correa'),
(1934, 22, 'AR', 'Crispi'),
(1935, 22, 'AR', 'Cululú'),
(1936, 22, 'AR', 'Curupayti'),
(1937, 22, 'AR', 'Desvio Arijón'),
(1938, 22, 'AR', 'Diaz'),
(1939, 22, 'AR', 'Diego de Alvear'),
(1940, 22, 'AR', 'Egusquiza'),
(1941, 22, 'AR', 'El Arazá'),
(1942, 22, 'AR', 'El Rabón'),
(1943, 22, 'AR', 'El Sombrerito'),
(1944, 22, 'AR', 'El Trébol'),
(1945, 22, 'AR', 'Elisa'),
(1946, 22, 'AR', 'Elortondo'),
(1947, 22, 'AR', 'Emilia'),
(1948, 22, 'AR', 'Empalme San Carlos'),
(1949, 22, 'AR', 'Empalme Villa Constitucion'),
(1950, 22, 'AR', 'Esmeralda'),
(1951, 22, 'AR', 'Esperanza'),
(1952, 22, 'AR', 'Estación Alvear'),
(1953, 22, 'AR', 'Estacion Clucellas'),
(1954, 22, 'AR', 'Esteban Rams'),
(1955, 22, 'AR', 'Esther'),
(1956, 22, 'AR', 'Esustolia'),
(1957, 22, 'AR', 'Eusebia'),
(1958, 22, 'AR', 'Felicia'),
(1959, 22, 'AR', 'Fidela'),
(1960, 22, 'AR', 'Fighiera'),
(1961, 22, 'AR', 'Firmat'),
(1962, 22, 'AR', 'Florencia'),
(1963, 22, 'AR', 'Fortín Olmos'),
(1964, 22, 'AR', 'Franck'),
(1965, 22, 'AR', 'Fray Luis Beltrán'),
(1966, 22, 'AR', 'Frontera'),
(1967, 22, 'AR', 'Fuentes'),
(1968, 22, 'AR', 'Funes'),
(1969, 22, 'AR', 'Gaboto'),
(1970, 22, 'AR', 'Galisteo'),
(1971, 22, 'AR', 'Gálvez'),
(1972, 22, 'AR', 'Garabalto'),
(1973, 22, 'AR', 'Garibaldi'),
(1974, 22, 'AR', 'Gato Colorado'),
(1975, 22, 'AR', 'Gdor. Crespo'),
(1976, 22, 'AR', 'Gessler'),
(1977, 22, 'AR', 'Godoy'),
(1978, 22, 'AR', 'Golondrina'),
(1979, 22, 'AR', 'Gral. Gelly'),
(1980, 22, 'AR', 'Gral. Lagos'),
(1981, 22, 'AR', 'Granadero Baigorria'),
(1982, 22, 'AR', 'Gregoria Perez De Denis'),
(1983, 22, 'AR', 'Grutly'),
(1984, 22, 'AR', 'Guadalupe N.'),
(1985, 22, 'AR', 'Gödeken'),
(1986, 22, 'AR', 'Helvecia'),
(1987, 22, 'AR', 'Hersilia'),
(1988, 22, 'AR', 'Hipatía'),
(1989, 22, 'AR', 'Huanqueros'),
(1990, 22, 'AR', 'Hugentobler'),
(1991, 22, 'AR', 'Hughes'),
(1992, 22, 'AR', 'Humberto 1º'),
(1993, 22, 'AR', 'Humboldt'),
(1994, 22, 'AR', 'Ibarlucea'),
(1995, 22, 'AR', 'Ing. Chanourdie'),
(1996, 22, 'AR', 'Intiyaco'),
(1997, 22, 'AR', 'Ituzaingó'),
(1998, 22, 'AR', 'Jacinto L. Aráuz'),
(1999, 22, 'AR', 'Josefina'),
(2000, 22, 'AR', 'Juan B. Molina'),
(2001, 22, 'AR', 'Juan de Garay'),
(2002, 22, 'AR', 'Juncal'),
(2003, 22, 'AR', 'La Brava'),
(2004, 22, 'AR', 'La Cabral'),
(2005, 22, 'AR', 'La Camila'),
(2006, 22, 'AR', 'La Chispa'),
(2007, 22, 'AR', 'La Clara'),
(2008, 22, 'AR', 'La Criolla'),
(2009, 22, 'AR', 'La Gallareta'),
(2010, 22, 'AR', 'La Lucila'),
(2011, 22, 'AR', 'La Pelada'),
(2012, 22, 'AR', 'La Penca'),
(2013, 22, 'AR', 'La Rubia'),
(2014, 22, 'AR', 'La Sarita'),
(2015, 22, 'AR', 'La Vanguardia'),
(2016, 22, 'AR', 'Labordeboy'),
(2017, 22, 'AR', 'Laguna Paiva'),
(2018, 22, 'AR', 'Landeta'),
(2019, 22, 'AR', 'Lanteri'),
(2020, 22, 'AR', 'Larrechea'),
(2021, 22, 'AR', 'Las Avispas'),
(2022, 22, 'AR', 'Las Bandurrias'),
(2023, 22, 'AR', 'Las Garzas'),
(2024, 22, 'AR', 'Las Palmeras'),
(2025, 22, 'AR', 'Las Parejas'),
(2026, 22, 'AR', 'Las Petacas'),
(2027, 22, 'AR', 'Las Rosas'),
(2028, 22, 'AR', 'Las Toscas'),
(2029, 22, 'AR', 'Las Tunas'),
(2030, 22, 'AR', 'Lazzarino'),
(2031, 22, 'AR', 'Lehmann'),
(2032, 22, 'AR', 'Llambi Campbell'),
(2033, 22, 'AR', 'Logroño'),
(2034, 22, 'AR', 'Loma Alta'),
(2035, 22, 'AR', 'López'),
(2036, 22, 'AR', 'Los Amores'),
(2037, 22, 'AR', 'Los Cardos'),
(2038, 22, 'AR', 'Los Laureles'),
(2039, 22, 'AR', 'Los Molinos'),
(2040, 22, 'AR', 'Los Quirquinchos'),
(2041, 22, 'AR', 'Lucio V. Lopez'),
(2042, 22, 'AR', 'Luis Palacios'),
(2043, 22, 'AR', 'Ma. Juana'),
(2044, 22, 'AR', 'Ma. Luisa'),
(2045, 22, 'AR', 'Ma. Susana'),
(2046, 22, 'AR', 'Ma. Teresa'),
(2047, 22, 'AR', 'Maciel'),
(2048, 22, 'AR', 'Maggiolo'),
(2049, 22, 'AR', 'Malabrigo'),
(2050, 22, 'AR', 'Marcelino Escalada'),
(2051, 22, 'AR', 'Margarita'),
(2052, 22, 'AR', 'Matilde'),
(2053, 22, 'AR', 'Mauá'),
(2054, 22, 'AR', 'Máximo Paz'),
(2055, 22, 'AR', 'Melincué'),
(2056, 22, 'AR', 'Miguel Torres'),
(2057, 22, 'AR', 'Moisés Ville'),
(2058, 22, 'AR', 'Monigotes'),
(2059, 22, 'AR', 'Monje'),
(2060, 22, 'AR', 'Monte Obscuridad'),
(2061, 22, 'AR', 'Monte Vera'),
(2062, 22, 'AR', 'Montefiore'),
(2063, 22, 'AR', 'Montes de Oca'),
(2064, 22, 'AR', 'Murphy'),
(2065, 22, 'AR', 'Ñanducita'),
(2066, 22, 'AR', 'Naré'),
(2067, 22, 'AR', 'Nelson'),
(2068, 22, 'AR', 'Nicanor E. Molinas'),
(2069, 22, 'AR', 'Nuevo Torino'),
(2070, 22, 'AR', 'Oliveros'),
(2071, 22, 'AR', 'Palacios'),
(2072, 22, 'AR', 'Pavón'),
(2073, 22, 'AR', 'Pavón Arriba');
INSERT INTO Ciudades VALUES
(2074, 22, 'AR', 'Pedro Gómez Cello'),
(2075, 22, 'AR', 'Pérez'),
(2076, 22, 'AR', 'Peyrano'),
(2077, 22, 'AR', 'Piamonte'),
(2078, 22, 'AR', 'Pilar'),
(2079, 22, 'AR', 'Piñero'),
(2080, 22, 'AR', 'Plaza Clucellas'),
(2081, 22, 'AR', 'Portugalete'),
(2082, 22, 'AR', 'Pozo Borrado'),
(2083, 22, 'AR', 'Progreso'),
(2084, 22, 'AR', 'Providencia'),
(2085, 22, 'AR', 'Pte. Roca'),
(2086, 22, 'AR', 'Pueblo Andino'),
(2087, 22, 'AR', 'Pueblo Esther'),
(2088, 22, 'AR', 'Pueblo Gral. San Martín'),
(2089, 22, 'AR', 'Pueblo Irigoyen'),
(2090, 22, 'AR', 'Pueblo Marini'),
(2091, 22, 'AR', 'Pueblo Muñoz'),
(2092, 22, 'AR', 'Pueblo Uranga'),
(2093, 22, 'AR', 'Pujato'),
(2094, 22, 'AR', 'Pujato N.'),
(2095, 22, 'AR', 'Rafaela'),
(2096, 22, 'AR', 'Ramayón'),
(2097, 22, 'AR', 'Ramona'),
(2098, 22, 'AR', 'Reconquista'),
(2099, 22, 'AR', 'Recreo'),
(2100, 22, 'AR', 'Ricardone'),
(2101, 22, 'AR', 'Rivadavia'),
(2102, 22, 'AR', 'Roldán'),
(2103, 22, 'AR', 'Romang'),
(2104, 22, 'AR', 'Rosario'),
(2105, 22, 'AR', 'Rueda'),
(2106, 22, 'AR', 'Rufino'),
(2107, 22, 'AR', 'Sa Pereira'),
(2108, 22, 'AR', 'Saguier'),
(2109, 22, 'AR', 'Saladero M. Cabal'),
(2110, 22, 'AR', 'Salto Grande'),
(2111, 22, 'AR', 'San Agustín'),
(2112, 22, 'AR', 'San Antonio de Obligado'),
(2113, 22, 'AR', 'San Bernardo (N.J.)'),
(2114, 22, 'AR', 'San Bernardo (S.J.)'),
(2115, 22, 'AR', 'San Carlos Centro'),
(2116, 22, 'AR', 'San Carlos N.'),
(2117, 22, 'AR', 'San Carlos S.'),
(2118, 22, 'AR', 'San Cristóbal'),
(2119, 22, 'AR', 'San Eduardo'),
(2120, 22, 'AR', 'San Eugenio'),
(2121, 22, 'AR', 'San Fabián'),
(2122, 22, 'AR', 'San Fco. de Santa Fé'),
(2123, 22, 'AR', 'San Genaro'),
(2124, 22, 'AR', 'San Genaro N.'),
(2125, 22, 'AR', 'San Gregorio'),
(2126, 22, 'AR', 'San Guillermo'),
(2127, 22, 'AR', 'San Javier'),
(2128, 22, 'AR', 'San Jerónimo del Sauce'),
(2129, 22, 'AR', 'San Jerónimo N.'),
(2130, 22, 'AR', 'San Jerónimo S.'),
(2131, 22, 'AR', 'San Jorge'),
(2132, 22, 'AR', 'San José de La Esquina'),
(2133, 22, 'AR', 'San José del Rincón'),
(2134, 22, 'AR', 'San Justo'),
(2135, 22, 'AR', 'San Lorenzo'),
(2136, 22, 'AR', 'San Mariano'),
(2137, 22, 'AR', 'San Martín de Las Escobas'),
(2138, 22, 'AR', 'San Martín N.'),
(2139, 22, 'AR', 'San Vicente'),
(2140, 22, 'AR', 'Sancti Spititu'),
(2141, 22, 'AR', 'Sanford'),
(2142, 22, 'AR', 'Santo Domingo'),
(2143, 22, 'AR', 'Santo Tomé'),
(2144, 22, 'AR', 'Santurce'),
(2145, 22, 'AR', 'Sargento Cabral'),
(2146, 22, 'AR', 'Sarmiento'),
(2147, 22, 'AR', 'Sastre'),
(2148, 22, 'AR', 'Sauce Viejo'),
(2149, 22, 'AR', 'Serodino'),
(2150, 22, 'AR', 'Silva'),
(2151, 22, 'AR', 'Soldini'),
(2152, 22, 'AR', 'Soledad'),
(2153, 22, 'AR', 'Soutomayor'),
(2154, 22, 'AR', 'Sta. Clara de Buena Vista'),
(2155, 22, 'AR', 'Sta. Clara de Saguier'),
(2156, 22, 'AR', 'Sta. Isabel'),
(2157, 22, 'AR', 'Sta. Margarita'),
(2158, 22, 'AR', 'Sta. Maria Centro'),
(2159, 22, 'AR', 'Sta. María N.'),
(2160, 22, 'AR', 'Sta. Rosa'),
(2161, 22, 'AR', 'Sta. Teresa'),
(2162, 22, 'AR', 'Suardi'),
(2163, 22, 'AR', 'Sunchales'),
(2164, 22, 'AR', 'Susana'),
(2165, 22, 'AR', 'Tacuarendí'),
(2166, 22, 'AR', 'Tacural'),
(2167, 22, 'AR', 'Tartagal'),
(2168, 22, 'AR', 'Teodelina'),
(2169, 22, 'AR', 'Theobald'),
(2170, 22, 'AR', 'Timbúes'),
(2171, 22, 'AR', 'Toba'),
(2172, 22, 'AR', 'Tortugas'),
(2173, 22, 'AR', 'Tostado'),
(2174, 22, 'AR', 'Totoras'),
(2175, 22, 'AR', 'Traill'),
(2176, 22, 'AR', 'Venado Tuerto'),
(2177, 22, 'AR', 'Vera'),
(2178, 22, 'AR', 'Vera y Pintado'),
(2179, 22, 'AR', 'Videla'),
(2180, 22, 'AR', 'Vila'),
(2181, 22, 'AR', 'Villa Amelia'),
(2182, 22, 'AR', 'Villa Ana'),
(2183, 22, 'AR', 'Villa Cañas'),
(2184, 22, 'AR', 'Villa Constitución'),
(2185, 22, 'AR', 'Villa Eloísa'),
(2186, 22, 'AR', 'Villa Gdor. Gálvez'),
(2187, 22, 'AR', 'Villa Guillermina'),
(2188, 22, 'AR', 'Villa Minetti'),
(2189, 22, 'AR', 'Villa Mugueta'),
(2190, 22, 'AR', 'Villa Ocampo'),
(2191, 22, 'AR', 'Villa San José'),
(2192, 22, 'AR', 'Villa Saralegui'),
(2193, 22, 'AR', 'Villa Trinidad'),
(2194, 22, 'AR', 'Villada'),
(2195, 22, 'AR', 'Virginia'),
(2196, 22, 'AR', 'Wheelwright'),
(2197, 22, 'AR', 'Zavalla'),
(2198, 22, 'AR', 'Zenón Pereira'),
(2199, 23, 'AR', 'Añatuya'),
(2200, 23, 'AR', 'Árraga'),
(2201, 23, 'AR', 'Bandera'),
(2202, 23, 'AR', 'Bandera Bajada'),
(2203, 23, 'AR', 'Beltrán'),
(2204, 23, 'AR', 'Brea Pozo'),
(2205, 23, 'AR', 'Campo Gallo'),
(2206, 23, 'AR', 'Capital'),
(2207, 23, 'AR', 'Chilca Juliana'),
(2208, 23, 'AR', 'Choya'),
(2209, 23, 'AR', 'Clodomira'),
(2210, 23, 'AR', 'Col. Alpina'),
(2211, 23, 'AR', 'Col. Dora'),
(2212, 23, 'AR', 'Col. El Simbolar Robles'),
(2213, 23, 'AR', 'El Bobadal'),
(2214, 23, 'AR', 'El Charco'),
(2215, 23, 'AR', 'El Mojón'),
(2216, 23, 'AR', 'Estación Atamisqui'),
(2217, 23, 'AR', 'Estación Simbolar'),
(2218, 23, 'AR', 'Fernández'),
(2219, 23, 'AR', 'Fortín Inca'),
(2220, 23, 'AR', 'Frías'),
(2221, 23, 'AR', 'Garza'),
(2222, 23, 'AR', 'Gramilla'),
(2223, 23, 'AR', 'Guardia Escolta'),
(2224, 23, 'AR', 'Herrera'),
(2225, 23, 'AR', 'Icaño'),
(2226, 23, 'AR', 'Ing. Forres'),
(2227, 23, 'AR', 'La Banda'),
(2228, 23, 'AR', 'La Cañada'),
(2229, 23, 'AR', 'Laprida'),
(2230, 23, 'AR', 'Lavalle'),
(2231, 23, 'AR', 'Loreto'),
(2232, 23, 'AR', 'Los Juríes'),
(2233, 23, 'AR', 'Los Núñez'),
(2234, 23, 'AR', 'Los Pirpintos'),
(2235, 23, 'AR', 'Los Quiroga'),
(2236, 23, 'AR', 'Los Telares'),
(2237, 23, 'AR', 'Lugones'),
(2238, 23, 'AR', 'Malbrán'),
(2239, 23, 'AR', 'Matara'),
(2240, 23, 'AR', 'Medellín'),
(2241, 23, 'AR', 'Monte Quemado'),
(2242, 23, 'AR', 'Nueva Esperanza'),
(2243, 23, 'AR', 'Nueva Francia'),
(2244, 23, 'AR', 'Palo Negro'),
(2245, 23, 'AR', 'Pampa de Los Guanacos'),
(2246, 23, 'AR', 'Pinto'),
(2247, 23, 'AR', 'Pozo Hondo'),
(2248, 23, 'AR', 'Quimilí'),
(2249, 23, 'AR', 'Real Sayana'),
(2250, 23, 'AR', 'Sachayoj'),
(2251, 23, 'AR', 'San Pedro de Guasayán'),
(2252, 23, 'AR', 'Selva'),
(2253, 23, 'AR', 'Sol de Julio'),
(2254, 23, 'AR', 'Sumampa'),
(2255, 23, 'AR', 'Suncho Corral'),
(2256, 23, 'AR', 'Taboada'),
(2257, 23, 'AR', 'Tapso'),
(2258, 23, 'AR', 'Termas de Rio Hondo'),
(2259, 23, 'AR', 'Tintina'),
(2260, 23, 'AR', 'Tomas Young'),
(2261, 23, 'AR', 'Vilelas'),
(2262, 23, 'AR', 'Villa Atamisqui'),
(2263, 23, 'AR', 'Villa La Punta'),
(2264, 23, 'AR', 'Villa Ojo de Agua'),
(2265, 23, 'AR', 'Villa Río Hondo'),
(2266, 23, 'AR', 'Villa Salavina'),
(2267, 23, 'AR', 'Villa Unión'),
(2268, 23, 'AR', 'Vilmer'),
(2269, 23, 'AR', 'Weisburd'),
(2270, 24, 'AR', 'Río Grande'),
(2271, 24, 'AR', 'Tolhuin'),
(2272, 24, 'AR', 'Ushuaia'),
(2273, 25, 'AR', 'Acheral'),
(2274, 25, 'AR', 'Agua Dulce'),
(2275, 25, 'AR', 'Aguilares'),
(2276, 25, 'AR', 'Alderetes'),
(2277, 25, 'AR', 'Alpachiri'),
(2278, 25, 'AR', 'Alto Verde'),
(2279, 25, 'AR', 'Amaicha del Valle'),
(2280, 25, 'AR', 'Amberes'),
(2281, 25, 'AR', 'Ancajuli'),
(2282, 25, 'AR', 'Arcadia'),
(2283, 25, 'AR', 'Atahona'),
(2284, 25, 'AR', 'Banda del Río Sali'),
(2285, 25, 'AR', 'Bella Vista'),
(2286, 25, 'AR', 'Buena Vista'),
(2287, 25, 'AR', 'Burruyacú'),
(2288, 25, 'AR', 'Capitán Cáceres'),
(2289, 25, 'AR', 'Cevil Redondo'),
(2290, 25, 'AR', 'Choromoro'),
(2291, 25, 'AR', 'Ciudacita'),
(2292, 25, 'AR', 'Colalao del Valle'),
(2293, 25, 'AR', 'Colombres'),
(2294, 25, 'AR', 'Concepción'),
(2295, 25, 'AR', 'Delfín Gallo'),
(2296, 25, 'AR', 'El Bracho'),
(2297, 25, 'AR', 'El Cadillal'),
(2298, 25, 'AR', 'El Cercado'),
(2299, 25, 'AR', 'El Chañar'),
(2300, 25, 'AR', 'El Manantial'),
(2301, 25, 'AR', 'El Mojón'),
(2302, 25, 'AR', 'El Mollar'),
(2303, 25, 'AR', 'El Naranjito'),
(2304, 25, 'AR', 'El Naranjo'),
(2305, 25, 'AR', 'El Polear'),
(2306, 25, 'AR', 'El Puestito'),
(2307, 25, 'AR', 'El Sacrificio'),
(2308, 25, 'AR', 'El Timbó'),
(2309, 25, 'AR', 'Escaba'),
(2310, 25, 'AR', 'Esquina'),
(2311, 25, 'AR', 'Estación Aráoz'),
(2312, 25, 'AR', 'Famaillá'),
(2313, 25, 'AR', 'Gastone'),
(2314, 25, 'AR', 'Gdor. Garmendia'),
(2315, 25, 'AR', 'Gdor. Piedrabuena'),
(2316, 25, 'AR', 'Graneros'),
(2317, 25, 'AR', 'Huasa Pampa'),
(2318, 25, 'AR', 'J. B. Alberdi'),
(2319, 25, 'AR', 'La Cocha'),
(2320, 25, 'AR', 'La Esperanza'),
(2321, 25, 'AR', 'La Florida'),
(2322, 25, 'AR', 'La Ramada'),
(2323, 25, 'AR', 'La Trinidad'),
(2324, 25, 'AR', 'Lamadrid'),
(2325, 25, 'AR', 'Las Cejas'),
(2326, 25, 'AR', 'Las Talas'),
(2327, 25, 'AR', 'Las Talitas'),
(2328, 25, 'AR', 'Los Bulacio'),
(2329, 25, 'AR', 'Los Gómez'),
(2330, 25, 'AR', 'Los Nogales'),
(2331, 25, 'AR', 'Los Pereyra'),
(2332, 25, 'AR', 'Los Pérez'),
(2333, 25, 'AR', 'Los Puestos'),
(2334, 25, 'AR', 'Los Ralos'),
(2335, 25, 'AR', 'Los Sarmientos'),
(2336, 25, 'AR', 'Los Sosa'),
(2337, 25, 'AR', 'Lules'),
(2338, 25, 'AR', 'M. García Fernández'),
(2339, 25, 'AR', 'Manuela Pedraza'),
(2340, 25, 'AR', 'Medinas'),
(2341, 25, 'AR', 'Monte Bello'),
(2342, 25, 'AR', 'Monteagudo'),
(2343, 25, 'AR', 'Monteros'),
(2344, 25, 'AR', 'Padre Monti'),
(2345, 25, 'AR', 'Pampa Mayo'),
(2346, 25, 'AR', 'Quilmes'),
(2347, 25, 'AR', 'Raco'),
(2348, 25, 'AR', 'Ranchillos'),
(2349, 25, 'AR', 'Río Chico'),
(2350, 25, 'AR', 'Río Colorado'),
(2351, 25, 'AR', 'Río Seco'),
(2352, 25, 'AR', 'Rumi Punco'),
(2353, 25, 'AR', 'San Andrés'),
(2354, 25, 'AR', 'San Felipe'),
(2355, 25, 'AR', 'San Ignacio'),
(2356, 25, 'AR', 'San Javier'),
(2357, 25, 'AR', 'San José'),
(2358, 25, 'AR', 'San Miguel de Tucumán'),
(2359, 25, 'AR', 'San Pedro'),
(2360, 25, 'AR', 'San Pedro de Colalao'),
(2361, 25, 'AR', 'Santa Rosa de Leales'),
(2362, 25, 'AR', 'Sgto. Moya'),
(2363, 25, 'AR', 'Siete de Abril'),
(2364, 25, 'AR', 'Simoca'),
(2365, 25, 'AR', 'Soldado Maldonado'),
(2366, 25, 'AR', 'Sta. Ana'),
(2367, 25, 'AR', 'Sta. Cruz'),
(2368, 25, 'AR', 'Sta. Lucía'),
(2369, 25, 'AR', 'Taco Ralo'),
(2370, 25, 'AR', 'Tafí del Valle'),
(2371, 25, 'AR', 'Tafí Viejo'),
(2372, 25, 'AR', 'Tapia'),
(2373, 25, 'AR', 'Teniente Berdina'),
(2374, 25, 'AR', 'Trancas'),
(2375, 25, 'AR', 'Villa Belgrano'),
(2376, 25, 'AR', 'Villa Benjamín Araoz'),
(2377, 25, 'AR', 'Villa Chiligasta'),
(2378, 25, 'AR', 'Villa de Leales'),
(2379, 25, 'AR', 'Villa Quinteros'),
(2380, 25, 'AR', 'Yánima'),
(2381, 25, 'AR', 'Yerba Buena');

/* Carga inicial Domicilios */
INSERT INTO Domicilios VALUES (1, 2358, 25, 'AR', 'Av. Manuel Belgrano 1456', '4000', now(), 'Domicilio sucursal Belgrano');
INSERT INTO Domicilios VALUES (2, 2358, 25, 'AR', 'Ildefonso de las Muñecas 374', '4000', now(), 'Domicilio sucursal Muñecas');
INSERT INTO Domicilios VALUES (3, 1678, 18, 'AR', 'España 109', '4400', now(), 'Domicilio sucursal Salta');
INSERT INTO Domicilios VALUES (4, 2358, 25, 'AR', 'Uruguay 1274', '4000', now(), 'Domicilio fábrica');
INSERT INTO Domicilios VALUES (5, 2358, 25, 'AR', 'Bolivia 1653', '4000', now(), 'Domicilio lustrería');
INSERT INTO Domicilios VALUES (6, 2358, 25, 'AR', '12 de Octubre 980', '4000', now(), 'Domicilio ex-lustrería');
INSERT INTO Domicilios VALUES (7, 2358, 25, 'AR', '12 de Octubre 760', '4000', now(), 'Domicilio depósito 12 de Octubre');
INSERT INTO Domicilios VALUES (8, 2358, 25, 'AR', 'Corrientes 1553', '4000', now(), 'Domicilio depósito Corrientes');

/* Carga inicial Ubicaciones */
INSERT INTO Ubicaciones VALUES (1,1, 'Sucursal Belgrano', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (2,2, 'Sucursal Muñecas', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (3,3, 'Sucursal Salta', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (4,4, 'Fábrica', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (5,5, 'Lustrería', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (6,6, 'Ex-lustrería', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (7,7, 'Depósito 12 de Octubre', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (8,8, 'Depósito Corrientes', now(), NULL, '', 'A');

/* Carga inicial Usuarios */
/*IdUsuario, IdRol, IdUbicacion, IdTipoDocumento, */

INSERT INTO Usuarios VALUES (1,1,1,1,'00000001','Adam', 'Super Admin','C', '+54 381 4321719', 'zimmermanmueblesgestion@gmail.com',2,'adam','Adam1234','TOKEN', NULL, 0, '1950-01-01', NOW(), NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (2,1,1,1,'39477073','Nicolás', 'Bachs','S', '+54 381 4491954', 'nicolas.bachs@gmail.com',0,'nbachs','081f2c59f57f53a74e651663f451ae2e8c711d4c0f6550b20b3bea1e2725afbe','', NULL, 0, '1995-12-27', NOW(), NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (3,1,1,1,'41144069','Loik', 'Choua','S', '+54 381 5483777', 'loikchoua4@gmail.com',0,'lchoua','7a2ce2c44232f375fdc5bb77fa2b0163fe3231563db69cbab1bf0e62734228f0','', NULL, 0, '1998-05-27', NOW(), NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (4,1,1,1,'21328891','Silvia Graciela', 'Zimmerman','C', '+54 381 4409726', 'zimmermansilvia@gmail.com',3,'szimmerman','f156a1721e9b6c0cd10efc7a78538e67dc32162a908db2a33c44dfc228f93a34','', NULL, 0, '1970-06-08', NOW(), NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (5,1,1,1,'16458657','Noemy Fanny', 'Zimmerman','S', '+54 387 5240343', 'nomyz@hotmail.com',0,'nzimmerman','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1961-04-06', NOW(), NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (6,1,5,1,'13475551','Daniel Ernesto', 'Zimmerman','C', '+54 381 4409746', 'danielzimmerman@hotmail.com',3,'dzimmerman','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1959-10-01', NOW(), NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (7,3,5,1,'11476623','Dante Hugo', 'Sanchez','C', '', 'dantehugosanchez@gmail.com',1,'hsanchez','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '1992-02-01', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (8,3,5,1,'17182912','Jorge Eduardo', 'Maidana','C', '', 'jorgemaidana@gmail.com',1,'jmaidana','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '1998-05-11', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (9,3,5,1,'25543764','Fernando', 'Vazquez','C', '', 'fernandovazquez@gmail.com',1,'fvazquez','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2000-07-01', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (10,3,5,1,'17947875','Jorge Luis', 'Brito','C', '', 'jorgebrito@gmail.com',1,'jbrito','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2005-10-27', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (11,2,2,1,'22665074','Liliana Del Valle', 'Tokar','C', '', 'lilianatokar@gmail.com',1,'ltokar','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2006-05-03', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (12,2,3,1,'25212971','Carolina Fanny', 'Monte','C', '', 'carolinamonte@gmail.com',1,'cmonte','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2009-06-03', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (13,3,3,1,'27562575','Fernando', 'Belmonte','C', '', 'fernandobelmonte@gmail.com',1,'fbelmonte','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2007-06-01', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (14,3,5,1,'32602001','Angel', 'Bigliardo','C', '', 'angelbigliardo@gmail.com',1,'abigliardo','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2008-02-13', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (15,3,4,1,'11890222','Miguel Angel', 'Melón','C', '', 'miguelmelon@gmail.com',1,'mmelon','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '1992-11-04', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (16,3,4,1,'26445850','Esteban Dario', 'Rajido','C', '', 'estebanrajido@gmail.com',1,'erajido','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '1998-07-06', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (17,3,5,1,'33541694','Jose María', 'Madrid','C', '', 'josemadrid@gmail.com',1,'jmadrid','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2011-10-17', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (18,3,5,1,'27652284','César Alberto', 'Jimenez','C', '', 'cesarjimenez@gmail.com',1,'cjimenez','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2016-03-01', NOW(), NULL, 'A');
INSERT INTO Usuarios VALUES (19,3,4,1,'37455195','Jacobo Juan', 'Cañete','C', '', 'jacobocanete@gmail.com',1,'jcañete','a356abb3d9cfa0eb9add70f70f42c3199dc5665dfc8da63ad5a1499372b5e098','', NULL, 0, '1970-01-01', '2016-12-01', NOW(), NULL, 'A');

/*Carga inicial TiposProducto*/
INSERT INTO TiposProducto (`IdTipoProducto`, `TipoProducto`) VALUES ('P', 'Producto fabricable');
INSERT INTO TiposProducto (`IdTipoProducto`, `TipoProducto`) VALUES ('N', 'Producto no fabricable');

/*Carga inicial GruposProducto*/
/*IdGrupo, Grupo, FechaAlta, FechaBaja, Descripcion, Estado*/
INSERT INTO GruposProducto VALUES (1, 'GE', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (2, 'MD', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (3, 'MI', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (4, 'MA', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (5, 'FC', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (6, 'DE', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (7, 'LA', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (8, 'VTH', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (9, 'SA', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (10, 'MZ', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (11, 'AH', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (12, 'AB', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (13, 'DA', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (14, 'SR', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (15, 'TR', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (16, 'Ebony', NOW(), NULL, '', 'A');
INSERT INTO GruposProducto VALUES (17, 'HAN', NOW(), NULL, '', 'A');

/*Carga inicial CategoriasProducto*/
/*IdCategoria, Categoria, Descripcion*/
INSERT INTO CategoriasProducto VALUES (1, 'Bahiut', '');
INSERT INTO CategoriasProducto VALUES (2, 'Banquetas', '');
INSERT INTO CategoriasProducto VALUES (3, 'Bar', '');
INSERT INTO CategoriasProducto VALUES (4, 'Bibliotecas', '');
INSERT INTO CategoriasProducto VALUES (5, 'Camas 1 P', '');
INSERT INTO CategoriasProducto VALUES (6, 'Camas 1 1/2 P', '');
INSERT INTO CategoriasProducto VALUES (7, 'Camas 2 1/2 P', '');
INSERT INTO CategoriasProducto VALUES (8, 'Cómodas', '');
INSERT INTO CategoriasProducto VALUES (9, 'Chifonier', '');
INSERT INTO CategoriasProducto VALUES (10, 'Divanes 1 P', '');
INSERT INTO CategoriasProducto VALUES (11, 'Divanes 1 1/2 P', '');
INSERT INTO CategoriasProducto VALUES (12, 'Divan cuna', '');
INSERT INTO CategoriasProducto VALUES (13, 'Dressoir', '');
INSERT INTO CategoriasProducto VALUES (14, 'Escritorios', '');
INSERT INTO CategoriasProducto VALUES (15, 'Espejos', '');
INSERT INTO CategoriasProducto VALUES (16, 'Lettos', '');
INSERT INTO CategoriasProducto VALUES (17, 'Mesas de comedor', '');
INSERT INTO CategoriasProducto VALUES (18, 'Sillas', '');
INSERT INTO CategoriasProducto VALUES (19, 'Sillones', '');
INSERT INTO CategoriasProducto VALUES (20, 'Butacas', '');
INSERT INTO CategoriasProducto VALUES (21, 'Mesas', '');
INSERT INTO CategoriasProducto VALUES (22, 'Mesas de Livings', '');
INSERT INTO CategoriasProducto VALUES (23, 'Mesas de TV', '');
INSERT INTO CategoriasProducto VALUES (24, 'Mesas de Costados', '');
INSERT INTO CategoriasProducto VALUES (25, 'Mesas de Luz', '');
INSERT INTO CategoriasProducto VALUES (26, 'Respaldos', '');

/*Carga inicial Productos*/
/*IdProducto, IdCategoria, IdGrupo, IdTipo, Producto, LongitudTela, FechaAlta, FechaBaja, Observaciones, Estado*/
INSERT INTO Productos VALUES  (1, 1, 4, 'P', 'Bahiut Inglés 0,89 C/Cub', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (2, 1, 4, 'P', 'Bahiut Inglés 1,65 Convencional', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (3, 1, 4, 'P', 'Bahiut L2000 1,60 C/Luz', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (4, 1, 4, 'P', 'Bahiut C/Varilla S/Copero 2,06x0,53', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (5, 1, 4, 'P', 'Bahiut C/Cuadritos S/Copero', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (6, 2, 4, 'P', 'Banqueta P/Vestidor Opus', 0.5, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (7, 2, 4, 'P', 'Banqueta Inglés Escabel Tap Simple', 0.5, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (8, 2, 4, 'P', 'Banqueta Inglés Reina Ana Tap Capitoné', 1, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (9, 2, 4, 'P', 'Banqueta Alta P/Bar Tapizada', 0.5, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (10, 2, 4, 'P', 'Banqueta Inglés Óvalo Tap Simple', 0.5, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (11, 3, 4, 'P', 'Barra Bar Moderna S/Moldura 1,50x0,40', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (12, 3, 4, 'P', 'Barra Bar Inglés 1,50x0,40', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (13, 3, 4, 'P', 'Alzada Bar Copero C/Espejo 1,65', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (14, 3, 4, 'P', 'Barra Bar C/Pluma 1,70x0,5', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (15, 3, 4, 'P', 'Bodega P/Colgar S/Luz', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (16, 4, 4, 'P', 'Biblioteca de Pie 0,80x1,80', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (17, 4, 4, 'P', 'Biblioteca Adicional 2 puertas C/Vidrio o Madera', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (18, 4, 4, 'P', 'Biblioteca Adicional 4 puertas C/Vidrio o Madera', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (19, 4, 4, 'P', 'Biblioteca Inglés C/Puerta Cristal Roble', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (20, 4, 4, 'P', 'Biblioteca Inglés S/Puerta Roble', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (21, 5, 4, 'P', 'Cama Bretaña', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (22, 5, 4, 'P', 'Cama Dov I', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (23, 5, 4, 'P', 'Cama Dov II', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (24, 5, 4, 'P', 'Cama Inglés Clásico', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (25, 5, 4, 'P', 'Cama Pau', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (26, 6, 4, 'P', 'Cama Dov I 1 1/2 P', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (27, 6, 4, 'P', 'Cama Dov II 1 1/2 P', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (28, 6, 4, 'P', 'Cama Inglés Clásico 1 1/2 P', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (29, 6, 4, 'P', 'Cama Opus 1 1/2 P', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (30, 6, 4, 'P', 'Cama Victoriana S/Estirilla', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (31, 7, 4, 'P', 'Cama Dov 2 1/2 P', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (32, 7, 4, 'P', 'Cama Inglés Bet 2 1/2 P', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (33, 7, 4, 'P', 'Cama Inglés Clásica 2 1/2 P', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (34, 7, 4, 'P', 'Espaldar Victoriano S/Estirilla 1,6', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (35, 7, 4, 'P', 'Espaldar de Cama Alicia 1,4', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (36, 8, 4, 'P', 'Comoda Dov 5 Cajones C/C', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (37, 8, 4, 'P', 'Comoda Alicia C/Aluminio', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (38, 8, 4, 'P', 'Comoda Alicia', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (39, 8, 4, 'P', 'Vestidor Dov C/Espejo Alas Móviles', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (40, 8, 4, 'P', 'Comoda IB 6 Cajones C/C', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (41, 9, 4, 'P', 'Chifonier Dov 6 Caj y Botinero', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (42, 9, 4, 'P', 'Chifonier Dov C/Molduras', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (43, 9, 4, 'P', 'Chifonier Ingles', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (44, 9, 4, 'P', 'Botinero C/2 Cajones', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (45, 17, 4, 'P', 'Base Inglés o K Rectangular o 4 Gajos', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (46, 17, 4, 'P', 'Base Inglés o K Redonda o 4 Gajos', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (47, 17, 4, 'P', 'Base K P/Cristal Cuadrado hasta 1,30x1,30', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (48, 17, 4, 'P', 'Base de Mesa 0,90x1,80 Gótica', 0, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (49, 17, 4, 'P', 'Mesa Rebatible de Pared 0,45x0,90', 0, NOW(), NULL, '', 'A');

INSERT INTO Productos VALUES  (50, 18, 9, 'P', 'Silla Cadiz Baja', 1.25, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (51, 18, 9, 'P', 'Silla Emi', 1.40, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (52, 18, 9, 'P', 'Silla Emi Capitoné', 2.3, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (53, 18, 9, 'P', 'Silla Lara', 1.25, NOW(), NULL, '', 'A');
INSERT INTO Productos VALUES  (54, 18, 9, 'P', 'Silla Valencia', 1.3, NOW(), NULL, '', 'A');

/*Carga inicial Telas*/
/*IdTela, Tela, FechaAlta, FechaBaja, Observaciones, Estado*/
INSERT INTO Telas VALUES (1, 'Panne Beige', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (2, 'Panne Natural', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (3, 'Panne Gris', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (4, 'Panne Sambayón', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (5, 'Panne Gamusa', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (6, 'Mecha Perla', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (7, 'Mecha Turquesa', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (8, 'Chen Rojo', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (9, 'Chen Natural', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (10, 'Chen Chocolate', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (11, 'New York Gris', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (12, 'New York Arena', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (13, 'New York Natural', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (14, 'Eco Cuero Marrón', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (15, 'Eco Cuero Chocolate', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (16, 'Eco Cuero Tiza', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (17, 'Bella Lino', NOW(), NULL, '', 'A');
INSERT INTO Telas VALUES (18, 'Bella Natural', NOW(), NULL, '', 'A'); 

/*Carga inicial Lustres*/
/*IdLustre, Lustre, Observaciones*/
INSERT INTO Lustres VALUES (1, 'CA1', '');
INSERT INTO Lustres VALUES (2, 'CA2', '');
INSERT INTO Lustres VALUES (3, 'CA3', '');
INSERT INTO Lustres VALUES (4, 'CA4', '');
INSERT INTO Lustres VALUES (5, 'CS', '');
INSERT INTO Lustres VALUES (6, 'IS', '');
INSERT INTO Lustres VALUES (7, 'Chocolate', '');
INSERT INTO Lustres VALUES (8, 'Wenghe', '');
INSERT INTO Lustres VALUES (9, 'Muestra S/Cliente', '');
