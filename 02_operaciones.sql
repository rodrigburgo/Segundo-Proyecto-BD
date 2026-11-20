BEGIN;
SET search_path=tienda,pg_catalog;
CREATE VIEW inventario AS
SELECT p.id,p.nombre,p.unidad,p.precio_venta,p.minimo,coalesce(sum(l.saldo),0) existencia,
 CASE WHEN p.descontinuado THEN 'DESCONTINUADO' WHEN coalesce(sum(l.saldo),0)=0 THEN 'AGOTADO' ELSE 'DISPONIBLE' END estado
FROM producto p LEFT JOIN lote l ON l.producto_id=p.id GROUP BY p.id;
CREATE VIEW compras AS SELECT c.*,coalesce((SELECT sum(subtotal) FROM detalle_compra WHERE compra_id=c.id),0) total FROM compra c;
CREATE VIEW ventas AS SELECT v.*,coalesce((SELECT sum(subtotal) FROM detalle_venta WHERE venta_id=v.id),0) total FROM venta v;
CREATE VIEW mis_ventas AS SELECT v.* FROM ventas v JOIN empleado e ON e.id=v.empleado_id WHERE e.usuario=session_user;
CREATE VIEW mis_renglones AS SELECT d.* FROM detalle_venta d JOIN mis_ventas v ON v.id=d.venta_id;
CREATE VIEW historial_cliente AS SELECT v.cliente_id,v.id venta_id,v.fecha,d.id detalle_id,p.nombre,d.cantidad,d.unitario,d.subtotal
FROM venta v JOIN detalle_venta d ON d.venta_id=v.id JOIN lote l ON l.id=d.lote_id JOIN producto p ON p.id=l.producto_id WHERE v.cliente_id IS NOT NULL;
CREATE VIEW rotacion_30d AS SELECT p.id,p.nombre,p.unidad,coalesce(sum(d.cantidad) FILTER (WHERE v.fecha BETWEEN now()-interval '30 days' AND now()),0) unidades_vendidas
FROM producto p LEFT JOIN lote l ON l.producto_id=p.id LEFT JOIN detalle_venta d ON d.lote_id=l.id LEFT JOIN venta v ON v.id=d.venta_id GROUP BY p.id;
CREATE VIEW bajo_minimo AS SELECT * FROM inventario WHERE existencia<minimo AND estado<>'DESCONTINUADO';
CREATE VIEW proximos_vencer AS SELECT p.nombre,l.codigo,l.saldo,l.vence FROM lote l JOIN producto p ON p.id=l.producto_id WHERE l.saldo>0 AND l.vence BETWEEN current_date AND current_date+30;
CREATE VIEW lotes_caja AS SELECT l.id,l.producto_id,l.codigo,l.vence,l.saldo FROM lote l JOIN producto p ON p.id=l.producto_id WHERE l.saldo>0 AND NOT p.descontinuado AND (l.vence IS NULL OR l.vence>=current_date);

CREATE FUNCTION validar_lote() RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,tienda,pg_temp AS $$
BEGIN
 IF NEW.vence IS NULL AND (SELECT perecedero FROM producto WHERE id=NEW.producto_id) THEN RAISE EXCEPTION 'Se requiere vencimiento'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER validar BEFORE INSERT OR UPDATE OF vence,producto_id ON lote FOR EACH ROW EXECUTE FUNCTION validar_lote();

CREATE FUNCTION responsable() RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,tienda,pg_temp AS $$
 SELECT id FROM empleado WHERE usuario=session_user
$$;
-- Cada llamada crea toda la operación en la transacción del usuario.
CREATE FUNCTION registrar_compra(prov integer, lineas jsonb) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,tienda,pg_temp AS $$
DECLARE doc integer; r record; acuerdo numeric;
BEGIN
 IF coalesce(jsonb_array_length(lineas),0)=0 THEN RAISE EXCEPTION 'Compra vacía'; END IF;
 INSERT INTO compra(proveedor_id,empleado_id) VALUES(prov,responsable()) RETURNING id INTO doc;
 FOR r IN SELECT * FROM jsonb_to_recordset(lineas) AS x(lote integer,cantidad numeric,costo numeric) LOOP
 SELECT o.costo INTO acuerdo FROM lote l JOIN oferta o ON o.producto_id=l.producto_id WHERE l.id=r.lote AND o.proveedor_id=prov;
 IF NOT FOUND THEN RAISE EXCEPTION 'Producto sin acuerdo con el proveedor'; END IF;
 -- El costo omitido toma el acuerdo vigente; si se indica, debe coincidir con él.
 IF r.costo IS NOT NULL AND r.costo<>acuerdo THEN RAISE EXCEPTION 'El costo % no coincide con el acuerdo (%) del lote %',r.costo,acuerdo,r.lote; END IF;
 INSERT INTO detalle_compra(compra_id,lote_id,cantidad,unitario) VALUES(doc,r.lote,r.cantidad,acuerdo);
 END LOOP;
 RETURN doc;
