USE Com2900G04;
--agregamos un trigger en el cual convertimos en hash las contrasenas de los usuarios:

GO
CREATE OR ALTER TRIGGER app.HashContrasena
ON app.Usuario
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE u
    SET 
        u.ContrasenaHash = HASHBYTES('SHA2_256', CONVERT(NVARCHAR(100), i.Contrasena)),
        u.Contrasena = NULL
    FROM app.Usuario u
    INNER JOIN inserted i ON u.IdUsuario = i.IdUsuario;
END;
--Trigger para Generar un usuario default para cuando se cree un socio nuevo
GO
--Trigger para generar una inscripcion en cada socio nuevo:
CREATE OR ALTER TRIGGER app.tgr_GenerarInscripcion
ON app.Socio
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO app.Inscripcion(Fecha,Estado,NumeroDeSocio)
	SELECT
		CAST(GETDATE() AS DATE),
		'ACT', --Puede ser Activo, Pendiente o Cancelada
		i.NumeroDeSocio
	FROM inserted i;
END;

GO
CREATE OR ALTER TRIGGER  app.tgr_GenerarUsuario
ON app.Socio
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
	--Como la contrasena esta generada de manera default, se debe cambiar y por ende la fecha de vigencia sera
	--Una semana despues de su creacion
	--Como este trigger es para usuarios de socios, el Rol siempre sera 'Socio'
	--Asignaremos una contrasena default (para cada socio) para que se ingrese en primera instancia con esa
	INSERT INTO app.Usuario (FechaVigenciaContrasena, Rol, Usuario, Contrasena, NumeroDeSocio)
	SELECT 
		DATEADD(WEEK, 1, GETDATE()),  -- Una semana despu�s de la creaci�n
		'Socio', 
		i.Nombre, 
		CONCAT(i.NumeroDeSocio, i.Documento), 
		i.NumeroDeSocio
	FROM inserted i;
END;
GO
--Se crea un trigger que generará una factura cada vez que se genere una cuota
CREATE OR ALTER TRIGGER app.trg_GenerarFacturaPorCuota
ON app.Cuota
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO app.Factura (Tipo, FechaFacturacion, PrimerVencimiento, SegundoVencimiento, Estado, idCuota)
    SELECT 
		'Factura',
        i.FechaEmision,
        DATEADD(DAY, 5, i.FechaEmision) AS PrimerVto,
        DATEADD(DAY, 10, i.FechaEmision) AS SegundoVto,
		'PEN',
		i.idCuota
    FROM inserted i;
END;
GO
--Creamos un trigger que va a cargar la tabla ItemFactura cada vez que se genera una factura.
CREATE OR ALTER TRIGGER app.CargaItemFactura
ON app.Factura
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
		--Inserta si es una factura creada por una reserva de actividad
		INSERT INTO app.ItemFactura(Descripcion, Cantidad, PrecioUnitario,IdFactura)
		SELECT 
			'Reserva actividad',
			1,
			a.Monto,
			i.IdFactura
		FROM inserted i 
		INNER JOIN app.ReservaActividad a ON i.IdReserva = a.IdReserva
		WHERE i.idCuota IS NULL;
		
		--Inserta si es una factura creada por una cuota.
		INSERT INTO app.ItemFactura(Descripcion, Cantidad, PrecioUnitario,IdFactura)
		SELECT 
			'Cuota',
			1,
			a.MontoTotal,
			i.IdFactura
		FROM inserted i 
		INNER JOIN app.Cuota a ON i.IdCuota = a.IdCuota
		WHERE i.idCuota IS NOT NULL;

		--Inserta si es una Nota de crédito generada por una devolución.
		INSERT INTO app.ItemFactura(Descripcion, Cantidad, PrecioUnitario,IdFactura)
		SELECT 
			'Cuota',
			1,
			D.MontoTotal,
			i.IdFactura
		FROM inserted i 
		INNER JOIN app.Pago P ON i.IdFactura = P.IdFactura
		INNER JOIN app.Devolucion D ON P.IdPago = D.IdPago
		WHERE i.Tipo = 'Nota de credito';
