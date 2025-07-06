USE Com2900G04;
GO
/*Este archivo esta pensado para ser ejecutado por partes e ir visualizando los datos insertados en las tablas.
Recomendamos, generar una carpeta dentro de C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL
que se llame ArchivosImportacion y alli dentro pegar los archivos que se deben importar, cambiar la ruta en caso 
de hacer falta.
Es importanto, ir ejecutando este archivo paso a paso, en el orden en el que fue predispuesto.
*/


--Continuamos con los responsables de pago:
EXEC imp.ImportarResponsablesDePago 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\Datos socios.xlsx'
--Verificamos si se ingresaron datos en los socios
SELECT COUNT(*) [Numero de filas] FROM app.Socio WHERE IdGrupoFamiliar IS NULL
--Tambien podemos corroborar si se crearon los usuarios y se hashearon las contrasenas
SELECT * FROM app.Usuario

--Continuamos con los grupos familiares
EXEC imp.ImportarGruposFamiliares 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\Datos socios.xlsx'
--Verificamos si se ingresaron datos en los grupos familiares y los nuevos socios 
SELECT * FROM app.GrupoFamiliar
SELECT NumeroDeSocio, IdGrupoFamiliar FROM app.Socio WHERE IdGrupoFamiliar IS NOT NULL
--Tambien podemos corroborar si se crearon los usuarios y se hashearon las contrasenas
SELECT * FROM app.Usuario

--Ahora, importamos las tarifas
EXEC imp.ImportarTarifas 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\Datos socios.xlsx'
--
SELECT * FROM app.CategoriaSocio 
SELECT * FROM app.CostoMembresia
SELECT * FROM app.ActividadDeportiva

--Importamos los pagos realizados por los socios
--Pero antes.. hay que generar cuotas
INSERT INTO app.MedioPago (Nombre, Descripcion) VALUES
	('Visa','Pago con tarjeta'),
	('MasterCard','Pago con tarjeta'),
	('Tarjeta Naranja','Pago con tarjeta'),
	('Pago F�cil','Pago en efectivo'),
	('Efectivo','Pago en efectivo'),
	('MercadoPago','Transferencia');

--Importar datos de cuotas: (Este procedimiento es para pruebas, lo ideal es que las cuotas ya esten previamente cargadas)
    -- Cargar datos del Excel en tabla temporal
    SELECT [fecha], [valor], [Responsable de pago] COLLATE Latin1_General_CI_AI AS NumeroDeSocio
	INTO #CuotasExcel
	FROM OPENROWSET('Microsoft.ACE.OLEDB.12.0',
	'Excel 12.0 Xml;HDR=YES;Database=C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\Datos socios.xlsx;',
	'SELECT * FROM [pago cuotas$]');

    -- Insertamos las cuotas segun los pagos ingresados.
    INSERT INTO app.Cuota (FechaEmision, MontoCuota, Recargo, MontoTotal, NumeroDeSocio)
    SELECT 
        CONVERT(DATE, [fecha]) AS FechaEmision,
        [valor] AS MontoCuota,
        ([valor] * 0.1) AS Recargo, 
        [valor] AS MontoTotal,
		CE.NumeroDeSocio
    FROM #CuotasExcel CE
    WHERE CE.NumeroDeSocio IN (SELECT NumeroDeSocio FROM app.Socio)
    ;

    DROP TABLE #CuotasExcel;

SELECT * FROM app.Cuota
select * from app.Factura
select * from app.ItemFactura
--Ahora si, importamos los pagos
EXEC imp.ImportarPagosDesdeExcel 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\Datos socios.xlsx'
SELECT * FROM app.Pago

