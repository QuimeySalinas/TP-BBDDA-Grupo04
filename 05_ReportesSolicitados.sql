USE Com2900G04;

--REPORTE 1
-- Morosos Recurrentes

GO
CREATE OR ALTER PROCEDURE rep.MorososRecurrentes
    @FechaInicio DATE,
    @FechaFin DATE
AS
BEGIN
    -- Validaci�n de fechas
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
    -- 1. Identificamos socios únicos que participaron de cada actividad por mes
    WITH SociosUnicosPorMes AS (
        SELECT DISTINCT
            DATEPART(MONTH, r.Fecha) AS Mes,
            a.IdActividad,
            a.Nombre,
            a.Monto,
            r.NumeroDeSocio
        FROM app.ReservaActividad r
        INNER JOIN app.ClaseActividad c ON r.IdClaseActividad = c.IdClaseActividad
        INNER JOIN app.ActividadDeportiva a ON c.IdActividad = a.IdActividad
        WHERE 
            YEAR(r.Fecha) = YEAR(GETDATE())
            AND MONTH(r.Fecha) <= MONTH(GETDATE()) -- solo hasta el mes actual
    ),
    IngresosAcumulados AS (
        SELECT 
            IdActividad,
            Nombre,
            Monto,
            COUNT(DISTINCT CONCAT(NumeroDeSocio, Mes)) AS CantidadSociosMeses,
            COUNT(DISTINCT CONCAT(NumeroDeSocio, Mes)) * Monto AS IngresoAcumulado
        FROM SociosUnicosPorMes
        GROUP BY IdActividad, Nombre, Monto
    )

    SELECT 
        Nombre AS [Actividad],
        Monto AS [Monto mensual],
        CantidadSociosMeses AS [Inscripciones mensuales],
        IngresoAcumulado AS [Ingresos mensuales acumulados]
    FROM IngresosAcumulados
    ORDER BY Nombre;
END



--REPORTE 3:Reporte de la cantidad de socios que han realizado alguna actividad de forma alternada 
--(inasistencias) por categoría de socios y actividad, ordenado según cantidad de inasistencias
--ordenadas de mayor a menor.
GO
CREATE OR ALTER PROCEDURE rep.CantidadInasistencias
AS
BEGIN
	SET NOCOUNT ON;

		SELECT 
			CS.Nombre AS CategoriaSocio, 
			AD.Nombre AS ActividadDeportiva,
			COUNT(*) AS CantInasistencias
		FROM 
			app.ReservaActividad R
		INNER JOIN 
			app.Socio S ON R.NumeroDeSocio = S.NumeroDeSocio
		INNER JOIN 
			app.CategoriaSocio CS ON S.IdCategoriaSocio = CS.IdCategoriaSocio
		INNER JOIN 
			app.ClaseActividad CA ON R.IdclaseActividad = CA.IdclaseActividad
		INNER JOIN 
			app.ActividadDeportiva AD ON CA.IdActividad = AD.IdActividad
		WHERE 
			Asistencia IN ('A','J')--Que solo devuelva las A: Ausente y J: Ausente Justificado.
		GROUP BY 
			CS.Nombre, AD.Nombre
		ORDER BY 
			CantInasistencias DESC

END

--REPORTE 4: Reporte que contenga a los socios que no han asistido a alguna clase de la actividad que 
--realizan. El reporte debe contener: Nombre, Apellido, edad, categoría y la actividad 
GO
CREATE OR ALTER PROCEDURE rep.InasistenciasAClasesPorSocio
AS
BEGIN
	SET NOCOUNT ON;

		WITH SociosConReservas AS (
		SELECT 
			R.NumeroDeSocio,
			CA.IdActividad
		FROM 
			app.ReservaActividad R
		INNER JOIN 
			app.ClaseActividad CA ON R.IdClaseActividad = CA.IdClaseActividad
		GROUP BY 
			R.NumeroDeSocio, CA.IdActividad
	),--Devuelve las reservas generadas por los socios, sin discriminar aún por presentismo.
	SociosConPresente AS (
		SELECT 
			R.NumeroDeSocio,
			CA.IdActividad
		FROM 
			app.ReservaActividad R
		INNER JOIN 
			app.ClaseActividad CA ON R.IdClaseActividad = CA.IdClaseActividad
		WHERE 
			R.Asistencia = 'P'
		GROUP BY 
			R.NumeroDeSocio, CA.IdActividad
	)--Devuelve las reservas que terminaron con los socios presentes
	SELECT 
		S.Nombre,
		S.Apellido,
		DATEDIFF(YEAR, S.FechaNacimiento, GETDATE()) AS Edad,
		CS.Nombre AS Categoria,
		AD.Nombre AS Actividad
	FROM 
		SociosConReservas SCR
	LEFT JOIN 
		SociosConPresente SP ON SCR.NumeroDeSocio = SP.NumeroDeSocio AND SCR.IdActividad = SP.IdActividad
	INNER JOIN 
		app.Socio S ON S.NumeroDeSocio = SCR.NumeroDeSocio
	INNER JOIN 
		app.CategoriaSocio CS ON S.IdCategoriaSocio = CS.IdCategoriaSocio
	INNER JOIN 
		app.ActividadDeportiva AD ON SCR.IdActividad = AD.IdActividad
	WHERE 
		SP.NumeroDeSocio IS NULL --Si el socio es NULL es porque no encontró coincidencias, por ende, significa que no asistió a ninguna de esas clases
	ORDER BY 
		AD.Nombre, S.Apellido, S.Nombre;

END

