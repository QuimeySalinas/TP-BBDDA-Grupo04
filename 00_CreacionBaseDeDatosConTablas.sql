--Creamos nuestra base de datos
CREATE DATABASE Com2900G04;
GO
--Seleccionamos nuestra base de datos
USE Com2900G04;

GO
--Generamos esquemas necesarios para un futuro
CREATE SCHEMA ops  --Esquema para los objetos relacionados con operaciones internas de la app.
GO
CREATE SCHEMA rep  --Esquema para los objetos relacionados con reportes.
GO
CREATE SCHEMA imp  --Esquema para los objetos relacionados con importacion de archivos.
GO
CREATE SCHEMA app  --Esquema para los objetos relacionados directamente con la aplicacion.
GO

--A continuacion, procederemos con la creacion de las tablas:
