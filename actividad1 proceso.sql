/* ============================================================
   PA3 - Actividad 1: Identificación del proceso a automatizar
   Responsable: Rodrigo Gómez Carrasco
   Base: PA3_NovaMarket (ejecutar antes 00_esquema_y_datos_base.sql)

   Proceso elegido: REGISTRO DE UN PEDIDO
   Registrar una venta son tres operaciones que dependen entre sí:
     1. INSERT de la cabecera en Pedido
     2. INSERT de cada producto vendido en DetallePedido
     3. UPDATE del Stock de cada producto en Producto

   Hoy la aplicación del vendedor envía esas sentencias por separado.
   Si una falla, las anteriores ya quedaron grabadas. Este script:
     - documenta entradas, salidas y reglas del proceso,
     - revisa en la base los datos de los que depende,
     - demuestra el problema actual (paso 4),
     - deja el pseudocódigo del procedimiento que lo resolverá
       en el servidor (Actividad 3).
   No crea ningún procedimiento.
   ============================================================ */

USE PA3_NovaMarket;
GO

/* ------------------------------------------------------------
   1. ENTRADAS, SALIDAS Y REGLAS
   ------------------------------------------------------------
   Entradas (las envía la aplicación cliente):
     @ClienteID    INT          cliente que compra
     @Canal        VARCHAR(30)  Web, Tienda, WhatsApp o Teléfono
     @ProductoID1  INT          primer producto
     @Cantidad1    INT          unidades del primer producto
     @ProductoID2  INT          segundo producto (puede ir en NULL)
     @Cantidad2    INT          unidades del segundo producto (puede ir en NULL)

   Salidas (las devuelve el servidor):
     @PedidoID OUTPUT  número del pedido creado, NULL si no se registró
     RETURN            0 = registrado
                       1 = cliente no válido (no existe o está inactivo)
                       2 = producto no válido (no existe o está inactivo)
                       3 = stock insuficiente
                       4 = datos incompletos (canal inválido o sin productos)

   Reglas:
     R1  El cliente debe existir y estar activo.
     R2  El canal debe ser uno de los cuatro permitidos.
     R3  Cada producto debe existir, estar activo y pedirse con cantidad > 0.
     R4  Debe haber stock suficiente para cada producto.
     R5  El precio lo toma el servidor desde Producto.PrecioLista;
         la aplicación nunca envía precios.
     R6  Todo o nada: si una regla falla, no se graba ni el pedido,
         ni las líneas, ni el descuento de stock.
   ------------------------------------------------------------ */


/* ------------------------------------------------------------
   2. DATOS DE LOS QUE DEPENDE EL PROCESO
   ------------------------------------------------------------ */

-- R1: clientes que pueden comprar (activos) y los que no
SELECT ClienteID, Nombre, Ciudad, Activo,
       CASE WHEN Activo = 1 THEN 'Puede comprar' ELSE 'Bloqueado (R1)' END AS Estado
FROM dbo.Cliente
ORDER BY ClienteID;

-- R3 y R4: productos vendibles según estado y stock
SELECT p.ProductoID, p.Nombre, c.Nombre AS Categoria, p.PrecioLista, p.Stock, p.Activo,
       CASE
           WHEN p.Activo = 0 THEN 'No vendible: inactivo (R3)'
           WHEN p.Stock  = 0 THEN 'No vendible: agotado (R4)'
           WHEN p.Stock <= 3 THEN 'Vendible, stock bajo'
           ELSE 'Vendible'
       END AS Situacion
FROM dbo.Producto AS p
JOIN dbo.Categoria AS c ON c.CategoriaID = p.CategoriaID
ORDER BY p.ProductoID;

-- Pedidos ya registrados: el próximo pedido nuevo será el 9
SELECT p.PedidoID, p.ClienteID, p.FechaPedido, p.Estado, p.Canal,
       COUNT(d.DetalleID)                 AS Lineas,
       SUM(d.Cantidad * d.PrecioUnitario) AS Total
