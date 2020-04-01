/* Limpieza de tablas */
DELETE FROM ZMGestion.PermisosRoles;
DELETE FROM ZMGestion.Permisos;
DELETE FROM ZMGestion.Roles;
DELETE FROM ZMGestion.Usuarios;
DELETE FROM ZMGestion.Empresa;

/* Carga inicial roles */
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`) VALUES (1, 'Administradores', 'Rol para los administradores de ZMGestion.');
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`) VALUES (2, 'Vendedores', 'Rol para los vendedores de ZMGestion.');
INSERT INTO ZMGestion.Roles (`IdRol`, `Rol`, `Descripcion`) VALUES (3, 'Fabricantes', 'Rol para los fabricantes de ZMGestion.');

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

/* Carga inicial PermisosRoles Administradores */
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 1);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 2);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 3);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 4);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 5);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 6);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 7);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 8);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 9);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 10);
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (1, 11);

/* Carga inicial PermisosRoles Vendedores */
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (2, 11);

/* Carga inicial PermisosRoles Fabricantes */
INSERT INTO ZMGestion.PermisosRoles (IdRol, IdPermiso) VALUES (3, 11);

/* Carga inicial parametros empresa */
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (1, 'MAXINTPASS', 'Maximo de intentos permitidos ingresando contrasena incorrecta, antes de bloquear al usuario', '3');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (2, 'TIEMPOINTENTOS', 'Tiempo desde el ultimo intento en minutos, si se supera en dicha cantidad el tiempo desde la fecha del ultimo intento, los intentos se vuelven a contar desde cero.', '30');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (3, 'IDROLADMINISTRADOR', 'Identificador del rol de administradores.', '1');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (4, 'IDROLVENDEDOR', 'Identificador del rol de vendedores.', '2');
INSERT INTO ZMGestion.Empresa (`IdParametro`, `Parametro`, `Descripcion`, `Valor`) VALUES (5, 'IDROLFABRICANTE', 'Identificador del rol de fabricantes.', '3');

/* Carga inicial usuarios */
/*INSERT INTO ZMGestion.Usuarios ()*/