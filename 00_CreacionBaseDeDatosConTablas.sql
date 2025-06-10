--Creamos nuestra base de datos
IF NOT EXISTS ( SELECT name FROM master.dbo.sysdatabases WHERE name = 'Com2900G04')
BEGIN
CREATE DATABASE Com2900G04
COLLATE Latin1_General_CI_AI;
END
GO

--Seleccionamos nuestra base de datos
USE Com2900G04;
GO

--Generamos esquemas necesarios para un futuro
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'ops')
BEGIN
EXEC('CREATE SCHEMA ops') --Esquema para los objetos relacionados con operaciones internas de la app.
END
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'rep')
BEGIN
EXEC('CREATE SCHEMA rep') --Esquema para los objetos relacionados con reportes.
END
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'imp')
BEGIN
EXEC('CREATE SCHEMA imp') --Esquema para los objetos relacionados con importacion de archivos.
END
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'app')
BEGIN
EXEC('CREATE SCHEMA app') --Esquema para los objetos relacionados directamente con la aplicacion.
END
GO

--A continuacion, procederemos con la creacion de las tablas:

CREATE TABLE app.CategoriaSocio(
	idCategoriaSocio INT IDENTITY(1,1) PRIMARY KEY,
	nombre varchar(50)
)

CREATE TABLE app.CostoMembresia(
	idCostoMembresia INT IDENTITY(1,1) PRIMARY KEY,
	Monto DECIMAL(10,2) not null check(Monto>0),
	fecha DATE,
	idCategoriaSocio INT,
	FOREIGN KEY(idCategoriaSocio) REFERENCES app.categoriaSocio(idCategoriaSocio)
)

CREATE TABLE app.GrupoFamiliar (
    IdGrupoFamiliar INT IDENTITY(1,1) PRIMARY KEY,
    FechaCreacion DATE,
    Estado VARCHAR(20),
    NombreFamilia VARCHAR(50),
	NumeroDeSocioResponsable CHAR(7)
);

CREATE TABLE app.Inscripcion(
	IdInscripcion INT IDENTITY(1,1) PRIMARY KEY,
	TipoInscripcion VARCHAR(20),
	Fecha DATE,
	Estado VARCHAR(20)
);

CREATE TABLE app.ObraSocial (
    IdObraSocial INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(50),
    Tipo VARCHAR(20)
);

CREATE TABLE app.Socio (
    NumeroDeSocio CHAR(7) primary key,
    Documento VARCHAR(15) NOT NULL,
    Saldo DECIMAL(10,2),
    Estado VARCHAR(20),
    Telefono VARCHAR(20),
    Nombre VARCHAR(50) NOT NULL,
    Apellido VARCHAR(50) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    EmailPersonal VARCHAR(100),
    HospitalCercano VARCHAR(100),
    NumeroObraSocial VARCHAR(50),
    IdCategoriaSocio INT,
    IdUsuario INT,
    IdGrupoFamiliar INT,
	--IdGrupoFamiliarResp INT, --Si es responsable de un grupo familiar
    IdDescuento INT,
	IdObraSocial INT,
    FOREIGN KEY (IdCategoriaSocio) REFERENCES app.CategoriaSocio(IdCategoriaSocio),
    FOREIGN KEY (IdGrupoFamiliar) REFERENCES app.GrupoFamiliar(IdGrupoFamiliar),
	--FOREIGN KEY (IdGrupoFamiliarResp) REFERENCES app.GrupoFamiliar(IdGrupoFamiliar),
	FOREIGN KEY (IdObraSocial) REFERENCES app.ObraSocial(IdObraSocial) 
);

ALTER TABLE app.GrupoFamiliar
ADD CONSTRAINT FK_GrupoFamiliarSocioResponsable
FOREIGN KEY (NumeroDeSocioResponsable) REFERENCES app.Socio(NumeroDeSocio);

CREATE TABLE app.Invita(
	FechaInvitacion Date,
    NumeroDeSocio  CHAR(7),
	NumeroSocioInvitado  CHAR(7),
	PRIMARY KEY(NumeroDeSocio,NumeroSocioInvitado,FechaInvitacion),
	FOREIGN KEY(NumeroDeSocio) REFERENCES app.Socio(NumeroDeSocio),
	FOREIGN KEY(NumeroSocioInvitado) REFERENCES app.Socio(NumeroDeSocio)
);

CREATE TABLE app.Usuario (
    IdUsuario INT IDENTITY(1,1) PRIMARY KEY,
    FechaVigenciaContrasena DATE,
    Rol VARCHAR(20),
    Usuario VARCHAR(50),
    Contrasena VARCHAR(50),
	NumeroDeSocio CHAR(7),
	FOREIGN KEY (NumeroDeSocio) REFERENCES app.Socio(NumeroDeSocio)
);



CREATE TABLE app.Descuento (
    IdDescuento INT IDENTITY(1,1) PRIMARY KEY,
    Tipo VARCHAR(50),
    Porcentaje DECIMAL(5,2),
    FechaVigencia DATE,
	NumeroDeSocio CHAR(7),
	FOREIGN KEY (NumeroDeSocio) REFERENCES app.Socio(NumeroDeSocio)
);

CREATE TABLE app.ActividadDeportiva (
    IdActividad INT IDENTITY(1,1) PRIMARY KEY,
    ActividadExtra BIT, --Indica si es una actividad extra o no
    Nombre VARCHAR(50), 
	FechaVigencia DATE,
    Monto DECIMAL(10,2) not null check(Monto>0)
);