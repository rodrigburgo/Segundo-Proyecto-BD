-- Reinicia el entorno de práctica: permite ejecutar todo el proyecto varias veces.
-- Requiere que no haya otras conexiones abiertas a la base supermercado.
DROP DATABASE IF EXISTS supermercado;
DROP ROLE IF EXISTS sm_caja, sm_bodega, sm_administracion, sm_atencion;
CREATE DATABASE supermercado;
ALTER DATABASE supermercado SET timezone TO 'America/Bogota';
