USE Com2900G04;
/*
Este archivo esta pensado para ejecutarse paso a paso por cada reporte, para ir viendo sus resultados.
*/
--Procederemos a visualizar los reportes realizados
--REPORTE 1
--Cargamos, para probar, que todas las cuotas que tengan fecha emision previa a la fecha actual, sean morosas:
INSERT INTO app.CuotaMorosa (Fecha, Estado, IdCuota)
SELECT FechaEmision, 'VEN', IdCuota
FROM app.Cuota
WHERE FechaEmision < GETDATE();

EXEC rep.MorososRecurrentes '2024-01-01', '2025-12-31'
--REPORTE 2
--Con lo ya cargado previamente en los juegos de prueba, se puede visualizar el reporte
EXEC rep.IngresosAcumuladosMensualesActividadDeportiva

--REPORTE 3
-- Para este reporte y el siguiente, habria primero que asignar a los socios sus categorias 
--Para probar haremos lo siguiente:
UPDATE s
SET IdCategoriaSocio =
    CASE 
        WHEN DATEDIFF(YEAR, s.FechaNacimiento, GETDATE()) < 18 THEN (SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Menor')
        WHEN DATEDIFF(YEAR, s.FechaNacimiento, GETDATE()) BETWEEN 18 AND 25 THEN (SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Cadete')
        ELSE (SELECT IdCategoriaSocio FROM app.CategoriaSocio WHERE Nombre = 'Mayor')
    END
FROM app.Socio s;
--Ahora si, ejecutamos los reportes:
EXEC rep.CantidadInasistencias

--REPORTE 4

EXEC rep.InasistenciasAClasesPorSocio