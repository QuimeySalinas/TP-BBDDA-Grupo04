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

CREATE TABLE app.ClaseActividad (
    IdClaseActividad INT IDENTITY(1,1) PRIMARY KEY,
    Horario TIME,
    Fecha DATE,
    IdProfesor INT,
    IdActividad INT,
    IdActividadExtra INT,
    IdClima INT,
    FOREIGN KEY (IdActividad) REFERENCES app.ActividadDeportiva(IdActividad),
    FOREIGN KEY (IdActividadExtra) REFERENCES app.ActividadExtra(IdActividadExtra),
    FOREIGN KEY (IdClima) REFERENCES app.Clima(IdClima)
);

CREATE TABLE app.DictadaPor (
    IdProfesor INT,
    IdClaseActividad INT,
    PRIMARY KEY (IdProfesor, IdClaseActividad),
    FOREIGN KEY (IdProfesor) REFERENCES app.Profesor(IdProfesor),
    FOREIGN KEY (IdClaseActividad) REFERENCES app.ClaseActividad(IdClaseActividad)
);

CREATE TABLE app.Reserva (
    IdReserva INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE,
    Hora TIME,
    NumeroDeSocio CHAR(7),
    IdClaseActividad INT,
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
    IdActividadExtra INT,
    FOREIGN KEY (IdCuota) REFERENCES app.Cuota(IdCuota),
    FOREIGN KEY (IdActividadExtra) REFERENCES app.ActividadExtra(IdActividadExtra)
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