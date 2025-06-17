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

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'org')
BEGIN
EXEC('CREATE SCHEMA org') --Esquema para los objetos relacionados con la organizacion.
END
GO

--A continuacion, procederemos con la creacion de las tablas:
CREATE TABLE app.DebitoAutomatico (
	idDebitoAutomatico INT IDENTITY(1,1) PRIMARY KEY,
	FechaVigencia DATE,
	FechaFin DATE,
	Tipo VARCHAR(20),
	NumeroTarjeta INT
);

CREATE TABLE app.CategoriaSocio(
	idCategoriaSocio INT IDENTITY(1,1) PRIMARY KEY,
	nombre varchar(50)
);

CREATE TABLE app.GrupoFamiliar (
    IdGrupoFamiliar INT IDENTITY(1,1) PRIMARY KEY,
    FechaCreacion DATE,
    Estado VARCHAR(20),
    NombreFamilia VARCHAR(50),
	NumeroDeSocioResponsable CHAR(7)
);

CREATE TABLE app.ObraSocial (
    IdObraSocial INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(50),
    FechaAlta DATE,
    FechaBaja DATE
);

CREATE TABLE app.ActividadDeportiva (
    IdActividad INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(50),
    Monto DECIMAL(10,2) NOT NULL CHECK (Monto > 0),
	FechaVigencia DATE
);

CREATE TABLE app.ActividadExtra (
    IdActividadExtra INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(50),
    Monto DECIMAL(10,2) NOT NULL CHECK (Monto > 0),
	FechaVigencia DATE
);

CREATE TABLE app.Clima (
	IdClima INT IDENTITY(1,1) PRIMARY KEY,
    Tiempo DATETIME UNIQUE, --Dejamos el tiempo como UNIQUE para evitar dos climas distintos en un mismo momento
    Temperatura DECIMAL(5,2),
    VelocidadViento DECIMAL(5,2),
    HumedadRelativa DECIMAL(5,2),
    Lluvia DECIMAL(5,2)
);

CREATE TABLE app.Profesor (
    IdProfesor INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(50),
    Apellido VARCHAR(50),
    Mail VARCHAR(100)
);


CREATE TABLE app.Socio (
    NumeroDeSocio CHAR(7) PRIMARY KEY,
    Documento VARCHAR(15) NOT NULL,
    Saldo DECIMAL(10,2),
    Estado VARCHAR(15) CHECK (Estado IN ('Activo','Inactivo')),
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
    IdDescuento INT,
    IdObraSocial INT,
    IdDebitoAutomatico INT,
    FOREIGN KEY (IdCategoriaSocio) REFERENCES app.CategoriaSocio(IdCategoriaSocio),
    FOREIGN KEY (IdGrupoFamiliar) REFERENCES app.GrupoFamiliar(IdGrupoFamiliar),
    FOREIGN KEY (IdObraSocial) REFERENCES app.ObraSocial(IdObraSocial),
    FOREIGN KEY (IdDebitoAutomatico) REFERENCES app.DebitoAutomatico(IdDebitoAutomatico)
);

ALTER TABLE app.GrupoFamiliar
ADD CONSTRAINT FK_GrupoFamiliarSocioResponsable
FOREIGN KEY (NumeroDeSocioResponsable) REFERENCES app.Socio(NumeroDeSocio);

CREATE TABLE app.CostoMembresia (
    idCostoMembresia INT IDENTITY(1,1) PRIMARY KEY,
    Monto DECIMAL(10,2) NOT NULL CHECK (Monto > 0),
    fecha DATE,
    idCategoriaSocio INT,
    FOREIGN KEY (idCategoriaSocio) REFERENCES app.CategoriaSocio(idCategoriaSocio)
);

CREATE TABLE app.Inscripcion (
    IdInscripcion INT IDENTITY(1,1) PRIMARY KEY,
    TipoInscripcion VARCHAR(20),
    Fecha DATE,
    Estado VARCHAR(20)
);

CREATE TABLE app.ClaseActividad (
    IdClaseActividad INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATETIME,
    IdActividad INT,
    IdActividadExtra INT,
    IdClima INT,
	IdProfesor INT,
    FOREIGN KEY (IdActividad) REFERENCES app.ActividadDeportiva(IdActividad),
    FOREIGN KEY (IdActividadExtra) REFERENCES app.ActividadExtra(IdActividadExtra),
    FOREIGN KEY (IdClima) REFERENCES app.Clima(IdClima),
	FOREIGN KEY (IdProfesor) REFERENCES app.Profesor(IdProfesor)
);

CREATE TABLE app.ReservaActividad (
    IdReserva INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATETIME,
	Asistencia CHAR (1) CHECK (Asistencia IN ('P','A','J')),
    NumeroDeSocio CHAR(7),
    IdClaseActividad INT,
	Monto DECIMAL(10,2)
    FOREIGN KEY (NumeroDeSocio) REFERENCES app.Socio(NumeroDeSocio),
    FOREIGN KEY (IdClaseActividad) REFERENCES app.ClaseActividad(IdClaseActividad)
);