END
GO
--Trigger que genera una factura por cada actividad generada
CREATE OR ALTER TRIGGER app.trg_GenerarFacturaPorReserva
ON app.ReservaActividad
AFTER INSERT 
AS
BEGIN
	SET NOCOUNT ON;
		INSERT INTO app.Factura (Tipo, FechaFacturacion, PrimerVencimiento, SegundoVencimiento, Estado, IdCuota, IdReserva)
		SELECT 
			'Factura',
			CONVERT(DATE, i.Fecha) AS Fecha,
			DATEADD(DAY, 5, CONVERT(DATE, i.Fecha)) AS PrimerVto,
			DATEADD(DAY, 10, CONVERT(DATE, i.Fecha)) AS SegundoVto,
			'PEN',
			NULL,
			i.IdReserva
		FROM 
			inserted i
		INNER JOIN
			app.ClaseActividad CA ON i.IdClaseActividad = CA.IdClaseActividad
		WHERE
			CA.IdActividadExtra IS NOT NULL; --Solo genera factura al momento si la reserva es por una actividad extra.
		
END;
GO
--Se crea un trigger que modifica el estado de la factura siempre que entre un pago
CREATE OR ALTER TRIGGER app.trg_ModificarEstadoFactura
ON app.Pago
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE app.Factura 
	SET Estado = 'PAG'
	FROM app.Factura A
	INNER JOIN inserted B on A.IdFactura = B.IdFactura

	--Modificamos el estado en la tabla CuotaMorosa en caso de que se aplique un pago a una cuota vencida:
	UPDATE CM
	SET CM.Estado = 'PAG'
	FROM app.CuotaMorosa CM
	INNER JOIN app.Cuota C ON CM.IdCuota = C.IdCuota
	INNER JOIN app.Factura F ON C.IdCuota = F.IdCuota
	INNER JOIN inserted I ON F.IdFactura = I.IdFactura
	WHERE CM.Estado = 'VEN'
END;

GO
--Trigger que genera una cuota cada vez que haya una inscripcion de un nuevo socio.
CREATE OR ALTER TRIGGER app.trg_PrimeraCuota
ON app.Socio
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO app.Cuota (FechaEmision, MontoCuota, Recargo, MontoTotal, NumeroDeSocio)
	SELECT
	GETDATE(),
	(CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) AS MontoCuota, --Se define el valor de la cuota
	(CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) * 0.1 AS MontoRecargo, --Se carga el campo recargo
	(CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) AS MontoTotal, --Inicialmente, el valor de la cuota total sera igual que el valor de la cuota
	i.NumeroDeSocio
	FROM inserted i
	INNER JOIN app.CategoriaSocio CS ON i.IdCategoriaSocio = CS.IdCategoriaSocio
	INNER JOIN app.CostoMembresia CM ON CS.iDCategoriaSocio = CM.iDCategoriaSocio 
	AND  CM.fecha = (SELECT MAX(fecha) FROM app.CostoMembresia WHERE IdCategoriaSocio = CS.IdCategoriaSocio AND fecha <= GETDATE() GROUP BY IdCategoriaSocio) --Que agarre la fecha mas alta
	LEFT JOIN app.Descuento D ON i.NumeroDeSocio = D.NumeroDeSocio 
	AND D.FechaVigencia = (SELECT MAX(FechaVigencia) FROM app.Descuento WHERE NumeroDeSocio = D.NumeroDeSocio AND FechaVigencia <= GETDATE() GROUP BY NumeroDeSocio)--Que agarre el último descuento disponible
END;
GO
--Trigger que modifica el campo Saldo del cliente una vez que se genera un reintegro
CREATE OR ALTER TRIGGER app.trg_ModificarSaldoACuenta
ON app.Reintegro
AFTER INSERT 
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO app.Saldo(Fecha,Monto,NumeroDeSocio,Estado)
	SELECT I.Fecha, I.Monto, S.NumeroDeSocio, 'PEN'
	FROM inserted I 
	INNER JOIN app.ClaseActividad CA ON I.IdClaseActividad = CA.IdClaseActividad
	INNER JOIN app.ReservaActividad RA ON CA.IdClaseActividad = RA.IdClaseActividad
	INNER JOIN app.Socio S ON RA.NumeroDeSocio = S.NumeroDeSocio AND I.Estado = 'PEN'
	INNER JOIN app.Saldo SA ON SA.NumeroDeSocio = S.NumeroDeSocio

	UPDATE R
	SET R.Estado = 'FIN'
	FROM app.Reintegro R 
	WHERE R.Estado = 'PEN'

END;
GO
--Trigger que modifica el estado del pago cuando se genere una devolucion:
CREATE OR ALTER TRIGGER app.ModifEstadoPago
ON app.Devolucion
AFTER INSERT
AS 
BEGIN
	SET NOCOUNT ON;
	UPDATE app.Pago
	SET Estado = 'ANU'
	FROM inserted i 
	INNER JOIN app.Pago C on i.IdPago = C.IdPAgo
