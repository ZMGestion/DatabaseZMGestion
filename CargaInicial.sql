/* Limpieza de tablas*/
DELETE FROM ZMGestion.Permisos;

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