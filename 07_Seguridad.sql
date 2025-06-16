USE Com2900G04;
GO

--ROLES Y PERMISOS
--Procederemos a crear los roles solicitados
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'JefeTesoreria') CREATE ROLE JefeTesoreria;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AdministrativoCobranza') CREATE ROLE AdministrativoCobranza;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AdministrativoMorosidad') CREATE ROLE AdministrativoMorosidad;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AdministrativoFacturacion') CREATE ROLE AdministrativoFacturacion;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'AdministrativoSocio') CREATE ROLE AdministrativoSocio;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'SociosWeb') CREATE ROLE SociosWeb;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Presidente') CREATE ROLE Presidente;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Vicepresidente') CREATE ROLE Vicepresidente;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Secretario') CREATE ROLE Secretario;
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'Vocales') CREATE ROLE Vocales;

--Continuamos asignando permisos segun los roles

-- Tesoreria puede ver datos de app
GRANT SELECT ON SCHEMA::app TO JefeTesoreria;
GRANT SELECT ON SCHEMA::app TO AdministrativoCobranza;
GRANT SELECT ON SCHEMA::app TO AdministrativoMorosidad;
GRANT SELECT ON SCHEMA::app TO AdministrativoFacturacion;
-- Socios puede ver y modificar informacion, pero solamente de ellos mismos (Esto se filtraria en la app)
GRANT SELECT ON SCHEMA::app TO SociosWeb;
GRANT SELECT, INSERT, UPDATE ON SCHEMA::app TO AdministrativoSocio;
-- Autoridades solo pueden consultar informacion general
GRANT SELECT ON SCHEMA::app TO Vocales;
GRANT SELECT ON SCHEMA::app TO Secretario;
GRANT SELECT ON SCHEMA::app TO Vicepresidente;
GRANT SELECT ON SCHEMA::app TO Presidente;
--Los siguientes roles pueden realizar importaciones
GRANT EXECUTE ON SCHEMA::imp TO JefeTesoreria;
GRANT EXECUTE ON SCHEMA::imp TO Presidente;
GRANT EXECUTE ON SCHEMA::imp TO Vicepresidente;
--Los siguientes roles pueden ejecutar reportes
GRANT EXECUTE ON SCHEMA::rep TO JefeTesoreria;
GRANT EXECUTE ON SCHEMA::rep TO AdministrativoCobranza;
GRANT EXECUTE ON SCHEMA::rep TO AdministrativoMorosidad;
GRANT EXECUTE ON SCHEMA::rep TO AdministrativoFacturacion;
GRANT EXECUTE ON SCHEMA::rep TO Presidente;
GRANT EXECUTE ON SCHEMA::rep TO Vicepresidente;
GRANT EXECUTE ON SCHEMA::rep TO Secretario;
--Los siguientes roles pueden consultar y modificar datos de la organizacion (respecto a empleados)
GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::org TO Presidente
GRANT SELECT, UPDATE, INSERT, DELETE ON SCHEMA::org TO Vicepresidente

--Fin de Roles y Permisos

---ENCRIPTACION DE DATOS DE EMPLEADOS
-- Creamos la clave maestra si no se creo previamente

IF NOT EXISTS (
    SELECT * 
    FROM sys.symmetric_keys 
    WHERE name = '##MS_DatabaseMasterKey##'
)
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'InstitucionDeportivaSolNorte2025';
END;

--Ejecutar solo si aun no existen el certificado ni la clave simetrica:
CREATE CERTIFICATE CertEmpleados
WITH SUBJECT = 'Cifrado para datos personales de los empleados';

CREATE SYMMETRIC KEY EmpleadosSolNorte25
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE CertEmpleados;

--Agregamos las columnas de encriptacion
ALTER TABLE org.Empleado ADD
	DocumentoEncriptado VARBINARY(MAX),
	TelefonoEncriptado VARBINARY(MAX),
	EmailEncriptado VARBINARY(MAX),
	SueldoEncriptado VARBINARY(MAX);

--Creamos un trigger que encripte los datos insertados y que los guarde en las nuevas columnas
GO
CREATE OR ALTER TRIGGER org.EncriptacionEmpleados
ON org.Empleado
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    OPEN SYMMETRIC KEY EmpleadosSolNorte25
    DECRYPTION BY CERTIFICATE CertEmpleados;

    UPDATE e
    SET
        DocumentoEncriptado = EncryptByKey(Key_GUID('EmpleadosSolNorte25'), e.Documento),
        TelefonoEncriptado  = EncryptByKey(Key_GUID('EmpleadosSolNorte25'), e.Telefono),
        EmailEncriptado = EncryptByKey(Key_GUID('EmpleadosSolNorte25'), e.Email),
        SueldoEncriptado  = EncryptByKey(Key_GUID('EmpleadosSolNorte25'), CONVERT(NVARCHAR(100), e.Sueldo)),
        Documento = NULL,
        Telefono = NULL,
        Email = NULL,
        Sueldo = NULL
    FROM org.Empleado e
    INNER JOIN inserted i ON e.IdEmpleado = i.IdEmpleado;

    CLOSE SYMMETRIC KEY EmpleadosSolNorte25;
END;

---Fin de encriptacion de datos de los empleados