END
GO
--SP Que genera las cuotas siempre que el socio cumpla un mes mas
CREATE OR ALTER PROCEDURE GenerarCuota
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @NumSoc CHAR(7)

	INSERT INTO app.Cuota (FechaEmision, MontoCuota, Recargo, MontoTotal, NumeroDeSocio)
		SELECT 
			GETDATE() AS FechaEmision,
			(CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0) + ISNULL(SA.Monto,0) AS MontoCuota, --Se aplica el descuento si corresponde solo a la membresía. Ademas, se descuenta el monto de pago a cuenta. Por otro lado, tambien se suman las actividades
			((CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0) + ISNULL(SA.Monto,0)) * 0.1 AS Recargo,
			(CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0 + ISNULL(SA.Monto,0)) AS MontoTotal,
			S.NumeroDeSocio
		FROM app.Socio S 
		INNER JOIN app.CategoriaSocio CS ON S.IdCategoriaSocio = CS.IdCategoriaSocio
		INNER JOIN app.CostoMembresia CM ON CS.IdCategoriaSocio = CM.IdCategoriaSocio
		AND  CM.fecha = (SELECT MAX(fecha) FROM app.CostoMembresia WHERE IdCategoriaSocio = CS.IdCategoriaSocio AND fecha <= GETDATE() GROUP BY IdCategoriaSocio) --Que agarre la fecha mas alta
		LEFT JOIN app.Descuento D ON S.NumeroDeSocio = D.NumeroDeSocio 
		AND D.FechaVigencia = (SELECT MAX(FechaVigencia) FROM app.Descuento WHERE NumeroDeSocio = D.NumeroDeSocio AND FechaVigencia <= GETDATE() GROUP BY NumeroDeSocio)
		LEFT JOIN (
		-- Subconsulta que trae la suma de actividades distintas por socio. Ejemplo, actividad 1 tiene x reservas, la actividad vale x entonces lo trae. Otra actividad 2 tiene x reservas, esa actividad vale y y suma y+x
		SELECT 
			RA.NumeroDeSocio, 
			SUM(DISTINCT AD.Monto) AS MontoActividades
		FROM app.ReservaActividad RA
		INNER JOIN app.ClaseActividad CA ON RA.IdClaseActividad = CA.IdClaseActividad
		INNER JOIN app.ActividadDeportiva AD ON CA.IdActividad = AD.IdActividad
		WHERE RA.Fecha > DATEADD(DAY, -30, GETDATE())
		GROUP BY RA.NumeroDeSocio
	) AD ON S.NumeroDeSocio = AD.NumeroDeSocio
	LEFT JOIN app.Saldo SA ON S.NumeroDeSocio = SA.NumeroDeSocio AND SA.Estado = 'PEN'
	WHERE S.Estado = 'Activo'
	AND S.NumeroDeSocio NOT IN (
		SELECT NumeroDeSocio 
		FROM app.Cuota 
		WHERE FechaEmision > DATEADD(DAY, -30, GETDATE())
	) 
	AND (CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0) > ABS(ISNULL(SA.Monto, 0))

END;
GO
CREATE OR ALTER TRIGGER app.ModifEstadoSaldo
ON app.Cuota
AFTER INSERT
AS 
BEGIN
	SET NOCOUNT ON;
	UPDATE S
	SET S.Estado = 'FIN'
	FROM inserted i 
	INNER JOIN app.Saldo S on i.NumeroDeSocio = S.NumeroDeSocio
	WHERE S.Estado = 'PEN'
END
GO
--SP que se ejecuta post ejecución del SP GenerarCuota que da por pagas las facturas de clientes adheridos al débito automático:
CREATE OR ALTER PROCEDURE PagoDebitoAutomatico
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO app.Pago(FechaPago, Estado, IdFactura, IdMedioPago)
	SELECT
		GETDATE(),
		'IMP',
		F.IdFactura,
		MP.IdMedioPago
	FROM app.DebitoAutomatico DA 
	INNER JOIN app.Socio S ON DA.IdDebitoAutomatico = S.IdDebitoAutomatico
	INNER JOIN app.Cuota C ON S.NumeroDeSocio = C.NumeroDeSocio
	INNER JOIN app.Factura F ON C.IdCuota = F.IdCuota
	INNER JOIN app.MedioPago MP ON MP.Descripcion = DA.Tipo
	WHERE F.Estado = 'PEN';
	