CREATE TABLE app.Cuota (
    IdCuota INT IDENTITY(1,1) PRIMARY KEY,
    FechaEmision DATE,
    MontoCuota DECIMAL(10,2) NOT NULL CHECK (MontoCuota > 0),
    Recargo DECIMAL(10,2) NULL CHECK (Recargo IS NULL OR Recargo > 0),
    MontoTotal DECIMAL(10,2) NOT NULL CHECK (MontoTotal > 0),
    NumeroDeSocio CHAR(7),
    FOREIGN KEY (NumeroDeSocio) REFERENCES app.Socio(NumeroDeSocio)
);

CREATE TABLE app.CuotaMorosa (
    IdMorosidad INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE,
    Estado CHAR(3) DEFAULT 'VEN' CHECK (Estado IN ('VEN','PAG')),
    IdCuota INT,
    FOREIGN KEY (IdCuota) REFERENCES app.Cuota(IdCuota)
);


CREATE TABLE app.MedioPago (
    IdMedioPago INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(50),
    Descripcion VARCHAR(100)
);

CREATE TABLE app.Factura (
    IdFactura INT IDENTITY(1,1) PRIMARY KEY,
    Tipo VARCHAR(20),
    FechaFacturacion DATE,
    PrimerVencimiento DATE,
    SegundoVencimiento DATE,
	Estado CHAR(3) CHECK (Estado IN ('PEN','PAG','VEN')), 
    IdCuota INT,
    IdReserva INT,
    FOREIGN KEY (IdCuota) REFERENCES app.Cuota(IdCuota),
    FOREIGN KEY (IdReserva) REFERENCES app.ReservaActividad(IdReserva)
);


CREATE TABLE app.Pago (
    IdPago INT IDENTITY(1,1) PRIMARY KEY,
    FechaPago DATE,
    Estado CHAR(3) DEFAULT 'IMP' CHECK (Estado IN ('IMP','ANU')), --IMP=IMPUTADO, ANU=ANULADO
    IdFactura INT,
    IdMedioPago INT,
    FOREIGN KEY (IdFactura) REFERENCES app.Factura(IdFactura),
    FOREIGN KEY (IdMedioPago) REFERENCES app.MedioPago(IdMedioPago)
);

CREATE TABLE app.Devolucion (
    IdDevolucion INT IDENTITY(1,1) PRIMARY KEY,
    MontoTotal DECIMAL(10,2) NOT NULL CHECK (MontoTotal < 0),
    FechaDevolucion DATE,
    Estado CHAR(3) DEFAULT 'PEN' CHECK (Estado IN ('PEN','DEV')), --PEN: PENDIENTE, DEV: DEVUELTO
    IdPago INT,
    FOREIGN KEY (IdPago) REFERENCES app.Pago(IdPago)
);

CREATE TABLE app.ItemFactura (
    IdItemFactura INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion VARCHAR(100),
    Cantidad INT,
    PrecioUnitario DECIMAL(10,2),
    IdFactura INT,
    FOREIGN KEY (IdFactura) REFERENCES app.Factura(IdFactura)
);

-- Finalmente, crear Usuario y Descuento con FKs hacia Socio

CREATE TABLE app.Usuario (
    IdUsuario INT IDENTITY(1,1) PRIMARY KEY,
    FechaVigenciaContrasena DATE,
    Rol VARCHAR(20),
    Usuario VARCHAR(50),
    Contrasena VARCHAR(100),
	ContrasenaHash VARBINARY(32),
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

CREATE TABLE app.Invita (
    FechaInvitacion DATE,
    NumeroDeSocio CHAR(7),
    NumeroDeSocioInvitado CHAR(7),
    PRIMARY KEY (NumeroDeSocio,NumeroDeSocioInvitado, FechaInvitacion),
    FOREIGN KEY (NumeroDeSocio) REFERENCES app.Socio(NumeroDeSocio),
    FOREIGN KEY (NumeroDeSocioInvitado) REFERENCES app.Socio(NumeroDeSocio)
);


CREATE TABLE org.Area(
	IdArea INT IDENTITY(1,1) PRIMARY KEY,
	Nombre VARCHAR(50)
);
CREATE TABLE org.Puesto(
	IdPuesto INT IDENTITY(1,1) PRIMARY KEY,
	Nombre VARCHAR(50),
	IdArea INT,
	FOREIGN KEY(IdArea) REFERENCES org.Area(IdArea)
);

CREATE TABLE org.Empleado(
	IdEmpleado INT IDENTITY(1,1) PRIMARY KEY,
	Nombre VARCHAR(50),
	Apellido VARCHAR(50),
	Sueldo DECIMAL(10,2),
	Email VARCHAR(100),
	Documento VARCHAR(15),
	Telefono VARCHAR(20),
	IdPuesto INT,
	FOREIGN KEY(IdPuesto) REFERENCES org.Puesto(IdPuesto)
);

CREATE TABLE app.Reintegro(
	IdReintegro INT IDENTITY(1,1) PRIMARY KEY,
	Estado CHAR (3) CHECK (Estado IN ('PEN','FIN')),
	Fecha DATE,
	Monto DECIMAL (10,2),
	idClaseActividad INT,
	FOREIGN KEY (IdClaseActividad) REFERENCES app.ClaseActividad(IdClaseActividad)
)
