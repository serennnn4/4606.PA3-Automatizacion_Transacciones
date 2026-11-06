/* ============================================================
   PA3 - Actividad 4: Pruebas, evidencias y análisis de resultados
   Curso: Programación Avanzada de Base de Datos (30627)
   Base: PA3_NovaMarket

   Orden previo:
     1. 00_esquema_y_datos_base.sql
     2. actividad2_procedimientos.sql
     3. actividad3_transaccion.sql   (crea usp_RegistrarPedido)

   Este script ejecuta usp_RegistrarPedido en 7 escenarios: dos que
   confirman la operación y cinco que la cancelan. En cada uno guarda
   el estado de las tablas ANTES y DESPUÉS y lo compara con el resultado
   esperado. Al final muestra la matriz de pruebas completa.

   Ejecutar el script completo con F5, en una sola ventana: la matriz se
   guarda en una tabla temporal (#Matriz) que vive mientras la ventana
   esté abierta.
   ============================================================ */

USE PA3_NovaMarket;
GO

/* ------------------------------------------------------------
   0. PREPARACIÓN
   El script de la Actividad 3 ya hizo una venta de ejemplo, así que
   antes de probar se dejan los productos y clientes involucrados en un
   estado conocido. Así las pruebas dan lo mismo sin importar cuántas
   veces se haya corrido la Actividad 3.
   ------------------------------------------------------------ */
IF OBJECT_ID('dbo.usp_RegistrarPedido', 'P') IS NULL
    PRINT 'ATENCIÓN: falta crear usp_RegistrarPedido (ejecutar actividad3_transaccion.sql).';

UPDATE dbo.Producto SET Stock = 40, Activo = 1 WHERE ProductoID = 1;  -- Router
UPDATE dbo.Producto SET Stock = 3,  Activo = 1 WHERE ProductoID = 2;  -- Switch
UPDATE dbo.Producto SET Activo = 0              WHERE ProductoID = 5;  -- Repetidor (inactivo)
UPDATE dbo.Producto SET Stock = 1,  Activo = 1 WHERE ProductoID = 6;  -- Firewall (último en stock)
UPDATE dbo.Producto SET Stock = 0,  Activo = 1 WHERE ProductoID = 9;  -- Tester (agotado)
UPDATE dbo.Cliente  SET Activo = 1 WHERE ClienteID IN (2, 3, 4);
UPDATE dbo.Cliente  SET Activo = 0 WHERE ClienteID = 10;

IF OBJECT_ID('tempdb..#Matriz') IS NOT NULL DROP TABLE #Matriz;
CREATE TABLE #Matriz (
    Prueba           VARCHAR(5),
    Escenario        VARCHAR(70),
    TipoEsperado     VARCHAR(10),
    RetornoEsperado  INT,
    RetornoObtenido  INT,
    PedidoID         INT,
    PedidosAntes     INT,
    PedidosDespues   INT,
    LineasAntes      INT,
    LineasDespues    INT,
    StockAntes       VARCHAR(40),
    StockDespues     VARCHAR(40),
    TranAbiertas     INT,
    Resultado        VARCHAR(5)
);

-- Estado inicial de las tablas
SELECT 'ESTADO INICIAL' AS Momento,
       (SELECT COUNT(*) FROM dbo.Pedido)        AS Pedidos,
       (SELECT COUNT(*) FROM dbo.DetallePedido) AS Lineas;
SELECT ProductoID, Nombre, Stock, Activo
FROM dbo.Producto
WHERE ProductoID IN (1, 2, 5, 6, 9)
ORDER BY ProductoID;
GO


/* ------------------------------------------------------------
   P1. CONFIRMA: cliente 2 compra 2 u. del producto 2 (stock 3)
       y 1 u. del producto 1 (stock 40).
   Esperado: RETURN 0, 1 pedido y 2 líneas nuevas,
             stock del producto 2: 3 -> 1, del producto 1: 40 -> 39.
   ------------------------------------------------------------ */
DECLARE @r INT, @p INT, @Tran INT, @PedA INT, @PedD INT, @LinA INT, @LinD INT,
        @S1A INT, @S2A INT, @S1D INT, @S2D INT;
SELECT @PedA = COUNT(*) FROM dbo.Pedido;
SELECT @LinA = COUNT(*) FROM dbo.DetallePedido;
SELECT @S1A = Stock FROM dbo.Producto WHERE ProductoID = 1;
SELECT @S2A = Stock FROM dbo.Producto WHERE ProductoID = 2;

EXEC @r = dbo.usp_RegistrarPedido
     @ClienteID = 2, @Canal = 'Web',
     @ProductoID1 = 2, @Cantidad1 = 2,
     @ProductoID2 = 1, @Cantidad2 = 1,
     @PedidoID = @p OUTPUT;

