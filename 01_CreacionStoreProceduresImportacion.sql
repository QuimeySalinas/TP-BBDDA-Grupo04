USE Com2900G04;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;

--Procedimiento para registrar socios
GO
CREATE OR ALTER PROCEDURE imp.ImportarResponsablesDePago
    @RutaArchivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Crear tabla temporal con el mismo collation que la base de datos
    CREATE TABLE #TemporalRespDePago (
        NroSocio CHAR(7) COLLATE Latin1_General_CI_AI,
        Nombre VARCHAR(50) COLLATE Latin1_General_CI_AI,
        Apellido VARCHAR(50) COLLATE Latin1_General_CI_AI,
        DNI VARCHAR(15) COLLATE Latin1_General_CI_AI,
        EmailPersonal VARCHAR(100) COLLATE Latin1_General_CI_AI,
        FechaNacimiento DATE,
        TelefonoContacto VARCHAR(20) COLLATE Latin1_General_CI_AI,
        TelefonoEmergencia VARCHAR(20) COLLATE Latin1_General_CI_AI,
        ObraSocial VARCHAR(50) COLLATE Latin1_General_CI_AI,
        NroSocioObraSocial VARCHAR(50) COLLATE Latin1_General_CI_AI,
        TelefonoContactoEmergencia VARCHAR(50) COLLATE Latin1_General_CI_AI
    );

    -- Cargamos de manera dinamica la query para extraer datos del excel provisto
    -- Se utilizara SQL dinámico ya que el OPENROWSET no permite la concatenacion de strings dentro del mismo. 
    -- Entonces conviene utilizar SQL dinámico justamente para esto.
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
        INSERT INTO #TemporalRespDePago
        SELECT *
        FROM OPENROWSET(
            ''Microsoft.ACE.OLEDB.12.0'',
            ''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES;IMEX=1'',
            ''SELECT * FROM [Responsables de Pago$]''
        );';

    EXEC sp_executesql @SQL;

    ------------------------------------ Procesamiento de los datos temporales ------------------------------------

    INSERT INTO app.Socio (NumeroDeSocio, Documento, Nombre, Apellido, EmailPersonal, Telefono, FechaNacimiento, NumeroObraSocial)
    SELECT 
        NroSocio COLLATE Latin1_General_CI_AI, 
        DNI COLLATE Latin1_General_CI_AI, 
        Nombre COLLATE Latin1_General_CI_AI, 
        Apellido COLLATE Latin1_General_CI_AI, 
        EmailPersonal COLLATE Latin1_General_CI_AI, 
        TelefonoContacto COLLATE Latin1_General_CI_AI, 
        FechaNacimiento, 
        NroSocioObraSocial COLLATE Latin1_General_CI_AI
    FROM #TemporalRespDePago A
    WHERE Nombre NOT LIKE '%[^a-zA-Z ]%' AND 
          Apellido NOT LIKE '%[^a-zA-Z ]%' AND  
          FechaNacimiento >= '19000101' AND FechaNacimiento < CAST(GETDATE() AS DATE) AND
          NOT EXISTS (
              SELECT 1
              FROM app.Socio B
              WHERE B.NumeroDeSocio = A.NroSocio COLLATE Latin1_General_CI_AI
          );

    -- Si hay una nueva obra social que no tenemos registrada, la ingresamos:
    INSERT INTO app.ObraSocial (Nombre)
    SELECT DISTINCT A.ObraSocial COLLATE Latin1_General_CI_AI
    FROM #TemporalRespDePago A
    LEFT JOIN app.ObraSocial B 
        ON B.Nombre COLLATE Latin1_General_CI_AI = A.ObraSocial COLLATE Latin1_General_CI_AI
    WHERE A.ObraSocial IS NOT NULL AND B.Nombre IS NULL;

    -- La tabla #TemporalRespDePago se elimina automáticamente al finalizar el SP
END;