END;
GO
--SP para generar reservas de actividades deportivas
CREATE OR ALTER PROCEDURE GenerarReservaActDeportiva
@IdSocio CHAR(7),
@Actividad CHAR(20),
@Fecha DATETIME
AS
BEGIN
	SET NOCOUNT ON;

		INSERT INTO app.ReservaActividad (Fecha, NumeroDeSocio, IdClaseActividad, Monto)
		SELECT
			GETDATE(),
			@IdSocio,
			CA.IdClaseActividad,
			AD.Monto + ISNULL(SA.Monto,0)
		FROM
			app.ClaseActividad CA
		INNER JOIN
			app.ActividadDeportiva AD ON CA.IdActividad = AD.IdActividad AND AD.Nombre = @Actividad
		AND
			AD.FechaVigencia =	(SELECT MAX(FechaVigencia) FROM app.ActividadDeportiva WHERE Nombre = AD.Nombre 
								AND FechaVigencia < GETDATE() GROUP BY Nombre)
		INNER JOIN
			app.Socio S ON S.NumeroDeSocio= @IdSocio 
		LEFT JOIN app.Saldo SA ON SA.NumeroDeSocio = S.NumeroDeSocio AND SA.Estado = 'PEN'
		WHERE
			CA.Fecha = @Fecha
			AND @IdSocio NOT IN		(SELECT C.NumeroDeSocio FROM app.Cuota C
									INNER JOIN app.CuotaMorosa CM ON C.IdCuota = CM.IdCuota
									WHERE CM.Estado = 'VEN') --Que el socio no tenga ninguna cuota vencida, si es así, no puede realizar la reserva.

END;
GO
CREATE OR ALTER TRIGGER app.ModifEstadoSaldoRes
ON app.ReservaActividad
AFTER INSERT
AS 
BEGIN
	SET NOCOUNT ON;
	UPDATE S
	SET S.Estado = 'FIN'
	FROM inserted i 
	INNER JOIN app.Saldo S on i.NumeroDeSocio = S.NumeroDeSocio
	WHERE S.Estado = 'PEN'
END
GO
--SP que permite generar reservas de actividades extras, como pileta verano o alquiler de SUM
CREATE OR ALTER PROCEDURE GenerarReservaActExtra
@IdSocio CHAR(7),
@Actividad CHAR(20),
@Fecha DATETIME
AS
BEGIN
	SET NOCOUNT ON;

		INSERT INTO app.ReservaActividad (Fecha, NumeroDeSocio, IdClaseActividad, Monto)
		SELECT
			GETDATE(),
			@IdSocio,
			CA.IdClaseActividad,
			AE.Monto + SA.Monto
		FROM
			app.ClaseActividad CA
		INNER JOIN
			app.ActividadExtra AE ON CA.IdActividadExtra = AE.IdActividadExtra AND AE.Nombre = @Actividad
		AND
			AE.FechaVigencia =	(SELECT MAX(FechaVigencia) FROM app.ActividadDeportiva WHERE Nombre = AE.Nombre 
								AND FechaVigencia <= GETDATE() GROUP BY Nombre)
		INNER JOIN
			app.Socio S ON S.NumeroDeSocio = @IdSocio 
		LEFT JOIN app.Saldo SA ON S.NumeroDeSocio = SA.NumeroDeSocio AND SA.Estado = 'PEN'
			AND AE.Monto > ABS(SA.Monto)
		WHERE
			CA.Fecha = @Fecha
			AND @IdSocio NOT IN		(SELECT C.NumeroDeSocio FROM app.Cuota C
									INNER JOIN app.CuotaMorosa CM ON C.IdCuota = CM.IdCuota
									WHERE CM.Estado = 'VEN') --Que el socio no tenga ninguna cuota vencida, si es así, no puede realizar la reserva.

END;
GO
--SP que genera el reintegro en caso de que haya llovido durante la jornada: Se ejecuta una vez al día:
CREATE OR ALTER PROCEDURE GenerarReintegroPorLluvia
AS
BEGIN
	SET NOCOUNT ON;
		
		INSERT INTO app.Reintegro (Estado, Fecha, IdClaseActividad, Monto)
		SELECT
			'PEN',
			GETDATE(),
			CA.IdClaseActividad,
			COALESCE(-(AD.Monto * 0.6), -(AE.Monto * 0.6)) --Se ingresa el registro con un monto del 60% del valor de la actividad realizada
		FROM
			app.ClaseActividad CA 
		INNER JOIN
			app.Clima C ON CA.IdClima = C.IdClima
		LEFT JOIN
			app.ActividadDeportiva AD ON CA.IdActividad = AD.IdActividad
		LEFT JOIN 
			app.ActividadExtra AE ON CA.IdActividadExtra = AE.IdActividadExtra
		WHERE
			C.Lluvia > 0
			AND COALESCE(AD.Monto, AE.Monto) IS NOT NULL --Que siempre inserte un monto.