/*
Importamos los presentismos de los socios, previamente hay que tener datos precargados, por ende
Ejecutaremos lo siguiente a modo de prueba para completar las tablas de reserva, clase actividad y profesor
	Creamos una tabla temporal para guardar la tabla del excel
*/	
	SELECT 
		[Profesor] COLLATE Latin1_General_CI_AI AS Nombre, 
		[Actividad] COLLATE Latin1_General_CI_AI AS Act, 
		[fecha de asistencia] AS fecha,  
		[Asistencia] COLLATE Latin1_General_CI_AI AS Asis, 
		[Nro de Socio] COLLATE Latin1_General_CI_AI AS IdSocio
	INTO #PresentismoExcel
	FROM OPENROWSET(
		'Microsoft.ACE.OLEDB.12.0',
		'Excel 12.0 Xml;HDR=YES;Database=C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\Datos socios.xlsx;',
		'SELECT * FROM [presentismo_actividades$]'
	);
	--Insertamos los profesores si no existen
	INSERT INTO app.Profesor (Nombre)
	SELECT DISTINCT t.Nombre
	FROM #PresentismoExcel t
	WHERE NOT EXISTS(
		SELECT 1 FROM app.Profesor p WHERE p.Nombre = t.Nombre
	)
	-- Insertamos en ClaseActividad
	INSERT INTO app.ClaseActividad (Fecha, IdProfesor, IdActividad)
	SELECT 
		CONVERT(DATETIME, PE.Fecha) AS Fecha,
		P.IdProfesor,
		AD.IdActividad
	FROM #PresentismoExcel PE 
	INNER JOIN app.Profesor P 
		ON P.Nombre COLLATE Latin1_General_CI_AI = PE.Nombre COLLATE Latin1_General_CI_AI
	INNER JOIN app.ActividadDeportiva AD 
		ON PE.Act COLLATE Latin1_General_CI_AI = AD.Nombre COLLATE Latin1_General_CI_AI
	GROUP BY PE.Fecha, P.IdProfesor, AD.IdActividad;
	-- Insertamos los registros en Reserva
	INSERT INTO app.ReservaActividad (Fecha, NumeroDeSocio, IdClaseActividad, Asistencia)
	SELECT 
		PE.Fecha,
		PE.IdSocio COLLATE Latin1_General_CI_AI, 
		IdClaseActividad,
		NULL
	FROM #PresentismoExcel PE
	INNER JOIN app.Profesor P 
		ON PE.Nombre COLLATE Latin1_General_CI_AI = P.Nombre COLLATE Latin1_General_CI_AI
	INNER JOIN app.ClaseActividad CA 
		ON P.IdProfesor = CA.IdProfesor 
		AND PE.Fecha = CA.Fecha
	INNER JOIN app.ActividadDeportiva AD 
		ON CA.IdActividad = AD.IdActividad
	WHERE AD.Nombre COLLATE Latin1_General_CI_AI = PE.Act COLLATE Latin1_General_CI_AI
	AND PE.IdSocio COLLATE Latin1_General_CI_AI IN (SELECT NumeroDeSocio FROM app.Socio)
	AND PE.Asis COLLATE Latin1_General_CI_AI IN ('P','A','J');

	-- Eliminamos la tabla temporal
	DROP TABLE #PresentismoExcel;

SELECT * FROM app.Profesor
SELECT * FROM app.ClaseActividad
SELECT * FROM app.ReservaActividad
--Ahora si, importamos los presentismos:
EXEC imp.ImportarPresentismoClases 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\Datos socios.xlsx'
SELECT * FROM app.ReservaActividad

--Ahora importamos los climas:
--Pero antes, agregamos un registro en Clase Actividad en el que coincidan las fechas de los csv para
--comprobar que se actualizan los climas en esa tabla correctamente.
INSERT INTO app.ClaseActividad (Fecha, IdActividad, IdProfesor)
SELECT 
    '2025-03-01',  -- Fecha fija
    IdActividad, 
    (SELECT TOP 1 IdProfesor FROM app.Profesor)  -- cualquier profesor 
FROM app.ActividadDeportiva
WHERE Nombre = 'Futsal' OR Nombre = 'Natacion'; --Insertamos dos registros en total

--Ahora si, importamos los climas:
EXEC imp.ImportacionClimas 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\open-meteo-buenosaires_2024.csv'
EXEC imp.ImportacionClimas 'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\ArchivosImportacion\open-meteo-buenosaires_2025.csv'
--Verificamos la correcta insersion de datos:
SELECT * FROM app.Clima
SELECT * FROM app.ClaseActividad WHERE IdClima IS NOT NULL --Se actualizan los datos que coinciden en la fecha

--Con esta consulta podemos ver las clases que coinciden en fecha y hora con nuestros datos en Clima
SELECT * FROM app.ClaseActividad ca INNER JOIN app.Clima c ON ca.Fecha = c.Tiempo

--Se Insertan 3 registros de cuotas vencidas para la prueba del SP.
INSERT INTO app.Cuota(FechaEmision, MontoCuota, Recargo, MontoTotal, NumeroDeSocio) VALUES ('2025-01-01', 5000, 500, 5000, 'SN-4022');
INSERT INTO app.Cuota(FechaEmision, MontoCuota, Recargo, MontoTotal, NumeroDeSocio) VALUES ('2025-01-15', 1000, 100, 1000, 'SN-4024');
INSERT INTO app.Cuota(FechaEmision, MontoCuota, Recargo, MontoTotal, NumeroDeSocio) VALUES ('2025-03-01', 15000, 1500, 15000, 'SN-4023');

EXEC RevisionFacturaVencida;

--Genera los registros en la tabla cuotamorosa basandose en las facturas que se marcaron como vencidas.
EXEC MonitorDeDeuda;

SELECT * FROM app.CuotaMorosa
--Este SP genera devolución para un pago X y genera registros en la tabla devolución
--Debe ejecutarse post importacion de los pagos.
EXEC GenerarDevolucion @idPago = '10'

SELECT * FROM App.Devolucion

--Procesa la devolución generando una nota de crédito en la cuenta
EXEC ProcesarDevolucion

SELECT * FROM app.Factura WHERE tipo = 'Nota de credito'