SELECT @PedD = COUNT(*) FROM dbo.Pedido;
SELECT @LinD = COUNT(*) FROM dbo.DetallePedido;
SELECT @S1D = Stock FROM dbo.Producto WHERE ProductoID = 1;
SELECT @S2D = Stock FROM dbo.Producto WHERE ProductoID = 2;

SET @Tran = @@TRANCOUNT;   -- se mide fuera del INSERT

INSERT INTO #Matriz VALUES (
    'P1', 'Confirma: 2 u. producto 2 + 1 u. producto 1', 'COMMIT', 0, @r, @p,
    @PedA, @PedD, @LinA, @LinD,
    CONCAT('Prod1=', @S1A, ' Prod2=', @S2A), CONCAT('Prod1=', @S1D, ' Prod2=', @S2D),
    @Tran,
    CASE WHEN @r = 0 AND @PedD = @PedA + 1 AND @LinD = @LinA + 2
               AND @S1D = @S1A - 1 AND @S2D = @S2A - 2 THEN 'OK' ELSE 'FALLA' END);

-- Evidencia: el pedido nuevo y sus líneas
SELECT 'P1 - pedido creado' AS Evidencia, PedidoID, ClienteID, FechaPedido, Estado, Canal
FROM dbo.Pedido WHERE PedidoID = @p;
SELECT 'P1 - líneas del pedido' AS Evidencia, DetalleID, PedidoID, ProductoID, Cantidad, PrecioUnitario
FROM dbo.DetallePedido WHERE PedidoID = @p;
SELECT 'P1 - stock después' AS Evidencia, ProductoID, Nombre, Stock
FROM dbo.Producto WHERE ProductoID IN (1, 2);
GO


/* ------------------------------------------------------------
   P2. CANCELA POR STOCK EN EL SEGUNDO PRODUCTO: cliente 2 compra
       1 u. del producto 1 y 5 u. del producto 2 (ahora stock 1).
   Dentro de la transacción se graba la cabecera, la línea del
   producto 1 y se le descuenta 1 unidad; al llegar al producto 2
   no hay stock y se hace ROLLBACK.
   Esperado: RETURN 3, ningún pedido ni línea nueva y el producto 1
             vuelve a su stock (el descuento se deshizo).
   ------------------------------------------------------------ */
DECLARE @r INT, @p INT, @Tran INT, @PedA INT, @PedD INT, @LinA INT, @LinD INT,
        @S1A INT, @S2A INT, @S1D INT, @S2D INT;
SELECT @PedA = COUNT(*) FROM dbo.Pedido;
SELECT @LinA = COUNT(*) FROM dbo.DetallePedido;
SELECT @S1A = Stock FROM dbo.Producto WHERE ProductoID = 1;
SELECT @S2A = Stock FROM dbo.Producto WHERE ProductoID = 2;

EXEC @r = dbo.usp_RegistrarPedido
     @ClienteID = 2, @Canal = 'Web',
     @ProductoID1 = 1, @Cantidad1 = 1,
     @ProductoID2 = 2, @Cantidad2 = 5,
     @PedidoID = @p OUTPUT;

SELECT @PedD = COUNT(*) FROM dbo.Pedido;
SELECT @LinD = COUNT(*) FROM dbo.DetallePedido;
SELECT @S1D = Stock FROM dbo.Producto WHERE ProductoID = 1;
SELECT @S2D = Stock FROM dbo.Producto WHERE ProductoID = 2;

SET @Tran = @@TRANCOUNT;   -- se mide fuera del INSERT

INSERT INTO #Matriz VALUES (
    'P2', 'Cancela: 1 u. producto 1 + 5 u. producto 2 (stock 1)', 'ROLLBACK', 3, @r, @p,
    @PedA, @PedD, @LinA, @LinD,
    CONCAT('Prod1=', @S1A, ' Prod2=', @S2A), CONCAT('Prod1=', @S1D, ' Prod2=', @S2D),
    @Tran,
    CASE WHEN @r = 3 AND @p IS NULL AND @PedD = @PedA AND @LinD = @LinA
               AND @S1D = @S1A AND @S2D = @S2A AND @Tran = 0 THEN 'OK' ELSE 'FALLA' END);

-- Evidencia: el stock del producto 1 no quedó descontado
SELECT 'P2 - stock después del ROLLBACK' AS Evidencia, ProductoID, Nombre, Stock
FROM dbo.Producto WHERE ProductoID IN (1, 2);
GO


