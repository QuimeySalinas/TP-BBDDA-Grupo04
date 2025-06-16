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
		DATEADD(WEEK, 1, GETDATE()),  -- Una semana después de la creación
		'Socio', 
		i.Nombre, 
		CONCAT(i.NumeroDeSocio, i.Documento), 
		i.NumeroDeSocio
	FROM inserted i;
END