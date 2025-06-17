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
CREATE OR ALTER TRIGGER  tgr_GenerarUsuario
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
END

--Se crea un trigger que generará una factura cada vez que se genere una cuota
CREATE TRIGGER trg_GenerarFacturaPorCuota
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

--Creamos un trigger que va a cargar la tabla ItemFactura cada vez que se genera una factura.
CREATE TRIGGER CargaItemFactura
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

--Trigger que genera una factura por cada actividad generada
CREATE TRIGGER trg_GenerarFacturaPorReserva
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


--Trigger que genera una cuota cada vez que haya una inscripcion de un nuevo socio.
CREATE TRIGGER trg_PrimerCuota
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
	LEFT JOIN app.Descuento D ON i.NumeroDeSocio = D.NumeroDeSocio AND D.FechaVigencia <= GETDATE()
END;

--SP Que genera las cuotas siempre que el socio cumpla un mes mas
CREATE PROCEDURE GenerarCuota
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO app.Cuota (FechaEmision, MontoCuota, Recargo, MontoTotal, NumeroDeSocio)
		SELECT 
			GETDATE() AS FechaEmision,
			(CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0) + S.Saldo AS MontoCuota, --Se aplica el descuento si corresponde solo a la membresía. Ademas, se descuenta el monto de pago a cuenta. Por otro lado, tambien se suman las actividades
			((CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0) + S.Saldo) * 0.1 AS Recargo,
			(CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0 + S.Saldo) AS MontoTotal,
			S.NumeroDeSocio
		FROM app.Socio S 
		INNER JOIN app.CategoriaSocio CS ON S.IdCategoriaSocio = CS.IdCategoriaSocio
		INNER JOIN app.CostoMembresia CM ON CS.IdCategoriaSocio = CM.IdCategoriaSocio
		LEFT JOIN app.Descuento D ON S.NumeroDeSocio = D.NumeroDeSocio AND D.FechaVigencia <= GETDATE()
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
	WHERE S.Estado = 'Activo'
	AND S.NumeroDeSocio NOT IN (
		SELECT NumeroDeSocio 
		FROM app.Cuota 
		WHERE FechaEmision > DATEADD(DAY, -30, GETDATE())
	) 
	AND (CM.Monto - (CM.Monto * ISNULL(D.Porcentaje, 0)/100)) + ISNULL(AD.MontoActividades, 0) > ABS(S.Saldo)

END;

--SP que se ejecuta post ejecución del SP GenerarCuota que da por pagas las facturas de clientes adheridos al débito automático:
CREATE PROCEDURE PagoDebitoAutomatico
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO app.Pago(FechaPago, Estado, IdFactura, IdMedioPago)
	SELECT
		GETDATE(),
		'IMPU',
		F.IdFactura,
		DA.Tipo
	FROM app.DebitoAutomatico DA 
	INNER JOIN app.Socio S ON DA.IdDebitoAutomatico = S.IdDebitoAutomatico
	INNER JOIN app.Cuota C ON S.NumeroDeSocio = C.NumeroDeSocio
	INNER JOIN app.Factura F ON C.IdCuota = F.IdCuota
	WHERE F.Estado = 'PEN';
	
END;

--SP para generar reservas de actividades deportivas
CREATE PROCEDURE GenerarReservaActDeportiva
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
			AD.Monto + S.Saldo
		FROM
			app.ClaseActividad CA
		INNER JOIN
			app.ActividadDeportiva AD ON CA.IdActividad = AD.IdActividad AND AD.Nombre = @Actividad
		INNER JOIN
			app.Socio S = @IdSocio 
			AND AD.Monto > ABS(S.Saldo)
		WHERE
			CA.Fecha = @Fecha
			AND @IdSocio NOT IN		(SELECT C.NumeroDeSocio FROM app.Cuota C
									INNER JOIN app.CuotaMorosa CM ON C.IdCuota = CM.IdCuota
									WHERE CM.Estado = 'VEN') --Que el socio no tenga ninguna cuota vencida, si es así, no puede realizar la reserva.

END;

--SP que permite generar reservas de actividades extras, como pileta verano o alquiler de SUM
CREATE PROCEDURE GenerarReservaActExtra
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
			AE.Monto + S.Saldo
		FROM
			app.ClaseActividad CA
		INNER JOIN
			app.ActividadExtra AE ON CA.IdActividadExtra = AE.IdActividadExtra AND AE.Nombre = @Actividad
		INNER JOIN
			app.Socio S = @IdSocio 
			AND AE.Monto > ABS(S.Saldo)
		WHERE
			CA.Fecha = @Fecha
			AND @IdSocio NOT IN		(SELECT C.NumeroDeSocio FROM app.Cuota C
									INNER JOIN app.CuotaMorosa CM ON C.IdCuota = CM.IdCuota
									WHERE CM.Estado = 'VEN') --Que el socio no tenga ninguna cuota vencida, si es así, no puede realizar la reserva.

END;

--SP que genera el reintegro en caso de que haya llovido durante la jornada: Se ejecuta una vez al día:
CREATE PROCEDURE GenerarReintegroPorLluvia
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