GO
CREATE OR ALTER PROCEDURE imp.ImportarGruposFamiliares
    @rutaArchivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Crear tabla temporal con el mismo collation que la base de datos
    CREATE TABLE #GrupoFamiliarTemporal (
        NroSocio CHAR(7) COLLATE Latin1_General_CI_AI,
        NroSocioRP CHAR(7) COLLATE Latin1_General_CI_AI,
        Nombre VARCHAR(50) COLLATE Latin1_General_CI_AI,
        Apellido VARCHAR(50) COLLATE Latin1_General_CI_AI,
        DNI VARCHAR(50) COLLATE Latin1_General_CI_AI,
        EmailPersonal VARCHAR(100) COLLATE Latin1_General_CI_AI,
        FechaNacimiento DATE,
        TelefonoContacto VARCHAR(20) COLLATE Latin1_General_CI_AI,
        TelefonoEmergencia VARCHAR(20) COLLATE Latin1_General_CI_AI,
        ObraSocial VARCHAR(50) COLLATE Latin1_General_CI_AI,
        NroSocioObraSocial VARCHAR(50) COLLATE Latin1_General_CI_AI,
        TelefonoContactoEmergencia VARCHAR(50) COLLATE Latin1_General_CI_AI
    );

    -- Cargamos de manera dinámica la query para extraer datos del excel provisto
    -- Se utilizará SQL dinámico ya que el OPENROWSET no permite la concatenación de strings dentro del mismo. 
    -- Entonces conviene utilizar SQL dinámico justamente para esto.
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = N'
    INSERT INTO #GrupoFamiliarTemporal
    SELECT *
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'', 
        ''Excel 12.0;Database=' + @rutaArchivo + ';HDR=YES'', 
        ''SELECT * FROM [Grupo Familiar$]''
    )';

    EXEC sp_executesql @SQL;

    ------------------------------------ Procesamiento de los datos temporales ------------------------------------
    -- Insertamos los socios no responsables (si no están registrados)
    INSERT INTO app.Socio (NumeroDeSocio, Documento, Nombre, Apellido, EmailPersonal, Telefono, FechaNacimiento, NumeroObraSocial)
    SELECT 
        NroSocio COLLATE Latin1_General_CI_AI, 
        DNI COLLATE Latin1_General_CI_AI, 
        Nombre COLLATE Latin1_General_CI_AI, 
        Apellido COLLATE Latin1_General_CI_AI, 
        EmailPersonal COLLATE Latin1_General_CI_AI, 
        TelefonoContacto COLLATE Latin1_General_CI_AI, 
        FechaNacimiento, 
        NroSocioObraSocial COLLATE Latin1_General_CI_AI
    FROM #GrupoFamiliarTemporal A
    WHERE NOT EXISTS (  
        SELECT 1 FROM app.Socio B WHERE B.NumeroDeSocio = A.NroSocio COLLATE Latin1_General_CI_AI -- Que no esté registrado previamente
    )
    AND Nombre NOT LIKE '%[^a-zA-Z ]%' 
    AND Apellido NOT LIKE '%[^a-zA-Z ]%'
    AND FechaNacimiento >= '19000101' 
    AND FechaNacimiento < CAST(GETDATE() AS DATE);

    -- Creamos grupos familiares
    INSERT INTO app.GrupoFamiliar (FechaCreacion, Estado, NombreFamilia, NumeroDeSocioResponsable)
    SELECT DISTINCT
        CAST(GETDATE() AS DATE),
        'Activo',
        CONCAT('Grupo de ', Apellido COLLATE Latin1_General_CI_AI),
        NroSocioRP COLLATE Latin1_General_CI_AI
    FROM #GrupoFamiliarTemporal A
    WHERE NOT EXISTS (
        SELECT 1 FROM app.GrupoFamiliar B 
        WHERE B.NumeroDeSocioResponsable = A.NroSocioRP COLLATE Latin1_General_CI_AI
    );

    -- Actualizamos los socios no responsables
    UPDATE s
    SET s.IdGrupoFamiliar = g.IdGrupoFamiliar
    FROM app.Socio s
    INNER JOIN #GrupoFamiliarTemporal t 
        ON s.NumeroDeSocio = t.NroSocio COLLATE Latin1_General_CI_AI -- Socios no responsables que están en el excel
    INNER JOIN app.GrupoFamiliar g 
        ON g.NumeroDeSocioResponsable = t.NroSocioRP COLLATE Latin1_General_CI_AI; -- Obtenemos datos del grupo familiar según su responsable.

    -- La tabla #GrupoFamiliarTemporal se elimina una vez finaliza el SP
END;


