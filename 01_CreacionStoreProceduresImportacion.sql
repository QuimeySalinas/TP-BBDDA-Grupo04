USE Com2900G04;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;


--Procedimiento para registrar socios
GO
CREATE PROCEDURE imp.ImportarResponsablesDePago
    @RutaArchivo NVARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    -- Crear tabla temporal
    CREATE TABLE #TemporalRespDePago (
		NroSocio CHAR(7),
		Nombre VARCHAR(50),
		Apellido VARCHAR(50),
		DNI VARCHAR(15),
		EmailPersonal VARCHAR(100),
		FechaNacimiento DATE,
		TelefonoContacto VARCHAR(20),
		TelefonoEmergencia VARCHAR(20),
		ObraSocial VARCHAR(50),
		NroSocioObraSocial VARCHAR(50),
		TelefonoContactoEmergencia VARCHAR(20)
	);

    -- Cargamos de manera dinamica la query para extraer datos del excel provisto
	--Se utilizara SQL dinamico ya que el OPENROWSET no permite la concatenacion de strings dentro del mismo. 
	--Entonces conviene utilizar SQL dinamico justamente para esto.
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
        INSERT INTO #TemporalRespDePago
        SELECT
            [Nro de Socio],
            [Nombre],
            [apellido],
            [DNI],
            [email personal],
            [fecha de nacimiento],
            [teléfono de contacto],
            [teléfono de contacto emergencia],
            [Nombre de la obra social o prepaga],
            [nro. de socio obra social/prepaga],
            [teléfono de contacto de emergencia]
        FROM OPENROWSET(
            ''Microsoft.ACE.OLEDB.12.0'',
            ''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES;IMEX=1'',
            ''SELECT * FROM [Responsables de Pago$]''
        );';

    EXEC sp_executesql @SQL;

    ------------------------------------ Procesamiento de los datos temporales ------------------------------------

    INSERT INTO app.Socio (NumeroDeSocio, Documento, Nombre, Apellido, EmailPersonal, Telefono, FechaNacimiento,NumeroObraSocial)
    SELECT NroSocio, DNI, Nombre, Apellido, EmailPersonal, TelefonoContacto, FechaNacimiento,NroSocioObraSocial
    FROM #TemporalRespDePago A
	WHERE Nombre NOT LIKE '%[^a-zA-Z ]%' and Apellido NOT LIKE '%[^a-zA-Z ]%' and 
	FechaNacimiento >= '19000101' and FechaNacimiento < CAST(GETDATE() AS DATE) AND
    NOT EXISTS (
        SELECT 1
        FROM app.Socio B
        WHERE B.NumeroDeSocio = A.NroSocio
    );

	--Si hay una nueva obra social que no tenemos registrada, la ingresamos:

	INSERT INTO app.ObraSocial (Nombre)
	SELECT DISTINCT A.ObraSocial
	FROM #TemporalRespDePago A
	LEFT JOIN app.ObraSocial B ON B.Nombre = A.ObraSocial
	WHERE A.ObraSocial IS NOT NULL AND B.Nombre IS NULL;

    -- La tabla #SociosTemp se elimina automáticamente al finalizar el SP
END;



--Procedimiento para insertar datos de Grupos familiares.
GO
CREATE PROCEDURE imp.ImportarGruposFamiliares
	@rutaArchivo NVARCHAR(260)
