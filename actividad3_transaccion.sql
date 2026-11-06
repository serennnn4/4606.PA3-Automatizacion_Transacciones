/* ============================================================
   PA3 - Actividad 3: Operación transaccional
   Curso: Programación Avanzada de Base de Datos (30627)
   Base: PA3_NovaMarket (ejecutar antes 00_esquema_y_datos_base.sql)

   Procedimiento: usp_RegistrarPedido
   Registra un pedido de hasta 2 productos como UNA sola unidad:
   cabecera, líneas de detalle y descuento de stock. Si algo falla
   a mitad del proceso, se cancela todo con ROLLBACK.

   Contrato definido en la Actividad 1:
     Entradas: @ClienteID, @Canal, @ProductoID1, @Cantidad1,
               @ProductoID2, @Cantidad2 (el segundo producto es opcional)
     Salida:   @PedidoID OUTPUT (NULL si no se registró)
     RETURN:   0 = registrado
               1 = cliente no válido (no existe o está inactivo)
               2 = producto no válido (no existe o está inactivo)
               3 = stock insuficiente (se cancela la transacción)
               4 = datos incompletos (canal inválido, cantidad <= 0,
                   sin productos o el mismo producto repetido)
   ============================================================ */

USE PA3_NovaMarket;
GO

-- Se elimina la versión anterior con prefijo sp_ (ese prefijo lo usa
-- SQL Server para sus procedimientos del sistema; por eso usamos usp_)
IF OBJECT_ID('dbo.sp_RegistrarPedido', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_RegistrarPedido;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RegistrarPedido
    @ClienteID    INT,
    @Canal        VARCHAR(30),
    @ProductoID1  INT,
    @Cantidad1    INT,
    @ProductoID2  INT = NULL,
    @Cantidad2    INT = NULL,
    @PedidoID     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    -- Si ocurre un error inesperado dentro de la transacción (por ejemplo,
    -- una restricción violada), SQL Server cancela toda la transacción.
    SET XACT_ABORT ON;
    SET @PedidoID = NULL;

    /* --------------------------------------------------------
       1. VALIDACIONES PREVIAS (no abren transacción)
       -------------------------------------------------------- */

    -- Cliente existe y está activo
    IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteID = @ClienteID AND Activo = 1)
    BEGIN
        PRINT 'Cancelado: el cliente no existe o está inactivo.';
        RETURN 1;
    END;

    -- Canal válido y cantidades correctas
    IF @Canal IS NULL OR @Canal NOT IN ('Web', 'Tienda', 'WhatsApp', 'Teléfono')
       OR @ProductoID1 IS NULL OR @Cantidad1 IS NULL OR @Cantidad1 <= 0
       OR (@ProductoID2 IS NOT NULL AND (@Cantidad2 IS NULL OR @Cantidad2 <= 0))
       OR (@ProductoID2 = @ProductoID1)
    BEGIN
        PRINT 'Cancelado: datos incompletos o inválidos.';
        RETURN 4;
    END;

    -- Cada producto existe y está activo
    IF NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE ProductoID = @ProductoID1 AND Activo = 1)
       OR (@ProductoID2 IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Producto WHERE ProductoID = @ProductoID2 AND Activo = 1))
    BEGIN
        PRINT 'Cancelado: algún producto no existe o está inactivo.';
        RETURN 2;
    END;

    /* --------------------------------------------------------
       2. TRANSACCIÓN EXPLÍCITA
       El stock se valida DENTRO de la transacción: el UPDATE solo
       descuenta si hay unidades suficientes. Si no afecta ninguna
       fila (@@ROWCOUNT = 0), se deshace todo lo hecho antes:
       la cabecera, las líneas y el stock ya descontado.
       -------------------------------------------------------- */
    BEGIN TRANSACTION;

    -- Paso A: cabecera del pedido
    INSERT INTO dbo.Pedido (ClienteID, FechaPedido, Estado, Canal)
    VALUES (@ClienteID, CAST(GETDATE() AS DATE), 'CONFIRMADO', @Canal);

    SET @PedidoID = SCOPE_IDENTITY();

    -- Paso B: primer producto (el precio lo pone el servidor)
    INSERT INTO dbo.DetallePedido (PedidoID, ProductoID, Cantidad, PrecioUnitario)
    SELECT @PedidoID, ProductoID, @Cantidad1, PrecioLista
    FROM dbo.Producto
    WHERE ProductoID = @ProductoID1;

    UPDATE dbo.Producto
    SET Stock = Stock - @Cantidad1
    WHERE ProductoID = @ProductoID1
      AND Stock >= @Cantidad1;

    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        SET @PedidoID = NULL;
        PRINT 'Cancelado con ROLLBACK: stock insuficiente del primer producto.';
        RETURN 3;
    END;

    -- Paso C: segundo producto (opcional)
    IF @ProductoID2 IS NOT NULL
    BEGIN
        INSERT INTO dbo.DetallePedido (PedidoID, ProductoID, Cantidad, PrecioUnitario)
        SELECT @PedidoID, ProductoID, @Cantidad2, PrecioLista
        FROM dbo.Producto
        WHERE ProductoID = @ProductoID2;

        UPDATE dbo.Producto
        SET Stock = Stock - @Cantidad2
        WHERE ProductoID = @ProductoID2
          AND Stock >= @Cantidad2;

        IF @@ROWCOUNT = 0
        BEGIN
            -- Aquí el primer producto ya se había grabado y descontado:
            -- el ROLLBACK también deshace esos cambios.
            ROLLBACK TRANSACTION;
            SET @PedidoID = NULL;
            PRINT 'Cancelado con ROLLBACK: stock insuficiente del segundo producto.';
            RETURN 3;
        END;
    END;

    -- Todo correcto: se confirman los cambios
    COMMIT TRANSACTION;
    PRINT 'Pedido registrado con COMMIT.';
    RETURN 0;
END;
GO


/* ============================================================
   EJECUCIÓN DE EJEMPLO
   Importante: este bloque cambia datos (crea el pedido 9 y
   descuenta stock). Antes de las pruebas de la Actividad 4 hay
   que volver a ejecutar 00_esquema_y_datos_base.sql.
   ============================================================ */

-- Escenario que CONFIRMA: 2 u. del producto 2 (stock 3) y 1 u. del producto 1 (stock 40)
DECLARE @Resultado INT, @Pedido INT;
EXEC @Resultado = dbo.usp_RegistrarPedido
     @ClienteID = 2, @Canal = 'Web',
     @ProductoID1 = 2, @Cantidad1 = 2,
     @ProductoID2 = 1, @Cantidad2 = 1,
     @PedidoID = @Pedido OUTPUT;
SELECT 'Confirma' AS Escenario, @Resultado AS Resultado, @Pedido AS PedidoID;
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID IN (1, 2);  -- 39 y 1
GO

-- Escenario que CANCELA: 1 u. del producto 1 y 5 u. del producto 2 (ahora stock 1)
-- El producto 1 se descuenta primero y luego se revierte con el ROLLBACK.
DECLARE @Resultado INT, @Pedido INT;
EXEC @Resultado = dbo.usp_RegistrarPedido
     @ClienteID = 2, @Canal = 'Web',
     @ProductoID1 = 1, @Cantidad1 = 1,
     @ProductoID2 = 2, @Cantidad2 = 5,
     @PedidoID = @Pedido OUTPUT;
SELECT 'Cancela' AS Escenario, @Resultado AS Resultado, @Pedido AS PedidoID;
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID IN (1, 2);  -- siguen 39 y 1
SELECT COUNT(*) AS Pedidos FROM dbo.Pedido;                                       -- siguen 9
-- Nota: el ROLLBACK deshace los datos, pero no devuelve el número IDENTITY que se
-- usó. Por eso el próximo pedido que se confirme será el 11, no el 10.
GO


/* ============================================================
   TIPOS DE TRANSACCIÓN EN SQL SERVER

   1. Autoconfirmación (modo por defecto)
      Cada sentencia es su propia transacción y se confirma sola al
      terminar. Si se registra un pedido con sentencias sueltas y una
      falla, las anteriores ya quedaron grabadas (demostrado en la
      Actividad 1).

   2. Implícita (SET IMPLICIT_TRANSACTIONS ON)
      SQL Server abre una transacción automáticamente con la primera
      sentencia (INSERT, UPDATE, DELETE, etc.), pero NO la cierra: queda
      abierta hasta que alguien escriba COMMIT o ROLLBACK. Si se olvida,
      la transacción sigue abierta y bloquea las filas.

   3. Explícita (BEGIN TRANSACTION ... COMMIT / ROLLBACK)
      El programador marca dónde empieza y dónde termina la unidad de
      trabajo, y decide con una regla de negocio si confirma o cancela.
      Es la que usamos en usp_RegistrarPedido: el servidor revisa el
      stock y elige COMMIT o ROLLBACK.

   Criterio de confirmación o cancelación en usp_RegistrarPedido:
     - COMMIT: el cliente y los productos son válidos y TODOS los
       productos tienen stock suficiente.
     - ROLLBACK: algún producto no tiene stock, o falla cualquier
       sentencia dentro de la transacción (XACT_ABORT ON).
   ============================================================ */

-- Demostración corta del modo implícito: la transacción queda abierta sola
SET IMPLICIT_TRANSACTIONS ON;
UPDATE dbo.Producto SET Stock = Stock WHERE ProductoID = 1;  -- no cambia nada
SELECT @@TRANCOUNT AS TransaccionesAbiertas;                 -- 1: quedó abierta sin BEGIN
ROLLBACK TRANSACTION;
SET IMPLICIT_TRANSACTIONS OFF;
SELECT @@TRANCOUNT AS TransaccionesAbiertas;                 -- 0: ya se cerró
GO