GO
CREATE OR ALTER PROCEDURE imp.ImportarTarifas
    @RutaArchivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Creamos las tablas temporales que usaremos con el collation adecuado
    CREATE TABLE #Actividades (
        Actividad VARCHAR(50) COLLATE Latin1_General_CI_AI,
        ValorPorMes DECIMAL(10,2),
        VigenteHasta DATE
    );

    CREATE TABLE #CategoriasSocio (
        CategoriaSocio VARCHAR(50) COLLATE Latin1_General_CI_AI,
        ValorCuota DECIMAL(12,2),
        VigenteHasta DATE
    );

    -- Cargamos con SQL Dinámico las tablas (debido a que la RutaArchivo es una variable)
    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
    INSERT INTO #Actividades
    SELECT [Actividad], [Valor por mes], [Vigente hasta]
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'',
        ''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES;IMEX=1'',
        ''SELECT * FROM [Tarifas$B2:D8]''
    );';

    EXEC sp_executesql @SQL;

    SET @SQL = '
    INSERT INTO #CategoriasSocio
    SELECT [Categoria socio], [Valor cuota], [Vigente hasta]
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'',
        ''Excel 12.0;Database=' + @RutaArchivo + ';HDR=YES;IMEX=1'',
        ''SELECT * FROM [Tarifas$B10:D13]''
    );';

    EXEC sp_executesql @SQL;

    -- Insertamos los datos en actividad deportiva
    INSERT INTO app.ActividadDeportiva (Nombre, Monto, FechaVigencia)
    SELECT Actividad COLLATE Latin1_General_CI_AI, ValorPorMes, VigenteHasta
    FROM #Actividades t
    WHERE Actividad NOT LIKE '%[^a-zA-Z ]%'
	AND NOT EXISTS(
		SELECT 1 FROM app.ActividadDeportiva a
		WHERE t.Actividad COLLATE Latin1_General_CI_AI = a.Nombre COLLATE Latin1_General_CI_AI
		AND t.ValorPorMes = a.Monto AND t.VigenteHasta = a.FechaVigencia
	);

    -- Insertamos los datos de categorías de socios evitando duplicados
    INSERT INTO app.CategoriaSocio (nombre)
    SELECT DISTINCT CategoriaSocio COLLATE Latin1_General_CI_AI
    FROM #CategoriasSocio
    WHERE NOT EXISTS (
        SELECT 1 FROM app.CategoriaSocio cs
        WHERE cs.nombre COLLATE Latin1_General_CI_AI = CategoriaSocio COLLATE Latin1_General_CI_AI
    );

    -- Ingresamos los costos de cada categoría
    INSERT INTO app.CostoMembresia (Monto, Fecha, idCategoriaSocio)
    SELECT 
        t.ValorCuota, 
        t.VigenteHasta, 
        cat.idCategoriaSocio
    FROM #CategoriasSocio t
    INNER JOIN app.CategoriaSocio cat 
        ON cat.nombre COLLATE Latin1_General_CI_AI = t.CategoriaSocio COLLATE Latin1_General_CI_AI
	WHERE NOT EXISTS(
		SELECT 1 FROM app.CostoMembresia cm
		WHERE cm.fecha = t.vigenteHasta AND cm.Monto = t.ValorCuota AND cm.idCategoriaSocio  = cat.IdCategoriaSocio
	)
END;

--IMPORTACION DE CLIMAS
GO
CREATE OR ALTER PROCEDURE imp.ImportacionClimas
	@RutaArchivo NVARCHAR(MAX)
AS
BEGIN TRY
	SET NOCOUNT ON;
	CREATE TABLE #TempClima (
		Tiempo VARCHAR(20),
		Temperatura VARCHAR(10),
		Lluvia VARCHAR(10),
		HumedadRelativa VARCHAR(10),
		VelocidadViento VARCHAR(10)
	);
	DECLARE @SQL NVARCHAR(MAX);

	--Utilizamos SQL Dinamico ya que la ruta viene por parametro
	SET @SQL = '
		INSERT INTO #TempClima (Tiempo, Temperatura, Lluvia, HumedadRelativa, VelocidadViento)
		SELECT *
		FROM OPENROWSET(
			BULK ''' + @RutaArchivo + ''',
			FORMAT = ''CSV'',
			FIRSTROW = 5,
			FIELDTERMINATOR = '','',
			ROWTERMINATOR = ''\n'',
			CODEPAGE = ''65001''
		) WITH (
			Tiempo VARCHAR(20),
			Temperatura VARCHAR(10),
			Lluvia VARCHAR(10),
			HumedadRelativa VARCHAR(10),
			VelocidadViento VARCHAR(10)
		) AS DatosCSV;';

    EXEC sp_executesql @SQL;

	--Una vez guardados los datos en la temporal, procedemos a transformarlos y guardarlos en la definitiva
	INSERT INTO app.Clima (Tiempo, Temperatura, Lluvia, HumedadRelativa, VelocidadViento)
	SELECT
		CAST(REPLACE(Tiempo, 'T', ' ') AS DATETIME),
		CAST(Temperatura AS DECIMAL(5,2)),
		CAST(Lluvia AS DECIMAL(3,1)),
		CAST(HumedadRelativa AS DECIMAL(5,2)),
		CAST(VelocidadViento AS DECIMAL(5,2))
	FROM #TempClima t
	WHERE NOT EXISTS (
		SELECT 1 FROM app.Clima c 
		WHERE c.Tiempo = CAST(REPLACE(t.Tiempo, 'T', ' ') AS DATETIME)
	);

	--Por ultimo, asociamos los climas ya cargados con las clases que tenemos
	UPDATE CA
	SET IdClima = C.IdClima
	FROM app.ClaseActividad CA
	INNER JOIN app.Clima C ON CA.Fecha = C.Tiempo;

	PRINT 'Importacion realizada con exito!'
END TRY
BEGIN CATCH
	PRINT 'Error de importacion! ' + ERROR_MESSAGE(); 
END CATCH
