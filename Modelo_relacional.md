# Modelo relacional · Supermercado

PK identifica cada fila. FK indica la relación con la clave primaria de otra tabla.

- **area** (id PK, nombre)
- **categoria** (id PK, nombre)
- **empleado** (id PK, nombre, documento, direccion, telefono, correo, cargo, area_id FK → area, usuario)
- **cliente** (id PK, nombre, documento, direccion, telefono, correo)
- **proveedor** (id PK, nombre, nit, direccion, telefono, correo, contacto)
- **producto** (id PK, nombre, descripcion, categoria_id FK → categoria, marca, unidad, precio_compra, precio_venta, minimo, perecedero, descontinuado)
- **oferta** (proveedor_id FK → proveedor, producto_id FK → producto, costo, condiciones) · PK (proveedor_id, producto_id)
- **lote** (id PK, producto_id FK → producto, codigo, ingreso, vence, saldo)
- **compra** (id PK, fecha, empleado_id FK → empleado, proveedor_id FK → proveedor, estado, fecha_recepcion, receptor_id FK → empleado)
- **venta** (id PK, fecha, empleado_id FK → empleado, cliente_id FK → cliente, pago)
- **detalle_compra** (id PK, compra_id FK → compra, lote_id FK → lote, cantidad, unitario, subtotal)
- **detalle_venta** (id PK, venta_id FK → venta, lote_id FK → lote, cantidad, unitario, subtotal)
- **solicitud** (id PK, fecha, empleado_id FK → empleado, detalle_id FK → detalle_venta, tipo, cantidad, motivo)
- **movimiento** (id PK, fecha, empleado_id FK → empleado, lote_id FK → lote, cantidad, tipo, motivo, solicitud_id FK → solicitud)

## Cardinalidades y decisiones
Cada área agrupa empleados y cada categoría agrupa productos. Oferta resuelve la relación N:M entre proveedores y productos. Cada compra pertenece a un proveedor, la registra un empleado y la recibe, una vez, otro o el mismo empleado; cada venta puede identificar a un cliente. Cada documento tiene uno o más renglones. Un lote pertenece a un producto y puede aparecer en muchas operaciones. Un renglón vendido admite varias solicitudes y cada solicitud admite como máximo un movimiento de devolución. El inventario inicial es cero. Las entradas, salidas y ajustes se contabilizan en la unidad base del producto.
