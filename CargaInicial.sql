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
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`, `FechaAlta`) VALUES (1, ', Administradores', 'Rol para los administradores de ZMGestion.', NOW());
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`, `FechaAlta`) VALUES (2, ', Vendedores', 'Rol para los vendedores de ZMGestion.', NOW());
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`, `FechaAlta`) VALUES (3, ', Fabricantes', 'Rol para los fabricantes de ZMGestion.', NOW());

/* Carga inicial permisos */
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (1, 'Crear rol', 'Permite a un usuario crear un nuevo rol.', 'zsp_rol_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (2, 'Borrar rol', 'Permite a un usuario borrar un rol existente, siempre y cuando ningun usuario tenga ese rol.', 'zsp_rol_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (3, 'Asignar permisos a rol', 'Permite a un usuario asignar permisos a un rol existente.', 'zsp_rol_asignar_permiso');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (4, 'Crear usuario', 'Permite a un usuario crear nuevos usuarios.', 'zsp_usuario_crear');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (5, 'Borrar usuario', 'Permite a un usuario borrar a otros usuarios siempre y cuando éste no tenga presupuestos, ventas, órdenes de producción, tareas o comprobantes asociados. Tampoco puede borrar al super administrador.', 'zsp_usuario_borrar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (6, 'Modificar usuario', 'Permite a un usuario modificar a otros usuarios.', 'zsp_usuario_modificar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (7, 'Buscar usuarios', 'Permite a un usuario buscar a otros usuarios.', 'zsp_usuarios_buscar');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (8, 'Dar de baja usuarios', 'Permite a un usuario dar de baja a otros usuarios.', 'zsp_usuario_dar_baja');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (9, 'Dar de alta usuarios', 'Permite a un usuario dar de alta a otros usuarios que fueron dado de baja.', 'zsp_usuario_dar_alta');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (10, 'Restablecer pass', 'Permite a un usuario restablecer la contraseña de otro usuario. ', 'zsp_usuario_restablecer_pass');
INSERT INTO ZMGestion.Permisos (`IdPermiso`, `Permiso`, `Descripcion`, `Procedimiento`) VALUES (11, 'Modificar pass', 'Permite a un usuario cambiar su contraseña ingresando la contraseña actual.', 'zsp_usuario_modificar_pass');

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

/* Carga inicial PermisosRol Vendedores */
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (2, 11);

/* Carga inicial PermisosRol Fabricantes */
INSERT INTO ZMGestion.PermisosRol (IdRol, IdPermiso) VALUES (3, 11);

/* Carga inicial parametros empresa */
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (1, 'MAXINTPASS', 'Maximo de intentos permitidos ingresando contrasena incorrecta, antes de bloquear al usuario', '3');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (2, 'TIEMPOINTENTOS', 'Tiempo desde el ultimo intento en minutos, si se supera en dicha cantidad el tiempo desde la fecha del ultimo intento, los intentos se vuelven a contar desde cero.', '30');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (3, 'IDROLADMINISTRADOR', 'Identificador del rol de administradores.', '1');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (4, 'IDROLVENDEDOR', 'Identificador del rol de vendedores.', '2');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (5, 'IDROLFABRICANTE', 'Identificador del rol de fabricantes.', '3');

/* -------------------------------- RESTANTE ----------------------------- */

/*Carga inicial TiposDocumento*/
INSERT INTO ZMGestion.TiposDocumento VALUES (1, 'DNI', 'Documento Nacional de Identidad');
INSERT INTO ZMGestion.TiposDocumento VALUES (2, 'Pasaporte', 'Pasaporte');
INSERT INTO ZMGestion.TiposDocumento VALUES (3, 'CUIT', 'Clave Única de Identificación Tributaria');
INSERT INTO ZMGestion.TiposDocumento VALUES (4, 'CUIL', 'Clave Única de Identificación Laboral');


/* Carga inicial Países */
INSERT INTO Paises VALUES ('AR', 'Argentina');


/* Carga inicial Provincias */
INSERT INTO Provincias VALUES (1, 'AR',  'Tucumán');
INSERT INTO Provincias VALUES (2, 'AR', 'Salta');


/* Carga inicial Ciudades */
INSERT INTO Ciudades VALUES (1, 1, 'AR', 'San Miguel de Tucumán');
INSERT INTO Ciudades VALUES (2, 2, 'AR', 'Salta');


/* Carga inicial Domicilios */
INSERT INTO Domicilios VALUES (1, 1, 1, 'AR', NULL,  'Av. Manuel Belgrano 1456', '4000', now(), 'Domicilio de la casa central');
INSERT INTO Domicilios VALUES (2, 1, 1, 'AR', NULL,  'Ildefonso de Muñecas 374', '4000', now(), 'Domicilio sucursal Muñecas');
INSERT INTO Domicilios VALUES (3, 2, 2, 'AR', NULL,  'España 109', '4400', now(), 'Domicilio sucursal Salta');


/* Carga inicial Ubicaciones */
INSERT INTO Ubicaciones VALUES (1,1, 'Casa Central Tucumán', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (2,2, 'Sucursal Muñecas', now(), NULL, '', 'A');
INSERT INTO Ubicaciones VALUES (3,3, 'Sucursal Salta', now(), NULL, '', 'A');
