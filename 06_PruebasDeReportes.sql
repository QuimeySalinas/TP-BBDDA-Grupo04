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

EXEC rep.CantidadInasistencias

--REPORTE 4

EXEC rep.InasistenciasAClasesPorSocio