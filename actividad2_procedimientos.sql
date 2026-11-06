/* ============================================================
   PA3 - Actividad 2: Procedimientos almacenados de mantenimiento
   Curso: Programación Avanzada de Base de Datos (30627)
   Base: PA3_NovaMarket (ejecutar antes 00_esquema_y_datos_base.sql)

   Lógica cliente/servidor: la aplicación cliente (en el curso, SSMS)
   solo envía los datos con EXEC. El servidor valida, graba y devuelve
   el resultado con un valor de retorno (RETURN) y, cuando aplica,
   con un parámetro de salida (OUTPUT). Así todas las aplicaciones
   aplican las mismas reglas.
   ============================================================ */

USE PA3_NovaMarket;
GO

/* ------------------------------------------------------------
   0) Listar clientes registrados (consulta de apoyo)
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Registrados
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ClienteID, Documento, Nombre, Ciudad, Correo, Telefono, Activo
    FROM dbo.Cliente
    ORDER BY ClienteID;
END;
GO

/* ------------------------------------------------------------
   1) Registrar un cliente nuevo
   Parámetros de entrada:
     @Documento  DNI del cliente; no se puede repetir
     @Nombre     nombre completo
     @Ciudad     ciudad de residencia
     @Correo     opcional
     @Telefono   opcional
   Parámetro de salida:
     @ClienteID  ID generado para el cliente nuevo (NULL si no se registró)
   Valor de retorno:
     0 = registrado
     1 = el documento ya existe
     2 = faltan datos obligatorios
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dbo.usp_Registrar_Cliente_Nuevo
    @Documento  VARCHAR(15),
    @Nombre     VARCHAR(100),
    @Ciudad     VARCHAR(50),
    @Correo     VARCHAR(100) = NULL,
    @Telefono   VARCHAR(20)  = NULL,
    @ClienteID  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @ClienteID = NULL;

    IF @Documento IS NULL OR @Nombre IS NULL OR @Ciudad IS NULL
    BEGIN
        PRINT 'No se registró: faltan datos obligatorios.';
        RETURN 2;
    END;

    IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE Documento = @Documento)
    BEGIN
        PRINT 'No se registró: ya existe un cliente con ese documento.';
        RETURN 1;
    END;

    INSERT INTO dbo.Cliente (Documento, Nombre, Ciudad, Correo, Telefono)
    VALUES (@Documento, @Nombre, @Ciudad, @Correo, @Telefono);

    SET @ClienteID = SCOPE_IDENTITY();
    PRINT 'Cliente registrado.';
    RETURN 0;
END;
GO

/* ------------------------------------------------------------
   2) Actualizar correo y/o teléfono de un cliente
   Parámetros de entrada:
     @ClienteID  cliente a actualizar
     @Correo     nuevo correo (si va NULL, se mantiene el actual)
     @Telefono   nuevo teléfono (si va NULL, se mantiene el actual)
   Valor de retorno:
     0 = actualizado
     1 = el cliente no existe
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dbo.usp_Actualizar_Datos_Clientes
    @ClienteID  INT,
    @Correo     VARCHAR(100) = NULL,
    @Telefono   VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID)
    BEGIN
        PRINT 'No se actualizó: el cliente no existe.';
        RETURN 1;
    END;

    UPDATE dbo.Cliente
    SET Correo   = COALESCE(@Correo, Correo),
        Telefono = COALESCE(@Telefono, Telefono)
    WHERE ClienteID = @ClienteID;

    PRINT 'Cliente actualizado.';
    RETURN 0;
END;
GO

/* ------------------------------------------------------------
   3) Eliminar un cliente
   Solo se elimina si no tiene pedidos; un cliente con historial
   de compras no se puede borrar porque se perderían las ventas.
   Parámetro de entrada:
     @ClienteID  cliente a eliminar
   Valor de retorno:
     0 = eliminado
     1 = el cliente no existe
     2 = tiene pedidos, no se puede eliminar
   ------------------------------------------------------------ */
CREATE OR ALTER PROCEDURE dbo.usp_Eliminar_Cliente_ID
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID)
    BEGIN
        PRINT 'No se eliminó: el cliente no existe.';
        RETURN 1;
    END;

    IF EXISTS (SELECT 1 FROM dbo.Pedido WHERE ClienteID = @ClienteID)
    BEGIN
        PRINT 'No se eliminó: el cliente tiene pedidos registrados.';
        RETURN 2;
    END;

    DELETE FROM dbo.Cliente WHERE ClienteID = @ClienteID;

    PRINT 'Cliente eliminado.';
    RETURN 0;
END;
GO


/* ============================================================
   CASOS DE PRUEBA
   Cada EXEC guarda el valor de retorno en @Resultado y lo muestra.
   ============================================================ */

-- Estado inicial
EXEC dbo.usp_Clientes_Registrados;
GO

-- Caso 1: alta correcta -> Resultado 0 y ClienteID 11
DECLARE @Resultado INT, @NuevoID INT;
EXEC @Resultado = dbo.usp_Registrar_Cliente_Nuevo
     @Documento = '70100011', @Nombre = 'Ana María Rengifo', @Ciudad = 'Lima',
     @Correo = 'ana.maria@correo.pe', @Telefono = '987100011',
     @ClienteID = @NuevoID OUTPUT;
SELECT 'Alta correcta' AS Caso, @Resultado AS Resultado, @NuevoID AS ClienteID;
GO

-- Caso 2: alta con documento repetido -> Resultado 1 y ClienteID NULL
DECLARE @Resultado INT, @NuevoID INT;
EXEC @Resultado = dbo.usp_Registrar_Cliente_Nuevo
     @Documento = '70100001', @Nombre = 'Ana Duplicada', @Ciudad = 'Lima',
     @ClienteID = @NuevoID OUTPUT;
SELECT 'Documento repetido' AS Caso, @Resultado AS Resultado, @NuevoID AS ClienteID;
GO

-- Caso 3: actualizar el correo del cliente 3 (no tenía) -> Resultado 0
DECLARE @Resultado INT;
EXEC @Resultado = dbo.usp_Actualizar_Datos_Clientes
     @ClienteID = 3, @Correo = 'bertha.quispe@correo.pe';
SELECT 'Actualizar cliente 3' AS Caso, @Resultado AS Resultado;
SELECT ClienteID, Nombre, Correo, Telefono FROM dbo.Cliente WHERE ClienteID = 3;
GO

-- Caso 4: actualizar un cliente que no existe -> Resultado 1
DECLARE @Resultado INT;
EXEC @Resultado = dbo.usp_Actualizar_Datos_Clientes
     @ClienteID = 99, @Telefono = '900000000';
SELECT 'Actualizar cliente 99' AS Caso, @Resultado AS Resultado;
GO

-- Caso 5: eliminar un cliente con pedidos (cliente 1) -> Resultado 2, no se borra
DECLARE @Resultado INT;
EXEC @Resultado = dbo.usp_Eliminar_Cliente_ID @ClienteID = 1;
SELECT 'Eliminar cliente 1' AS Caso, @Resultado AS Resultado;
GO

-- Caso 6: eliminar el cliente recién creado (sin pedidos) -> Resultado 0
--         Se busca por su documento, así funciona aunque el ID no sea 11
--         (el IDENTITY no reutiliza números si el script ya se corrió antes).
DECLARE @Resultado INT, @IdNuevo INT;
SELECT @IdNuevo = ClienteID FROM dbo.Cliente WHERE Documento = '70100011';
EXEC @Resultado = dbo.usp_Eliminar_Cliente_ID @ClienteID = @IdNuevo;
SELECT 'Eliminar cliente nuevo' AS Caso, @IdNuevo AS ClienteID, @Resultado AS Resultado;
GO

-- Estado final: el cliente 3 tiene correo y el nuevo ya no existe
EXEC dbo.usp_Clientes_Registrados;
GO