/* ------------------------------------------------------------
   P3. CANCELA POR PRODUCTO AGOTADO: cliente 3 compra 1 u. del
       producto 9 (stock 0).
   Esperado: RETURN 3, nada cambia.
   ------------------------------------------------------------ */
DECLARE @r INT, @p INT, @Tran INT, @PedA INT, @PedD INT, @LinA INT, @LinD INT, @SA INT, @SD INT;
SELECT @PedA = COUNT(*) FROM dbo.Pedido;
SELECT @LinA = COUNT(*) FROM dbo.DetallePedido;
SELECT @SA = Stock FROM dbo.Producto WHERE ProductoID = 9;

EXEC @r = dbo.usp_RegistrarPedido
     @ClienteID = 3, @Canal = 'Tienda',
     @ProductoID1 = 9, @Cantidad1 = 1,
     @PedidoID = @p OUTPUT;

SELECT @PedD = COUNT(*) FROM dbo.Pedido;
SELECT @LinD = COUNT(*) FROM dbo.DetallePedido;
SELECT @SD = Stock FROM dbo.Producto WHERE ProductoID = 9;

SET @Tran = @@TRANCOUNT;   -- se mide fuera del INSERT

INSERT INTO #Matriz VALUES (
    'P3', 'Cancela: producto 9 agotado (stock 0)', 'ROLLBACK', 3, @r, @p,
    @PedA, @PedD, @LinA, @LinD,
    CONCAT('Prod9=', @SA), CONCAT('Prod9=', @SD),
    @Tran,
    CASE WHEN @r = 3 AND @p IS NULL AND @PedD = @PedA AND @LinD = @LinA
               AND @SD = @SA AND @Tran = 0 THEN 'OK' ELSE 'FALLA' END);
GO


/* ------------------------------------------------------------
   P4. RECHAZA PRODUCTO INACTIVO: cliente 3 compra el producto 5.
   Esperado: RETURN 2, no se abre la transacción, nada cambia.
   ------------------------------------------------------------ */
DECLARE @r INT, @p INT, @Tran INT, @PedA INT, @PedD INT, @LinA INT, @LinD INT, @SA INT, @SD INT;
SELECT @PedA = COUNT(*) FROM dbo.Pedido;
SELECT @LinA = COUNT(*) FROM dbo.DetallePedido;
SELECT @SA = Stock FROM dbo.Producto WHERE ProductoID = 5;

EXEC @r = dbo.usp_RegistrarPedido
     @ClienteID = 3, @Canal = 'Web',
     @ProductoID1 = 5, @Cantidad1 = 1,
     @PedidoID = @p OUTPUT;

SELECT @PedD = COUNT(*) FROM dbo.Pedido;
SELECT @LinD = COUNT(*) FROM dbo.DetallePedido;
SELECT @SD = Stock FROM dbo.Producto WHERE ProductoID = 5;

SET @Tran = @@TRANCOUNT;   -- se mide fuera del INSERT

INSERT INTO #Matriz VALUES (
    'P4', 'Rechaza: producto 5 inactivo', 'SIN CAMBIO', 2, @r, @p,
    @PedA, @PedD, @LinA, @LinD,
    CONCAT('Prod5=', @SA), CONCAT('Prod5=', @SD),
    @Tran,
    CASE WHEN @r = 2 AND @p IS NULL AND @PedD = @PedA AND @LinD = @LinA
               AND @SD = @SA THEN 'OK' ELSE 'FALLA' END);
GO


/* ------------------------------------------------------------
   P5. RECHAZA CLIENTE INACTIVO: el cliente 10 intenta comprar.
   Esperado: RETURN 1, nada cambia.
   ------------------------------------------------------------ */
DECLARE @r INT, @p INT, @Tran INT, @PedA INT, @PedD INT, @LinA INT, @LinD INT, @SA INT, @SD INT;
SELECT @PedA = COUNT(*) FROM dbo.Pedido;
SELECT @LinA = COUNT(*) FROM dbo.DetallePedido;
SELECT @SA = Stock FROM dbo.Producto WHERE ProductoID = 1;

EXEC @r = dbo.usp_RegistrarPedido
     @ClienteID = 10, @Canal = 'Web',
     @ProductoID1 = 1, @Cantidad1 = 1,
     @PedidoID = @p OUTPUT;

SELECT @PedD = COUNT(*) FROM dbo.Pedido;
SELECT @LinD = COUNT(*) FROM dbo.DetallePedido;
SELECT @SD = Stock FROM dbo.Producto WHERE ProductoID = 1;

SET @Tran = @@TRANCOUNT;   -- se mide fuera del INSERT

