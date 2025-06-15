USE Com2900G04;

--REPORTE 1
-- Morosos Recurrentes

GO
CREATE OR ALTER PROCEDURE rep.MorososRecurrentes
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    -- Validación de fechas
    IF @FechaFin <= @FechaInicio
    BEGIN
        PRINT 'Error: La fecha de fin debe ser mayor que la de inicio.';
        RETURN;
    END;

    WITH Incumplimientos AS (
		SELECT
			s.NumeroDeSocio,
			s.Nombre,
			s.Apellido,
			DATEPART(mm, cm.Fecha) AS MesIncumplido,
			COUNT(*) OVER(PARTITION BY s.NumeroDeSocio) AS TotalIncumplimientos
		FROM app.CuotaMorosa cm
		INNER JOIN app.Cuota c ON cm.IdCuota = c.IdCuota
		INNER JOIN app.Socio s ON c.NumeroDeSocio = s.NumeroDeSocio
		WHERE cm.Fecha BETWEEN @FechaInicio AND @FechaFin
	),
	Morosidad(NroSocio,Nombre,Apellido,MesIncumplido,TotalIncumplimientos,RankingMorosidad) AS (
		SELECT 
			NumeroDeSocio,
			Nombre,
			Apellido,
			MesIncumplido,
			TotalIncumplimientos,
			RANK() OVER(ORDER BY TotalIncumplimientos DESC) RankingMorosidad
		FROM Incumplimientos
	)

    SELECT 
        CONCAT(@FechaInicio,' / ',@FechaFin) Periodo,
        NroSocio [Numero de socio],
        CONCAT(Nombre,' ',Apellido) [Nombre y apellido],
        MesIncumplido [Mes de incumplimiento]
    FROM Morosidad
    WHERE TotalIncumplimientos >= 2
    ORDER BY RankingMorosidad DESC
END

GO

--REPORTE 2
--Ingresos acumulados mensuales por clase deportiva 
--(No se incluyen recargos por morosidad ni descuentos aplicados a socios)
CREATE OR ALTER PROCEDURE rep.IngresosAcumuladosMensualesActividadDeportiva
AS
BEGIN
	WITH IngresosPorMes AS (
		SELECT 
			DATEPART(mm, r.Fecha) Mes,
			a.Nombre,
			a.Monto PrecioPorClase,
			a.IdActividad,
			COUNT(*) CantidadReservas,
			COUNT(*) * a.Monto IngresoMensual
		FROM app.Reserva r
		INNER JOIN app.ClaseActividad c ON r.IdClaseActividad = c.IdClaseActividad
		INNER JOIN app.ActividadDeportiva a ON c.IdActividad = a.IdActividad
		WHERE DATEPART(year, r.Fecha) = DATEPART(year, GETDATE()) -- Solo el año actual
		GROUP BY DATEPART(mm, r.Fecha), a.Nombre, a.Monto,a.IdActividad
	),
	IngresosAcumulados AS (
		SELECT 
			Mes,
			Nombre,
			PrecioPorClase,
			CantidadReservas,
			IngresoMensual,
			SUM(IngresoMensual) OVER(PARTITION BY Nombre ORDER BY Mes) AS IngresoAcumulado
		FROM IngresosPorMes
	)

	SELECT 
		FORMAT(DATEFROMPARTS(YEAR(GETDATE()), Mes, 1), 'MMMM', 'es-ES') AS Mes, 
		Nombre,
		PrecioPorClase [Precio por clase],
		CantidadReservas [Cantidad de reservas],
		--IngresoMensual [Ingreso mensual], Si se desea agregar
		IngresoAcumulado [Ingreso acumulado]
	FROM IngresosAcumulados
	ORDER BY Mes;
END


--REPORTE 3


--REPORTE 4
--socios que no han asistido a alguna clase de la actividad que realizan
GO
CREATE OR ALTER PROCEDURE rep.InasistenciasAClases 
AS
BEGIN
	SET NOCOUNT ON;

	SELECT
    s.Nombre,
    s.Apellido,
    DATEDIFF(YEAR, s.FechaNacimiento, GETDATE()) Edad,
    cs.nombre Categoria,
    ad.Nombre Actividad
	FROM app.Socio s
	JOIN app.CategoriaSocio cs ON s.IdCategoriaSocio = cs.idCategoriaSocio
	JOIN app.Reserva r ON r.NumeroDeSocio = s.NumeroDeSocio
	JOIN app.ClaseActividad ca ON r.IdClaseActividad = ca.IdClaseActividad
	JOIN app.ActividadDeportiva ad ON ca.IdActividad = ad.IdActividad
	WHERE r.Asistio = 0
	GROUP BY s.Nombre, s.Apellido, s.FechaNacimiento, cs.nombre, ad.Nombre;

END

