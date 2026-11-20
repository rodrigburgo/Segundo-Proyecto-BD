-- Perfiles de acceso: un rol por área. Cada empleado recibe el rol de su área.
SET search_path=tienda,pg_catalog;

CREATE ROLE sm_caja;
CREATE ROLE sm_bodega;
CREATE ROLE sm_administracion;
CREATE ROLE sm_atencion;

GRANT USAGE ON SCHEMA tienda TO sm_caja, sm_bodega, sm_administracion, sm_atencion;

-- Las funciones nacen ejecutables por todos; se quita ese permiso y se da solo a quien corresponde.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA tienda FROM PUBLIC;

-- CAJA: vende, consulta el catálogo, sus propias ventas y maneja clientes.
GRANT SELECT ON inventario, lotes_caja, mis_ventas, mis_renglones TO sm_caja;
GRANT SELECT, INSERT, UPDATE ON cliente TO sm_caja;
GRANT EXECUTE ON FUNCTION registrar_venta(integer,text,jsonb) TO sm_caja;

-- BODEGA: consulta productos y proveedores, compra, recibe, registra lotes y movimientos.
GRANT SELECT ON inventario, producto, proveedor, oferta, compras, detalle_compra, lote, movimiento, bajo_minimo, proximos_vencer TO sm_bodega;
GRANT INSERT (producto_id, codigo, vence) ON lote TO sm_bodega;
GRANT EXECUTE ON FUNCTION registrar_compra(integer,jsonb), recibir_compra(integer), registrar_movimiento(integer,text,numeric,text,integer) TO sm_bodega;

-- ADMINISTRACIÓN: consulta todo y mantiene los datos maestros.
GRANT SELECT ON ALL TABLES IN SCHEMA tienda TO sm_administracion;
GRANT INSERT, UPDATE, DELETE ON empleado, area, categoria, producto, proveedor, oferta TO sm_administracion;

-- ATENCIÓN AL CLIENTE: consulta disponibilidad e historial de clientes, maneja clientes y registra solicitudes.
GRANT SELECT ON inventario, historial_cliente TO sm_atencion;
GRANT SELECT, INSERT, UPDATE ON cliente TO sm_atencion;
GRANT EXECUTE ON FUNCTION registrar_solicitud(integer,text,numeric,text) TO sm_atencion;

-- Para probar: una cuenta por empleado (el nombre debe coincidir con empleado.usuario).
-- CREATE ROLE demo_ana LOGIN PASSWORD '1234';  GRANT sm_caja TO demo_ana;
-- CREATE ROLE demo_luis LOGIN PASSWORD '1234'; GRANT sm_bodega TO demo_luis;
-- CREATE ROLE demo_luz LOGIN PASSWORD '1234';  GRANT sm_administracion TO demo_luz;
-- CREATE ROLE demo_eva LOGIN PASSWORD '1234';  GRANT sm_atencion TO demo_eva;