FROM dbo.Pedido AS p
LEFT JOIN dbo.DetallePedido AS d ON d.PedidoID = p.PedidoID
GROUP BY p.PedidoID, p.ClienteID, p.FechaPedido, p.Estado, p.Canal
ORDER BY p.PedidoID;
GO


/* ------------------------------------------------------------
   3. ESCENARIOS QUE EL PROCESO DEBE RESOLVER
   (se ejecutan en la Actividad 4 con el procedimiento ya creado)

   Escenario                    Entrada                                   Resultado esperado
   Confirma                     Cliente 2, Web: 2 u. prod. 2 + 1 u. prod. 1   RETURN 0, pedido 9, stock 2 = 1, stock 1 = 39
   Cancela por stock            Cliente 2, Web: 1 u. prod. 1 + 5 u. prod. 2   RETURN 3, sin pedido, stock 1 sigue en 40
   Cancela por agotado          Cliente 3: 1 u. prod. 9 (stock 0)             RETURN 3
   Producto inactivo            Cliente 3: prod. 5                            RETURN 2
   Cliente inactivo/inexistente Cliente 10 o 99                               RETURN 1
   ------------------------------------------------------------ */

-- Estado de los registros involucrados en los escenarios
SELECT 'Cliente' AS Tipo, ClienteID AS ID, Nombre, Activo, NULL AS Stock
FROM dbo.Cliente WHERE ClienteID IN (2, 3, 10)
UNION ALL
SELECT 'Producto', ProductoID, Nombre, Activo, Stock
FROM dbo.Producto WHERE ProductoID IN (1, 2, 5, 9)
ORDER BY Tipo, ID;
GO


/* ------------------------------------------------------------
   4. DEMOSTRACIÓN DEL PROBLEMA ACTUAL (modo de autoconfirmación)
   La aplicación envía las sentencias sueltas, sin transacción.
   SQL Server confirma cada una apenas termina. Se registra el
   escenario "cancela por stock": 1 u. del producto 1 y 5 del 2.
   El UPDATE del producto 2 va a fallar a propósito por el CHECK
   Stock >= 0 (sale un error en rojo, es esperado).
   ------------------------------------------------------------ */

-- 4.1 Estado ANTES
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID IN (1, 2);
SELECT COUNT(*) AS PedidosAntes FROM dbo.Pedido;
GO

-- 4.2 Las cuatro sentencias que hoy envía la aplicación, una por una.
--     Van en un solo lote solo para guardar el número del pedido en una
--     variable; cada sentencia igual se confirma sola (autoconfirmación).
DECLARE @PedidoDemo INT;

INSERT INTO dbo.Pedido (ClienteID, FechaPedido, Estado, Canal)
VALUES (2, CAST(GETDATE() AS DATE), 'CONFIRMADO', 'Web');
SET @PedidoDemo = SCOPE_IDENTITY();

INSERT INTO dbo.DetallePedido (PedidoID, ProductoID, Cantidad, PrecioUnitario)
VALUES (@PedidoDemo, 1, 1, 289.90),
       (@PedidoDemo, 2, 5, 119.90);

UPDATE dbo.Producto SET Stock = Stock - 1 WHERE ProductoID = 1;   -- se graba
UPDATE dbo.Producto SET Stock = Stock - 5 WHERE ProductoID = 2;   -- falla: 3 - 5 < 0

-- 4.3 Estado DESPUÉS: la base quedó inconsistente
--     - existe el pedido con una línea de 5 unidades que nunca se descontaron
--     - al producto 1 sí se le descontó 1 unidad
SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID IN (1, 2);
SELECT p.PedidoID, p.Estado, d.ProductoID, d.Cantidad
FROM dbo.Pedido AS p
JOIN dbo.DetallePedido AS d ON d.PedidoID = p.PedidoID
WHERE p.PedidoID = @PedidoDemo;

-- 4.4 Limpieza: deja la base como estaba para las demás actividades
DELETE FROM dbo.DetallePedido WHERE PedidoID = @PedidoDemo;
DELETE FROM dbo.Pedido WHERE PedidoID = @PedidoDemo;
UPDATE dbo.Producto SET Stock = Stock + 1 WHERE ProductoID = 1;

