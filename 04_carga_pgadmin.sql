-- Carga de datos de ejemplo para pgAdmin (sin \copy). Ejecutar DESPUES de 01, 02 y 03.
BEGIN;
SET search_path=tienda,pg_catalog;
INSERT INTO area(nombre) VALUES
('Caja'),
('Bodega'),
('Administración'),
('Atención al cliente');
INSERT INTO categoria(nombre) VALUES
('Lácteos'),
('Frutas y verduras'),
('Bebidas'),
('Aseo'),
('Granos'),
('Carnes');
INSERT INTO empleado(nombre,documento,direccion,telefono,correo,cargo,area_id,usuario) VALUES
('Ana Pérez','9001','Calle 1','3000000001','demo_ana@example.org','Cajera',1,'demo_ana'),
('Luis Ríos','9002','Calle 2','3000000002','demo_luis@example.org','Auxiliar',2,'demo_luis'),
('Luz Díaz','9003','Calle 3','3000000003','demo_luz@example.org','Administradora',3,'demo_luz'),
('Eva León','9004','Calle 4','3000000004','demo_eva@example.org','Asesora',4,'demo_eva');
INSERT INTO cliente(nombre,documento,direccion,telefono,correo) VALUES
('Juan Mora','10001','Calle 8','3000000020','juan@example.org'),
('Sara Gil','10002','Calle 9','3000000021','sara@example.org');
INSERT INTO proveedor(nombre,nit,direccion,telefono,correo,contacto) VALUES
('Abastos Demo','900001-1','Bodega 1','6010000001','abastos@example.org','Rosa Sol'),
('Campo Demo','900002-2','Bodega 2','6010000002','campo@example.org','José Paz');
INSERT INTO producto(nombre,descripcion,categoria_id,marca,unidad,precio_compra,precio_venta,minimo,perecedero,descontinuado) VALUES
('Leche entera','Bolsa de un litro',1,'Prado','unidad',3200,4200,5,'True','False'),
('Arroz','Bolsa de 500 g',5,'Campo','unidad',1800,2500,4,'False','False'),
('Tomate','Tomate a granel',2,'Huerta','kg',2200,3800,3,'True','False'),
('Jabón','Barra de 250 g',4,'Limpio','unidad',1600,2200,2,'False','True');
INSERT INTO oferta(proveedor_id,producto_id,costo,condiciones) VALUES
(1,1,3200,'Pago a 15 días'),
(2,1,3100,'Pago de contado'),
(1,2,1800,'Entrega semanal'),
(2,3,2200,'Entrega diaria');
CREATE TEMP TABLE lotes_csv(producto integer,codigo text,dias_ingreso integer,dias_vencimiento integer);
INSERT INTO lotes_csv(producto,codigo,dias_ingreso,dias_vencimiento) VALUES
(1,'LE-A',-2,5),
(1,'LE-B',-1,25),
(2,'AR-A',-2,NULL),
(3,'TO-A',-1,4);
INSERT INTO lote(producto_id,codigo,ingreso,vence) SELECT producto,codigo,current_date+dias_ingreso,current_date+dias_vencimiento FROM lotes_csv ORDER BY producto,codigo;
CREATE TEMP TABLE ops(orden integer PRIMARY KEY,empleado integer,accion text,referencia integer,clase text,cantidad numeric,motivo text,solicitud integer,lineas jsonb);
INSERT INTO ops(orden,empleado,accion,referencia,clase,cantidad,motivo,solicitud,lineas) VALUES
(1,2,'compra',1,NULL,NULL,NULL,NULL,'[{"lote": 1, "cantidad": 10, "costo": 3200}, {"lote": 3, "cantidad": 8, "costo": 1800}]'),
(2,2,'recibir',1,NULL,NULL,NULL,NULL,NULL),
(3,2,'compra',2,NULL,NULL,NULL,NULL,'[{"lote": 2, "cantidad": 5, "costo": 3100}, {"lote": 4, "cantidad": 2.5, "costo": 2200}]'),
(4,2,'recibir',2,NULL,NULL,NULL,NULL,NULL),
(5,1,'venta',1,'TARJETA',NULL,NULL,NULL,'[{"lote": 1, "cantidad": 2}, {"lote": 3, "cantidad": 1}]'),
(6,1,'venta',NULL,'EFECTIVO',NULL,NULL,NULL,'[{"lote": 4, "cantidad": 0.5}]'),
(7,4,'solicitud',1,'DEVOLUCION',1,'Envase cerrado recibido',NULL,NULL),
(8,2,'movimiento',1,'DEVOLUCION_CLIENTE',1,'Reintegro autorizado',1,NULL),
(9,2,'movimiento',3,'DANO',1,'Bolsa rota',NULL,NULL),
(10,2,'compra',1,NULL,NULL,NULL,NULL,'[{"lote": 3, "cantidad": 4, "costo": 1800}]');
-- La carga, ejecutada por el propietario, asocia temporalmente su sesión con el empleado del ejemplo.
DO $$
DECLARE r record; original name;
BEGIN
 FOR r IN SELECT * FROM ops ORDER BY orden LOOP
 SELECT usuario INTO STRICT original FROM empleado WHERE id=r.empleado;
 UPDATE empleado SET usuario=session_user WHERE id=r.empleado;
 CASE r.accion
 WHEN 'compra' THEN PERFORM registrar_compra(r.referencia,r.lineas);
 WHEN 'recibir' THEN PERFORM recibir_compra(r.referencia);
 WHEN 'venta' THEN PERFORM registrar_venta(r.referencia,r.clase,r.lineas);
 WHEN 'solicitud' THEN PERFORM registrar_solicitud(r.referencia,r.clase,r.cantidad,r.motivo);
 WHEN 'movimiento' THEN PERFORM registrar_movimiento(r.referencia,r.clase,r.cantidad,r.motivo,r.solicitud);
 END CASE;
 UPDATE empleado SET usuario=original WHERE id=r.empleado;
 END LOOP;
END $$;
COMMIT;