--Este SP se ejecuta una vez al día, se debe ejecutar cuando un cliente pase un mes sin cuotas, para ello,
--Podemos eliminar las cuotas del cliente generadas el último mes, primero debe eliminarse el item, luego la factura y luego la cuota.
--Podemos ejecutar estos 3 deletes para la prueba
DELETE IT
FROM app.ItemFactura AS IT
INNER JOIN app.Factura AS F ON IT.IdFactura = F.IdFactura
INNER JOIN app.Cuota AS C ON F.IdCuota = C.IdCuota
WHERE C.FechaEmision > DATEADD(DAY, -30, GETDATE())
  AND C.NumeroDeSocio IN ('SN-4118','SN-4116');

DELETE F
FROM app.Factura AS F
INNER JOIN app.Cuota AS C ON F.IdCuota = C.IdCuota
WHERE C.FechaEmision > DATEADD(DAY, -30, GETDATE())
  AND C.NumeroDeSocio IN ('SN-4118','SN-4116');

DELETE FROM app.Cuota
WHERE FechaEmision > DATEADD(DAY, -30, GETDATE())
  AND NumeroDeSocio IN ('SN-4118','SN-4116');

--Ejecutamos el SP
EXEC GenerarCuota

--Revisamos que genere registros
SELECT * FROM app.Cuota WHERE NumeroDeSocio IN ('SN-4118','SN-4116');
--Testeamos todas las cuotas generadas el dia de la fecha.
SELECT * FROM app.Cuota WHERE FechaEmision = CAST(GETDATE() AS DATE) 


--Este SP da por pagas las facturas de los clientes con pago automatico activo. Por ejemplo, generamos un debito automático del socio  SN-4004
INSERT INTO app.DebitoAutomatico (FechaVigencia, FechaFin, Tipo, NumeroTarjeta)
VALUES ('2025-01-01', '2026-01-01', 'Tarjeta', '1234');

UPDATE app.Socio 
SET IdDebitoAutomatico = DA.IdDebitoAutomatico
FROM app.DebitoAutomatico DA
WHERE NumeroTarjeta = '1234'
AND NumeroDeSocio = 'SN-4004';

EXEC PagoDebitoAutomatico
SELECT * FROM app.Pago ORDER BY FechaPago DESC

--Este SP genera una reserva de actividad. Debe ejecutarse una vez importados los socios y las clase actividades.
--Verificamos que exista la clase previamente
SELECT * FROM app.ClaseActividad WHERE IdActividad = 1 AND Fecha = '2025-03-03 00:00'
--Seteamos todas las cuotas morosas como pagadas (porque si se posee una cuota morosa NO se realizan las reservas)
UPDATE CM SET CM.Estado = 'PAG' FROM app.CuotaMorosa CM INNER JOIN app.Cuota C ON CM.IdCuota = C.IdCuota WHERE C.NumeroDeSocio = 'SN-4012'

EXEC GenerarReservaActDeportiva 	@IdSocio = 'SN-4012', 	@Actividad = 'Futsal', 	@Fecha = '2025-03-03 00:00';

SELECT * FROM app.ReservaActividad WHERE NumeroDeSocio = 'SN-4012';

--SP que genera una reserva a una actividad extra, a su vez, esta reserva genera una factura ya que debe abonarse en el momento para su uso.
--Tambien debe ejecutarse post importacion de actividades extras que se hace en el archivo 01.
EXEC GenerarReservaActExtra @IdSocio = 'SN-4012', 	@Actividad = 'Pileta verano', 	@Fecha = '2025-03-05 00:00';

SELECT * FROM app.ReservaActividad WHERE NumeroDeSocio = 'SN-4012';

--Sp que genera los reintegros por lluvia para que despues un trigger modifique el saldo de la cuenta para tenerlo como pago a cuenta.
EXEC GenerarReintegroPorLluvia;

SELECT * FROM app.Reintegro;

SELECT * FROM app.Descuento

--POST PRIMER DEFENSA

--Prueba de inscripcion de un socio nuevo
SELECT * FROM app.Inscripcion
--Bloque de insert
	DECLARE @FechaNacimiento DATE = '20030505'
	INSERT INTO app.Socio(NumeroDeSocio,Documento,Nombre,Apellido,FechaNacimiento,Estado,IdCategoriaSocio)
	VALUES ('SN-9004', '40000001', 'Quimey', 'Salinas', @FechaNacimiento, 'Activo',
			CASE  
				WHEN DATEDIFF(YEAR, @FechaNacimiento, GETDATE()) < 18 THEN COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Menor'), NULL)  
				WHEN DATEDIFF(YEAR, @FechaNacimiento, GETDATE()) BETWEEN 18 AND 25 THEN COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Cadete'), NULL)  
				ELSE COALESCE((SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Mayor'), NULL)  
			END )

SELECT * FROM app.Cuota WHERE NumeroDeSocio = 'SN-9004'


--Prueba de pago de una cuota:
INSERT INTO app.Pago(FechaPago,Estado,IdFactura,IdMedioPago)
VALUES(GETDATE(),'IMP',1433,5)

SELECT * FROM app.pago WHERE IdFactura = 1433
SELECT * FROM app.Cuota  

SELECT * FROM app.Factura WHERE IdCuota = 1584