END;
GO
--Creamos un SP que genera un devolución en el caso de que se requiera:
CREATE OR ALTER PROCEDURE GenerarDevolucion
@idPago INT
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO app.Devolucion(MontoTotal, FechaDevolucion, Estado, IdPago)
	SELECT
		-(C.MontoTotal),
		GETDATE(),
		'PEN',
		P.IdPago
	FROM app.Pago P 
		INNER JOIN app.Factura F ON P.IdFactura = F.IdFactura AND P.IDPago = @idPago
		INNER JOIN app.Cuota C ON F.IdCuota = C.IdCuota
END;
GO
GO
--SP Que procesa las devoluciones, generando Notas de Crédito. Se ejecuta despues de GenerarDevolucion:
CREATE OR ALTER PROCEDURE ProcesarDevolucion
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO app.Factura (Tipo, FechaFacturacion, PrimerVencimiento, SegundoVencimiento, Estado, idCuota)
    SELECT 
		'Nota de credito',
        GETDATE(),
        DATEADD(DAY, 5,GETDATE()) AS PrimerVto,
        DATEADD(DAY, 10, GETDATE()) AS SegundoVto,
		'PAG',
		C.IdCuota
	FROM 
		app.Devolucion D 
		INNER JOIN app.Pago P ON D.IdPago = P.IdPago
		INNER JOIN app.Factura F ON P.IdFactura = F.IdFactura
		INNER JOIN app.Cuota C ON F.IdCuota = C.IdCuota
	WHERE
		D.Estado = 'PEN'
	
	--Modificamos el estado de la devolución para que no se siga procesando en el futuro
	UPDATE app.Devolucion
	SET Estado = 'DEV'
	WHERE Estado = 'PEN'
END;
GO
--SP que se ejecuta una vez al día y monitorea el estado de la cuota. En caso de que este vencida, modifica el campo MontoTotal para sumarle el recargo
--Y actualiza el estado de la factura.
CREATE OR ALTER PROCEDURE RevisionFacturaVencida
AS
BEGIN
	--Actualizamos el precio de la Cuota y le sumamos el Recargo.
	UPDATE C
	SET C.MontoTotal = C.MontoCuota + Recargo
	FROM app.Cuota C 
	INNER JOIN app.Factura F ON C.IdCuota = F.IdCuota
	WHERE F.SegundoVencimiento < GETDATE()
	AND F.Estado = 'PEN'

	--Actualizamos el estado de la Factura a Vencida:
	UPDATE app.Factura
	SET Estado = 'VEN'
	WHERE SegundoVencimiento < GETDATE()
	AND Estado = 'PEN' --Estado Impaga
END;
GO
--SP que carga la tabla DeudaMorosa en caso de que haya alguna factura vencida:
CREATE OR ALTER PROCEDURE MonitorDeDeuda 
AS  
BEGIN  
    INSERT INTO app.CuotaMorosa (Fecha, IdCuota)
	SELECT
		GETDATE(),
		IdCuota
		FROM app.Factura F
		WHERE F.Estado = 'VEN'
		AND NOT EXISTS(SELECT 1 FROM app.CuotaMorosa WHERE IdCuota = F.IdCuota)
END;

GO
CREATE OR ALTER PROCEDURE ops.EstablecerParentesco
	@NroSocio CHAR(7),
	@NroSocioResp CHAR(7)
AS
BEGIN
	SET NOCOUNT ON;
	IF @NroSocioResp NOT IN(SELECT NumeroDeSocioResponsable FROM app.GrupoFamiliar)
	BEGIN --El socio responsable aun no tiene grupo a cargo -> debe crearse
		INSERT INTO app.GrupoFamiliar(FechaCreacion,Estado,NombreFamilia,NumeroDeSocioResponsable)
		SELECT
			GETDATE(),
			'Activo', 
			CONCAT('Grupo de ', Apellido COLLATE Latin1_General_CI_AI),
			@NroSocioResp
		FROM app.Socio
		WHERE NumeroDeSocio = @NroSocioResp
	END;

	--Exista o no el grupo previamente, se debe establecer el parentesco, por ende:
	UPDATE app.Socio
	SET IdGrupoFamiliar = (SELECT TOP 1 IdGrupoFamiliar FROM app.GrupoFamiliar WHERE NumeroDeSocioResponsable = @NroSocioResp ORDER BY FechaCreacion DESC)
	WHERE NumeroDeSocio = @NroSocio
	
END;