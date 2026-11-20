# Base de datos de una tienda de víveres

## Instalación

Requisitos: PostgreSQL 15 o superior, cliente psql y una cuenta instaladora con permisos para crear bases y roles. Abrir una terminal dentro de la carpeta Supermercado descomprimida. Ejecutar en una instalación de práctica con la base supermercado y los cuatro roles sm_* disponibles para creación. La carga supone tablas nuevas y secuencias que comienzan en 1. 00_base.sql elimina y recrea la base y los cuatro roles, de modo que todo el proceso se puede repetir; para eso no debe haber otras conexiones abiertas a supermercado.

```sh
psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f 00_base.sql
psql -U postgres -d supermercado -v ON_ERROR_STOP=1 -f 01_tablas.sql -f 02_operaciones.sql -f 03_perfiles.sql -f 04_carga.sql
psql -U postgres -d supermercado -v ON_ERROR_STOP=1 -f 05_consultas.sql
```

El primer archivo recrea la base y los roles y configura la zona horaria de Bogotá. El segundo crea el esquema tienda. El cargador usa el comando de psql de lectura local de CSV. Ejecutar desde el directorio indicado permite resolver esas rutas.

## Perfiles y prueba de acceso

| Área | Rol | Operaciones |
|---|---|---|
| Caja | sm_caja | Consultar catálogo y lotes vendibles, registrar ventas, consultar comprobantes propios, crear o actualizar clientes. |
| Bodega | sm_bodega | Consultar ofertas, crear lotes y compras, recibir mercancía, ajustar inventario, revisar saldos, mínimos y vencimientos. |
| Administración | sm_administracion | Mantener maestros, precios, acuerdos y empleados. Consultar todas las tablas y vistas. Las claves foráneas protegen a empleados con historial frente a una eliminación. |
| Atención al cliente | sm_atencion | Mantener clientes, consultar disponibilidad e historial identificado y registrar solicitudes o devoluciones. |

El administrador técnico crea una cuenta LOGIN por empleado y le concede el rol correspondiente a su área. El campo empleado.usuario debe coincidir con esa cuenta. Para probar con la cajera de la carga, el instalador puede ejecutar lo siguiente desde psql:

```sql
CREATE ROLE demo_ana LOGIN;
GRANT sm_caja TO demo_ana;
\password demo_ana
```

Conectarse como demo_ana mediante el método de autenticación habilitado en el servidor. El filtro utiliza session_user y requiere iniciar sesión con esa cuenta. Para probar bodega se puede repetir el procedimiento con demo_luis y sm_bodega; para atención con demo_eva y sm_atencion; para administración con demo_luz y sm_administracion. Al trasladar un empleado, el administrador técnico debe revocar el rol anterior y asignar el nuevo.

## Ejemplo de venta en caja

```sql
SET search_path=tienda,pg_catalog;
SELECT * FROM lotes_caja ORDER BY vence NULLS LAST;
BEGIN;
SELECT registrar_venta(NULL,'EFECTIVO','[{"lote":1,"cantidad":1}]');
SELECT * FROM mis_ventas ORDER BY id DESC;
ROLLBACK;
```

ROLLBACK permite practicar sin modificar los saldos del ejemplo. Las secciones de 05_consultas.sql indican qué consultas corresponden a cada perfil. El propietario puede ejecutar el archivo completo. Las vistas de ventas propias solo muestran resultados cuando la cuenta corresponde a un empleado que ha registrado ventas.

## Supuestos del negocio

- Una sede, una bodega lógica, moneda COP, una forma de pago por venta. La tienda registra los precios finales. Cada renglón conserva el precio o costo aplicado y su subtotal redondeado a centavos.
- Todos los artículos usan una partida de inventario. Para artículos sin lote comercial se asigna un código interno. Se exige vencimiento a los perecederos. Una venta admite varios lotes del mismo producto. Se eligen explícitamente en caja.
- El saldo representa unidades físicas, incluidas las vencidas pendientes de baja. La caja solo ofrece partidas vigentes con saldo y productos activos. El estado comercial derivado se consulta en inventario.
- Se registra el lote antes de crear la compra. La compra queda pendiente y su recepción íntegra incrementa las existencias una sola vez. El empleado de la compra identifica a quien registró el documento; al recibirla se guardan además la fecha y el empleado receptor. El costo de catálogo es de referencia; el costo de compra es el del acuerdo con el proveedor (si se omite se toma de la oferta y si se informa debe coincidir con ella).
- En caja, el cliente es opcional. Un error en cualquier renglón revierte la venta completa. Las operaciones contabilizadas se conservan y las correcciones físicas se registran con un movimiento justificado.
- Atención registra una solicitud por renglón. Bodega verifica el artículo y registra el reingreso completo de esa solicitud si procede. La suma de devoluciones solicitadas por renglón queda limitada a la cantidad vendida. Un artículo devuelto que deba desecharse requiere una baja posterior. La gestión de reembolsos monetarios queda fuera del alcance.
- Para análisis, rotación significa cantidad bruta vendida en 30 días, incluyendo referencias con cero ventas; la clasificación compara productos con la misma unidad. La vista de productos bajo el mínimo excluye los descontinuados. “Próximo a vencer” cubre desde hoy hasta dentro de 30 días, ambos inclusive.
- Los datos son ficticios. El CSV de lotes expresa fechas en días relativos a la carga para que las alertas se puedan demostrar cualquier día. El CSV de operaciones se procesa por orden y reproduce las mismas funciones utilizadas por las áreas.

## Resultados esperados después de cargar

| Producto | Cálculo de unidades físicas | Saldo |
|---|---|---:|
| Leche entera | 10 + 5 recibidas − 2 vendidas + 1 devuelta | 14 |
| Arroz | 8 recibidas − 1 vendida − 1 dañada | 6 |
| Tomate | 2,5 kg recibidos − 0,5 kg vendidos | 2 kg |
| Jabón | Sin movimientos, descontinuado | 0 |

La venta identificada suma $10.900 y la anónima $1.900. La tercera compra, de cuatro bolsas de arroz por $7.200, permanece pendiente. La consulta de conciliación debe devolver cero filas.

## Archivos de diseño

Modelo_relacional.md enumera las relaciones, claves y cardinalidades. Diagrama_relacional.pdf muestra las tablas con sus claves y Diagrama_ER.pdf el modelo entidad-relación. Diccionario.md detalla los campos, tipos, restricciones y valores calculados.