INSERT INTO #Matriz VALUES (
    'P5', 'Rechaza: cliente 10 inactivo', 'SIN CAMBIO', 1, @r, @p,
    @PedA, @PedD, @LinA, @LinD,
    CONCAT('Prod1=', @SA), CONCAT('Prod1=', @SD),
    @Tran,
    CASE WHEN @r = 1 AND @p IS NULL AND @PedD = @PedA AND @LinD = @LinA
               AND @SD = @SA THEN 'OK' ELSE 'FALLA' END);
GO


/* ------------------------------------------------------------
   P6. RECHAZA DATOS INVÁLIDOS: canal 'Fax', que no existe.
   Esperado: RETURN 4, nada cambia.
   ------------------------------------------------------------ */
DECLARE @r INT, @p INT, @Tran INT, @PedA INT, @PedD INT, @LinA INT, @LinD INT, @SA INT, @SD INT;
SELECT @PedA = COUNT(*) FROM dbo.Pedido;
SELECT @LinA = COUNT(*) FROM dbo.DetallePedido;
SELECT @SA = Stock FROM dbo.Producto WHERE ProductoID = 1;

EXEC @r = dbo.usp_RegistrarPedido
     @ClienteID = 3, @Canal = 'Fax',
     @ProductoID1 = 1, @Cantidad1 = 1,
     @PedidoID = @p OUTPUT;

SELECT @PedD = COUNT(*) FROM dbo.Pedido;
SELECT @LinD = COUNT(*) FROM dbo.DetallePedido;
SELECT @SD = Stock FROM dbo.Producto WHERE ProductoID = 1;

SET @Tran = @@TRANCOUNT;   -- se mide fuera del INSERT

INSERT INTO #Matriz VALUES (
    'P6', 'Rechaza: canal inválido (Fax)', 'SIN CAMBIO', 4, @r, @p,
    @PedA, @PedD, @LinA, @LinD,
    CONCAT('Prod1=', @SA), CONCAT('Prod1=', @SD),
    @Tran,
    CASE WHEN @r = 4 AND @p IS NULL AND @PedD = @PedA AND @LinD = @LinA
               AND @SD = @SA THEN 'OK' ELSE 'FALLA' END);
GO


/* ------------------------------------------------------------
   P7. CONFIRMA EN EL LÍMITE: cliente 4 compra la última unidad del
       producto 6 (stock 1).
   Esperado: RETURN 0, 1 pedido y 1 línea nueva, stock 1 -> 0.
   Comprueba que pedir exactamente el stock disponible sí se permite.
   ------------------------------------------------------------ */
DECLARE @r INT, @p INT, @Tran INT, @PedA INT, @PedD INT, @LinA INT, @LinD INT, @SA INT, @SD INT;
SELECT @PedA = COUNT(*) FROM dbo.Pedido;
SELECT @LinA = COUNT(*) FROM dbo.DetallePedido;
SELECT @SA = Stock FROM dbo.Producto WHERE ProductoID = 6;

EXEC @r = dbo.usp_RegistrarPedido
     @ClienteID = 4, @Canal = 'Tienda',
     @ProductoID1 = 6, @Cantidad1 = 1,
     @PedidoID = @p OUTPUT;

SELECT @PedD = COUNT(*) FROM dbo.Pedido;
SELECT @LinD = COUNT(*) FROM dbo.DetallePedido;
SELECT @SD = Stock FROM dbo.Producto WHERE ProductoID = 6;

SET @Tran = @@TRANCOUNT;   -- se mide fuera del INSERT

INSERT INTO #Matriz VALUES (
    'P7', 'Confirma: última unidad del producto 6', 'COMMIT', 0, @r, @p,
    @PedA, @PedD, @LinA, @LinD,
    CONCAT('Prod6=', @SA), CONCAT('Prod6=', @SD),
    @Tran,
    CASE WHEN @r = 0 AND @PedD = @PedA + 1 AND @LinD = @LinA + 1
               AND @SD = 0 THEN 'OK' ELSE 'FALLA' END);
GO


/* ------------------------------------------------------------
   MATRIZ DE PRUEBAS (captura principal para el README)
   ------------------------------------------------------------ */
SELECT Prueba, Escenario, TipoEsperado,
       RetornoEsperado, RetornoObtenido, PedidoID,
       PedidosAntes, PedidosDespues, LineasAntes, LineasDespues,
       StockAntes, StockDespues, TranAbiertas, Resultado
FROM #Matriz
ORDER BY Prueba;

SELECT COUNT(*) AS PruebasEjecutadas,
       SUM(CASE WHEN Resultado = 'OK' THEN 1 ELSE 0 END) AS PruebasOK
FROM #Matriz;
GO