END $$;

CREATE FUNCTION recibir_compra(doc integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,tienda,pg_temp AS $$
DECLARE r record;
BEGIN
 UPDATE compra SET estado='RECIBIDA',fecha_recepcion=now(),receptor_id=responsable() WHERE id=doc AND estado='PENDIENTE';
 IF NOT FOUND THEN RAISE EXCEPTION 'Compra inexistente o ya recibida'; END IF;
 FOR r IN SELECT * FROM detalle_compra WHERE compra_id=doc ORDER BY lote_id LOOP
 UPDATE lote SET saldo=saldo+r.cantidad WHERE id=r.lote_id;
 END LOOP;
END $$;
CREATE FUNCTION registrar_venta(cliente integer, medio text, lineas jsonb) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,tienda,pg_temp AS $$
DECLARE doc integer; r record; precio numeric;
BEGIN
 IF coalesce(jsonb_array_length(lineas),0)=0 THEN RAISE EXCEPTION 'Venta vacía'; END IF;
 INSERT INTO venta(cliente_id,empleado_id,pago) VALUES(cliente,responsable(),medio) RETURNING id INTO doc;
 FOR r IN SELECT * FROM jsonb_to_recordset(lineas) AS x(lote integer,cantidad numeric(14,3)) ORDER BY lote LOOP
 UPDATE lote l SET saldo=saldo-r.cantidad FROM producto p WHERE l.id=r.lote AND p.id=l.producto_id AND NOT p.descontinuado AND (l.vence IS NULL OR l.vence>=current_date) AND l.saldo>=r.cantidad RETURNING p.precio_venta INTO precio;
 IF NOT FOUND THEN RAISE EXCEPTION 'Lote % sin disponibilidad para la venta',r.lote; END IF;
 INSERT INTO detalle_venta(venta_id,lote_id,cantidad,unitario) VALUES(doc,r.lote,r.cantidad,precio);
 END LOOP;
 RETURN doc;
END $$;
CREATE FUNCTION registrar_solicitud(det integer, clase text, cant numeric, razon text) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,tienda,pg_temp AS $$
DECLARE vendida numeric; nueva integer;
BEGIN
 SELECT cantidad INTO STRICT vendida FROM detalle_venta WHERE id=det FOR UPDATE;
 IF clase='DEVOLUCION' AND cant+(SELECT coalesce(sum(cantidad),0) FROM solicitud WHERE detalle_id=det AND tipo=clase)>vendida THEN RAISE EXCEPTION 'La devolución supera lo vendido'; END IF;
 INSERT INTO solicitud(empleado_id,detalle_id,tipo,cantidad,motivo) VALUES(responsable(),det,clase,cant,razon) RETURNING id INTO nueva;
 RETURN nueva;
END $$;
CREATE FUNCTION registrar_movimiento(partida integer, clase text, cant numeric, razon text, solicitud_ref integer DEFAULT NULL) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,tienda,pg_temp AS $$
DECLARE nuevo integer;
BEGIN
 IF clase='VENCIMIENTO' AND NOT EXISTS (SELECT 1 FROM lote WHERE id=partida AND vence<current_date) THEN RAISE EXCEPTION 'El lote % aún no está vencido',partida; END IF;
 IF clase='DEVOLUCION_CLIENTE' AND NOT EXISTS (SELECT 1 FROM solicitud s JOIN detalle_venta d ON d.id=s.detalle_id WHERE s.id=solicitud_ref AND s.tipo='DEVOLUCION' AND d.lote_id=partida AND s.cantidad=cant) THEN RAISE EXCEPTION 'Solicitud incompatible'; END IF;
 INSERT INTO movimiento(empleado_id,lote_id,tipo,cantidad,motivo,solicitud_id) VALUES(responsable(),partida,clase,cant,razon,solicitud_ref) RETURNING id INTO nuevo;
 UPDATE lote SET saldo=saldo+CASE WHEN clase IN ('AJUSTE_ENTRADA','DEVOLUCION_CLIENTE') THEN cant ELSE -cant END WHERE id=partida;
 RETURN nuevo;
END $$;
COMMIT;