AS
BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #GrupoFamiliarTemporal (
		NroSocio CHAR(7),
		NroSocioRP CHAR(7),
		Nombre VARCHAR(50),
		Apellido VARCHAR(50),
		DNI INT,
		EmailPersonal VARCHAR(100),
		FechaNacimiento DATE,
		TelefonoContacto VARCHAR(20),
		TelefonoEmergencia VARCHAR(20),
		ObraSocial VARCHAR(50),
		NroSocioObraSocial VARCHAR(50),
		TelefonoContactoEmergencia VARCHAR(20)
	);

	-- Cargamos de manera dinamica la query para extraer datos del excel provisto
	--Se utilizara SQL dinamico ya que el OPENROWSET no permite la concatenacion de strings dentro del mismo. 
	--Entonces conviene utilizar SQL dinamico justamente para esto.
    DECLARE @SQL NVARCHAR(MAX);

	SET @SQL = N'
    INSERT INTO #GrupoFamiliarTemporal
    SELECT 
        [Nro de Socio], 
		[Nro de socio RP], 
		[Nombre], [apellido], 
		[DNI], 
        [email personal], 
		[fecha de nacimiento], 
		[teléfono de contacto], 
        [teléfono de contacto emergencia], 
		[Nombre de la obra social o prepaga], 
        [nro. de socio obra social/prepaga], 
		[teléfono de contacto de emergencia]
    FROM OPENROWSET(
		''Microsoft.ACE.OLEDB.12.0'', 
        ''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES'', 
        ''SELECT * FROM [Grupo Familiar$]''
	)';

    EXEC sp_executesql @SQL;

    ------------------------------------ Procesamiento de los datos temporales ------------------------------------
	--Insertamos los socios no responsables (si no estan registrados)
	INSERT INTO app.Socio (NumeroDeSocio, Documento, Nombre, Apellido, EmailPersonal, Telefono, FechaNacimiento, NumeroObraSocial)
	SELECT NroSocio,DNI,Nombre,Apellido,EmailPersonal,TelefonoContacto,FechaNacimiento,NroSocioObraSocial
	FROM #GrupoFamiliarTemporal A
	WHERE NOT EXISTS ( 
			SELECT 1 FROM app.Socio B WHERE B.NumeroDeSocio = A.NroSocio --Que no este registrado previamente
		)
		AND Nombre NOT LIKE '%[^a-zA-Z ]%' AND Apellido NOT LIKE '%[^a-zA-Z ]%'
		AND FechaNacimiento >= '19000101' AND FechaNacimiento < CAST(GETDATE() AS DATE);

	--Creamos grupos familiares
	INSERT INTO app.GrupoFamiliar (FechaCreacion, Estado, NombreFamilia, NumeroDeSocioResponsable)
	SELECT DISTINCT
		CAST(GETDATE() AS DATE),
		'Activo',
		CONCAT('Grupo de ', Apellido),
		NroSocioRP
	FROM #GrupoFamiliarTemporal A
	WHERE NOT EXISTS (
		SELECT 1 FROM app.GrupoFamiliar B 
		WHERE B.NumeroDeSocioResponsable = A.NroSocioRP
	);

	--Actualizamos los socios no responsables
	UPDATE s
	SET s.IdGrupoFamiliar = g.IdGrupoFamiliar
	FROM app.Socio s
	INNER JOIN #GrupoFamiliarTemporal t ON s.NumeroDeSocio = t.NroSocio --Socios no responsables que estan en el excel
	INNER JOIN app.GrupoFamiliar g ON g.NumeroDeSocioResponsable = t.NroSocioRP; -- obtenemos datos del grupo familiar segun su responsable.

	--La tabla #GrupoFamiliarTemporal se elimina una vez finaliza el SP
END


GO
CREATE PROCEDURE imp.ImportarTarifas
	@RutaArchivo NVARCHAR(260)
AS
BEGIN
	SET NOCOUNT ON;
	--Creamos las tablas temporales que usaremos
	CREATE TABLE #Actividades (
		Actividad VARCHAR(50),
		ValorPorMes DECIMAL(10,2),
		VigenteHasta DATE
	);

	CREATE TABLE #CategoriasSocio (
		CategoriaSocio VARCHAR(50),
		ValorCuota DECIMAL(12, 2),
		VigenteHasta DATE
	);

	--Cargamos con SQL Dinamico las tablas (debido a que la RutaArchivo es una variable)
	DECLARE @SQL NVARCHAR(MAX);

	SET @SQL = '
	SELECT * INTO #Actividades
	FROM OPENROWSET(
		''Microsoft.ACE.OLEDB.12.0'',
		''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES;IMEX=1'',
		''SELECT * FROM [Tarifas$B2:D8]''
	);';

	EXEC sp_executesql @SQL;

	SET @SQL = '
	SELECT * INTO #CategoriasSocio
	FROM OPENROWSET(
		''Microsoft.ACE.OLEDB.12.0'',
		''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES;IMEX=1'',
		''SELECT * FROM [Tarifas$B10:D13]''
	);';
	EXEC sp_executesql @SQL;

	--Insertamos los datos en actividad deportiva
	INSERT INTO app.ActividadDeportiva(Nombre,Monto,FechaVigencia,ActividadExtra)
	SELECT Actividad,ValorPorMes,VigenteHasta,0
	FROM #Actividades
	where Actividad NOT LIKE '%[^a-zA-Z ]%'

	--Insertamos los datos de categorias socios

	-- Insertar categorías (evitando duplicados si ya existen)
	INSERT INTO app.CategoriaSocio (nombre)
	SELECT DISTINCT CategoriaSocio
	FROM #CategoriasSocio
	WHERE NOT EXISTS (
		SELECT 1 FROM app.CategoriaSocio cs
		WHERE cs.nombre = #CategoriasSocio.CategoriaSocio
	);
	--Ingresamos los costos de cada categoria
	INSERT INTO app.CostoMembresia (Monto, Fecha, idCategoriaSocio)
	SELECT 
		t.ValorCuota,
		t.VigenteHasta,
		cat.idCategoriaSocio
	FROM #CategoriasSocio t
	INNER JOIN app.CategoriaSocio cat ON cat.nombre = t.CategoriaSocio;
END