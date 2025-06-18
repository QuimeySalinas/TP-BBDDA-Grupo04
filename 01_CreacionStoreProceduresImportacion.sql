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
    -- Se utilizara SQL din�mico ya que el OPENROWSET no permite la concatenacion de strings dentro del mismo. 
    -- Entonces conviene utilizar SQL din�mico justamente para esto.
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

    INSERT INTO app.Socio (NumeroDeSocio, Documento, Nombre, Apellido, EmailPersonal, Telefono, FechaNacimiento, NumeroObraSocial, Saldo,IdCategoriaSocio)
    SELECT 
        NroSocio COLLATE Latin1_General_CI_AI, 
        DNI COLLATE Latin1_General_CI_AI, 
        Nombre COLLATE Latin1_General_CI_AI, 
        Apellido COLLATE Latin1_General_CI_AI, 
        EmailPersonal COLLATE Latin1_General_CI_AI, 
        TelefonoContacto COLLATE Latin1_General_CI_AI, 
        FechaNacimiento, 
        NroSocioObraSocial COLLATE Latin1_General_CI_AI,
		0, --Inicializamos el saldo en 0
		CASE  
			WHEN DATEDIFF(YEAR, FechaNacimiento, GETDATE()) < 18 THEN COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Menor'), NULL)  
			WHEN DATEDIFF(YEAR, FechaNacimiento, GETDATE()) BETWEEN 18 AND 25 THEN COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Cadete'), NULL)  
			ELSE COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Mayor'), NULL)  
		END  

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

    -- La tabla #TemporalRespDePago se elimina autom�ticamente al finalizar el SP
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

    -- Cargamos de manera din�mica la query para extraer datos del excel provisto
    -- Se utilizar� SQL din�mico ya que el OPENROWSET no permite la concatenaci�n de strings dentro del mismo. 
    -- Entonces conviene utilizar SQL din�mico justamente para esto.
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
    -- Insertamos los socios no responsables (si no est�n registrados)
    INSERT INTO app.Socio (NumeroDeSocio, Documento, Nombre, Apellido, EmailPersonal, Telefono, FechaNacimiento, NumeroObraSocial,Saldo,IdCategoriaSocio)
    SELECT 
        NroSocio COLLATE Latin1_General_CI_AI, 
        DNI COLLATE Latin1_General_CI_AI, 
        Nombre COLLATE Latin1_General_CI_AI, 
        Apellido COLLATE Latin1_General_CI_AI, 
        EmailPersonal COLLATE Latin1_General_CI_AI, 
        TelefonoContacto COLLATE Latin1_General_CI_AI, 
        FechaNacimiento, 
        NroSocioObraSocial COLLATE Latin1_General_CI_AI,
		0, --Inicializamos el saldo en 0
		CASE  
			WHEN DATEDIFF(YEAR, FechaNacimiento, GETDATE()) < 18 THEN COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Menor'), NULL)  
			WHEN DATEDIFF(YEAR, FechaNacimiento, GETDATE()) BETWEEN 18 AND 25 THEN COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Cadete'), NULL)  
			ELSE COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Mayor'), NULL)  
		END 
    FROM #GrupoFamiliarTemporal A
    WHERE NOT EXISTS (  
        SELECT 1 FROM app.Socio B WHERE B.NumeroDeSocio = A.NroSocio COLLATE Latin1_General_CI_AI -- Que no est� registrado previamente
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
        ON s.NumeroDeSocio = t.NroSocio COLLATE Latin1_General_CI_AI -- Socios no responsables que est�n en el excel
    INNER JOIN app.GrupoFamiliar g 
        ON g.NumeroDeSocioResponsable = t.NroSocioRP COLLATE Latin1_General_CI_AI; -- Obtenemos datos del grupo familiar seg�n su responsable.

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

    -- Cargamos con SQL Din�mico las tablas (debido a que la RutaArchivo es una variable)
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

    -- Insertamos los datos de categorias de socios evitando duplicados
    INSERT INTO app.CategoriaSocio (nombre)
    SELECT DISTINCT CategoriaSocio COLLATE Latin1_General_CI_AI
    FROM #CategoriasSocio
    WHERE NOT EXISTS (
        SELECT 1 FROM app.CategoriaSocio cs
        WHERE cs.nombre COLLATE Latin1_General_CI_AI = CategoriaSocio COLLATE Latin1_General_CI_AI
    );

    -- Ingresamos los costos de cada categor�a
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

	-- Una vez tenemos las categorias, actualizamos las categorias de los socios ya cargados:
	UPDATE s
	SET IdCategoriaSocio =
		CASE 
			WHEN DATEDIFF(YEAR, s.FechaNacimiento, GETDATE()) < 18 THEN (SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Menor')
			WHEN DATEDIFF(YEAR, s.FechaNacimiento, GETDATE()) BETWEEN 18 AND 25 THEN (SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Cadete')
			ELSE (SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Mayor')
		END
	FROM app.Socio s;
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

--Importacion de presentismos a clases
GO
CREATE OR ALTER PROCEDURE imp.ImportarPresentismoClases
    @RutaArchivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    -- Crear tabla temporal
    CREATE TABLE #PresentismoExcel (
        Nombre VARCHAR(50) COLLATE Latin1_General_CI_AI,
        Act VARCHAR(50) COLLATE Latin1_General_CI_AI,
        Fecha DATE,
        Asis VARCHAR(5) COLLATE Latin1_General_CI_AI,
        IdSocio CHAR(7) COLLATE Latin1_General_CI_AI
    );

    -- Cargar datos del Excel en tabla temporal con SQL dinámico
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = '
    INSERT INTO #PresentismoExcel
    SELECT 
        [Profesor] COLLATE Latin1_General_CI_AI AS Nombre, 
        [Actividad] COLLATE Latin1_General_CI_AI AS Act, 
        [fecha de asistencia] AS Fecha,  
        [Asistencia] COLLATE Latin1_General_CI_AI AS Asis, 
        [Nro de Socio] COLLATE Latin1_General_CI_AI AS IdSocio
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'',
        ''Excel 12.0 Xml;HDR=YES;Database=' + @RutaArchivo + ''',
        ''SELECT * FROM [presentismo_actividades$]''
    );';

    EXEC sp_executesql @SQL;

    -- Cargamos la asistencia a clases actualizando la tabla Reserva:
    UPDATE R
    SET R.Asistio = PE.Asis
    FROM app.Reserva R
    INNER JOIN #PresentismoExcel PE ON R.NumeroDeSocio = PE.IdSocio COLLATE Latin1_General_CI_AI
    INNER JOIN app.ClaseActividad CA ON R.IdClaseActividad = CA.IdClaseActividad
    INNER JOIN app.Profesor P ON CA.IdProfesor = P.IdProfesor
    INNER JOIN app.ActividadDeportiva AD ON CA.IdActividad = AD.IdActividad
    WHERE P.Nombre COLLATE Latin1_General_CI_AI = PE.Nombre COLLATE Latin1_General_CI_AI
      AND CA.Fecha = PE.Fecha
      AND AD.Nombre COLLATE Latin1_General_CI_AI = PE.Act COLLATE Latin1_General_CI_AI
      AND PE.Asis COLLATE Latin1_General_CI_AI IN ('P','A','J');

    -- Eliminamos la tabla temporal.
    DROP TABLE #PresentismoExcel;
END;


--Importar pagos de socios responsables desde excel
GO
CREATE OR ALTER PROCEDURE imp.ImportarPagosDesdeExcel
    @RutaArchivo NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    -- Crear tabla temporal
    CREATE TABLE #PagosExcel (
        FechaPago DATE,
        MedioDePago VARCHAR(50) COLLATE Latin1_General_CI_AI,
        NumeroDeSocio CHAR(7) COLLATE Latin1_General_CI_AI,
        MontoPago DECIMAL(12,2)
    );

    -- Cargar datos del Excel en tabla temporal con SQL dinámico
    DECLARE @SQL NVARCHAR(MAX);
    SET @SQL = '
    INSERT INTO #PagosExcel
    SELECT CONVERT(DATE, [fecha]) AS FechaPago,
        [Medio de pago] COLLATE Latin1_General_CI_AI AS MedioDePago,
        [Responsable de pago] COLLATE Latin1_General_CI_AI AS NumeroDeSocio,
        [valor] AS MontoPago
    FROM OPENROWSET(
        ''Microsoft.ACE.OLEDB.12.0'',
        ''Excel 12.0 Xml;HDR=YES;Database=' + @RutaArchivo + ''',
        ''SELECT * FROM [pago cuotas$]''
    );';
    EXEC sp_executesql @SQL;
	
    -- Se enumeran de menor a mayor las facturas pendientes por socio y monto  
    WITH FacturasPendientes(NumeroDeSocio,MontoTotal,IdFactura,NroFactura) AS (
        SELECT 
            C.NumeroDeSocio, 
            C.MontoTotal, 
            F.IdFactura,
            ROW_NUMBER() OVER (PARTITION BY C.NumeroDeSocio, C.MontoTotal ORDER BY F.FechaFacturacion) AS NroFactura
        FROM app.Cuota C
        INNER JOIN app.Factura F ON C.IdCuota = F.IdCuota AND F.Estado IN ('PEN','VEN')
    ),
    -- Se enumeran los pagos importados por socio y monto
    PagosExcelNumerados(FechaPago,MedioDePago,NumeroDeSocio,MontoPago,NroPago) AS (
        SELECT 
            PE.FechaPago,
            PE.MedioDePago COLLATE Latin1_General_CI_AI,
            PE.NumeroDeSocio COLLATE Latin1_General_CI_AI,
            PE.MontoPago,
            ROW_NUMBER() OVER (PARTITION BY PE.NumeroDeSocio, PE.MontoPago ORDER BY PE.FechaPago) AS NroPago
        FROM #PagosExcel PE
    )
    -- Insertar pagos matcheando por número correlativo entre pagos y facturas
   INSERT INTO app.Pago (FechaPago, Estado, IdFactura, IdMedioPago)
    SELECT 
        P.FechaPago,
        'IMP' AS Estado,
        F.IdFactura,
        MP.IdMedioPago
    FROM PagosExcelNumerados P
    INNER JOIN FacturasPendientes F
        ON P.NumeroDeSocio = F.NumeroDeSocio COLLATE Latin1_General_CI_AI
        AND P.MontoPago = F.MontoTotal 
        AND P.NroPago = F.NroFactura
    INNER JOIN app.MedioPago MP 
        ON MP.Nombre COLLATE Latin1_General_CI_AI = P.MedioDePago COLLATE Latin1_General_CI_AI;

    -- Eliminar la tabla temporal
    DROP TABLE #PagosExcel;
END;