-- Los contadores IDENTITY vuelven al último número usado, así el
-- próximo pedido no deja un hueco por esta demostración.
DECLARE @UltimoPedido INT = ISNULL((SELECT MAX(PedidoID) FROM dbo.Pedido), 0);
DECLARE @UltimaLinea  INT = ISNULL((SELECT MAX(DetalleID) FROM dbo.DetallePedido), 0);
DBCC CHECKIDENT ('dbo.Pedido', RESEED, @UltimoPedido);
DBCC CHECKIDENT ('dbo.DetallePedido', RESEED, @UltimaLinea);

SELECT ProductoID, Nombre, Stock FROM dbo.Producto WHERE ProductoID IN (1, 2);  -- como al inicio
SELECT COUNT(*) AS PedidosDespuesDeLimpiar FROM dbo.Pedido;
GO

/* Conclusión de la demostración: en autoconfirmación cada sentencia se
   confirma sola, así que un error a mitad del proceso deja cambios
   parciales. Por eso el registro del pedido se trasladará al servidor
   como un procedimiento almacenado con una transacción explícita
   (Actividad 3): el servidor valida las reglas y decide confirmar
   (COMMIT) o cancelar todo (ROLLBACK). */


/* ------------------------------------------------------------
   5. POR QUÉ IMPLEMENTARLO EN EL SERVIDOR
     - Las reglas R1 a R6 se escriben una sola vez. La web, la tienda,
       WhatsApp y teléfono llaman al mismo EXEC.
     - La transacción la controla el servidor: la aplicación no puede
       dejar un pedido a medias aunque se cierre en pleno proceso.
     - Una sola llamada reemplaza cuatro o más sentencias por la red.
     - Si cambia una regla se corrige con ALTER PROCEDURE, sin tocar
       las aplicaciones.

   6. ARQUITECTURA CLIENTE/SERVIDOR EN DOS CAPAS
     Capa cliente:   aplicación del vendedor (en el curso, SSMS).
                     Pide cliente, canal, productos y cantidades,
                     ejecuta el EXEC y muestra el resultado.
     Capa servidor:  SQL Server ejecuta usp_RegistrarPedido, valida,
                     graba dentro de la transacción y devuelve
                     RETURN y @PedidoID.

     [Aplicación cliente] --EXEC con parámetros--> [SQL Server: usp_RegistrarPedido]
                                                        | valida R1 a R4
                                                        | BEGIN TRANSACTION
                                                        | INSERT Pedido / DetallePedido
                                                        | UPDATE Producto.Stock
                                                        | COMMIT o ROLLBACK
     [Aplicación cliente] <--RETURN + @PedidoID----------+

   7. PSEUDOCÓDIGO DEL PROCEDIMIENTO (se programa en la Actividad 3)

     PROCEDIMIENTO usp_RegistrarPedido
         ENTRADA: ClienteID, Canal, ProductoID1, Cantidad1, ProductoID2, Cantidad2
         SALIDA:  PedidoID
         PedidoID <- NULL
         SI cliente no existe o está inactivo              -> RETORNAR 1
         SI canal inválido o ningún producto con cantidad > 0 -> RETORNAR 4
         SI algún producto no existe o está inactivo         -> RETORNAR 2
         INICIAR TRANSACCIÓN
             INSERTAR Pedido (ClienteID, hoy, CONFIRMADO, Canal)
             PedidoID <- número generado
             PARA cada producto recibido
                 INSERTAR DetallePedido con el PrecioLista actual
                 DESCONTAR Cantidad del Stock
             FIN PARA
             SI algún stock quedaría negativo o falló una sentencia
                 CANCELAR TRANSACCIÓN
                 PedidoID <- NULL
                 RETORNAR 3
             FIN SI
         CONFIRMAR TRANSACCIÓN
         RETORNAR 0
     FIN PROCEDIMIENTO
   ------------------------------------------------------------ */
