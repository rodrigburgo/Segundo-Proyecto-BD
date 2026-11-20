SET search_path=tienda,pg_catalog;
-- Caja: catálogo, existencias y comprobantes de la sesión.
SELECT * FROM inventario ORDER BY nombre;
SELECT * FROM mis_ventas ORDER BY fecha DESC;
SELECT * FROM mis_renglones ORDER BY venta_id,id;
-- Bodega: alternativas de abastecimiento y condiciones ofrecidas.
SELECT p.nombre,pr.nombre proveedor,o.costo,o.condiciones
FROM oferta o JOIN producto p ON p.id=o.producto_id JOIN proveedor pr ON pr.id=o.proveedor_id
ORDER BY p.nombre,o.costo;
SELECT * FROM compras ORDER BY fecha DESC;
SELECT * FROM bajo_minimo ORDER BY existencia-minimo;
SELECT * FROM proximos_vencer ORDER BY vence;
SELECT * FROM movimiento ORDER BY fecha,id;
-- Atención: compras del cliente identificado con documento 10001.
SELECT h.* FROM historial_cliente h JOIN cliente c ON c.id=h.cliente_id
WHERE c.documento='10001' ORDER BY h.fecha,h.detalle_id;
-- Administración: resumen diario y rotación máxima y mínima por unidad comparable.
SELECT fecha::date dia,count(*) transacciones,sum(total) ingreso_bruto FROM ventas GROUP BY fecha::date ORDER BY dia;
WITH posiciones AS (
 SELECT r.*,dense_rank() OVER(PARTITION BY unidad ORDER BY unidades_vendidas DESC) mayor,
 dense_rank() OVER(PARTITION BY unidad ORDER BY unidades_vendidas) menor FROM rotacion_30d r
) SELECT * FROM posiciones WHERE mayor=1 OR menor=1 ORDER BY unidad,mayor,nombre;
SELECT c.nombre,count(v.id) ventas,sum(v.total) valor FROM cliente c JOIN ventas v ON v.cliente_id=c.id GROUP BY c.id ORDER BY valor DESC;
-- Bodega: lotes vencidos con saldo, pendientes de baja por VENCIMIENTO.
SELECT p.nombre,l.codigo,l.saldo,l.vence FROM lote l JOIN producto p ON p.id=l.producto_id WHERE l.saldo>0 AND l.vence<current_date ORDER BY l.vence;
-- Bodega: lotes por producto con su saldo y estado de vigencia.
SELECT p.nombre,l.codigo,l.ingreso,l.vence,l.saldo,
 CASE WHEN l.vence IS NULL THEN 'SIN VENCIMIENTO' WHEN l.vence<current_date THEN 'VENCIDO' WHEN l.vence<=current_date+30 THEN 'PROXIMO A VENCER' ELSE 'VIGENTE' END vigencia
FROM lote l JOIN producto p ON p.id=l.producto_id ORDER BY p.nombre,l.vence NULLS LAST;
-- Bodega: compras pendientes de recepción y quién recibió las demás.
SELECT c.id,c.fecha,pr.nombre proveedor,c.estado,c.total,er.nombre recibida_por,c.fecha_recepcion
FROM compras c JOIN proveedor pr ON pr.id=c.proveedor_id LEFT JOIN empleado er ON er.id=c.receptor_id ORDER BY c.id;
-- Atención: solicitudes de posventa con su renglón y su reingreso, si existe.
SELECT s.id,s.fecha,s.tipo,p.nombre,s.cantidad,s.motivo,m.id movimiento_id
FROM solicitud s JOIN detalle_venta d ON d.id=s.detalle_id JOIN lote l ON l.id=d.lote_id JOIN producto p ON p.id=l.producto_id LEFT JOIN movimiento m ON m.solicitud_id=s.id ORDER BY s.id;
-- Administración: ventas consolidadas por producto (cantidad e ingreso).
SELECT p.nombre,p.unidad,sum(d.cantidad) unidades,sum(d.subtotal) ingreso
FROM detalle_venta d JOIN lote l ON l.id=d.lote_id JOIN producto p ON p.id=l.producto_id GROUP BY p.id ORDER BY ingreso DESC;
-- Administración: ventas por empleado y forma de pago.
SELECT e.nombre empleado,v.pago,count(*) transacciones,sum(v.total) valor FROM ventas v JOIN empleado e ON e.id=v.empleado_id GROUP BY e.nombre,v.pago ORDER BY valor DESC;
-- Administración: compras por proveedor.
SELECT pr.nombre proveedor,count(c.id) compras,coalesce(sum(c.total),0) valor FROM proveedor pr LEFT JOIN compras c ON c.proveedor_id=pr.id GROUP BY pr.id ORDER BY valor DESC;
-- Administración: valor del inventario a costo de referencia y margen unitario de catálogo.
SELECT p.nombre,i.existencia,p.precio_compra,p.precio_venta,p.precio_venta-p.precio_compra margen_unitario,i.existencia*p.precio_compra valor_inventario
FROM inventario i JOIN producto p ON p.id=i.id ORDER BY valor_inventario DESC;
-- Conciliación independiente por lote. Una ejecución correcta devuelve cero filas.
WITH fuentes AS (
 SELECT lote_id,cantidad delta FROM detalle_compra d JOIN compra c ON c.id=d.compra_id WHERE estado='RECIBIDA'
 UNION ALL SELECT lote_id,-cantidad FROM detalle_venta
 UNION ALL SELECT lote_id,CASE WHEN tipo IN ('DEVOLUCION_CLIENTE','AJUSTE_ENTRADA') THEN cantidad ELSE -cantidad END FROM movimiento
) SELECT l.id,l.saldo,coalesce(sum(f.delta),0) reconstruido FROM lote l LEFT JOIN fuentes f ON f.lote_id=l.id GROUP BY l.id HAVING l.saldo<>coalesce(sum(f.delta),0);
