/* ============================================================
   PA3 - Esquema base: NovaMarket
   Curso: Programación Avanzada de Base de Datos (30627)
   Cobertura: sesiones 09 y 10 (procedimientos almacenados y transacciones)
   Motor: SQL Server | Autenticación de Windows | instancia local

   Este script crea la base de datos, las 5 tablas del caso y los datos
   base sobre los que trabajan las actividades del PA3. No crea ningún
   procedimiento: los procedimientos y las transacciones van en los
   scripts de cada actividad.
   ============================================================ */

-- 1. Crear la base de datos
CREATE DATABASE PA3_NovaMarket;
GO

USE PA3_NovaMarket;
GO

-- 2. Limpieza de tablas (de hijas a padres, para poder re-ejecutar el script)
IF OBJECT_ID('dbo.DetallePedido', 'U') IS NOT NULL DROP TABLE dbo.DetallePedido;
IF OBJECT_ID('dbo.Pedido', 'U')        IS NOT NULL DROP TABLE dbo.Pedido;
IF OBJECT_ID('dbo.Producto', 'U')      IS NOT NULL DROP TABLE dbo.Producto;
IF OBJECT_ID('dbo.Categoria', 'U')     IS NOT NULL DROP TABLE dbo.Categoria;
IF OBJECT_ID('dbo.Cliente', 'U')       IS NOT NULL DROP TABLE dbo.Cliente;
GO

-- 3. Tabla Cliente
--    Correo y Telefono son opcionales: el mantenimiento de clientes (Actividad 2)
--    puede actualizarlos sin tocar el Documento, que es único.
CREATE TABLE dbo.Cliente (
    ClienteID      INT IDENTITY(1,1) NOT NULL,
    Documento      VARCHAR(15)  NOT NULL,
    Nombre         VARCHAR(100) NOT NULL,
    Ciudad         VARCHAR(50)  NOT NULL,
    Correo         VARCHAR(100) NULL,
    Telefono       VARCHAR(20)  NULL,
    Activo         BIT          NOT NULL CONSTRAINT DF_Cliente_Activo DEFAULT 1,
    FechaRegistro  DATE         NOT NULL CONSTRAINT DF_Cliente_Fecha DEFAULT (CAST(GETDATE() AS DATE)),
    CONSTRAINT PK_Cliente PRIMARY KEY (ClienteID),
    CONSTRAINT UQ_Cliente_Documento UNIQUE (Documento)
);
GO

-- 4. Tabla Categoria
CREATE TABLE dbo.Categoria (
    CategoriaID  INT IDENTITY(1,1) NOT NULL,
    Nombre       VARCHAR(50) NOT NULL,
    CONSTRAINT PK_Categoria PRIMARY KEY (CategoriaID),
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre)
);
GO

-- 5. Tabla Producto
--    El CHECK de Stock >= 0 es la regla que protege la transacción de la
--    Actividad 3: si un pedido intenta descontar más stock del que hay,
--    la operación debe cancelarse completa.
CREATE TABLE dbo.Producto (
    ProductoID   INT IDENTITY(1,1) NOT NULL,
    CategoriaID  INT            NOT NULL,
    Nombre       VARCHAR(100)   NOT NULL,
    PrecioLista  DECIMAL(10,2)  NOT NULL,
    Stock        INT            NOT NULL CONSTRAINT DF_Producto_Stock DEFAULT 0,
    Activo       BIT            NOT NULL CONSTRAINT DF_Producto_Activo DEFAULT 1,
    CONSTRAINT PK_Producto PRIMARY KEY (ProductoID),
    CONSTRAINT FK_Producto_Categoria FOREIGN KEY (CategoriaID)
        REFERENCES dbo.Categoria(CategoriaID),
    CONSTRAINT UQ_Producto_Nombre UNIQUE (Nombre),
    CONSTRAINT CK_Producto_PrecioLista CHECK (PrecioLista > 0),
    CONSTRAINT CK_Producto_Stock CHECK (Stock >= 0)
);
GO

-- 6. Tabla Pedido (cabecera)
CREATE TABLE dbo.Pedido (
    PedidoID     INT IDENTITY(1,1) NOT NULL,
    ClienteID    INT         NOT NULL,
    FechaPedido  DATE        NOT NULL CONSTRAINT DF_Pedido_Fecha DEFAULT (CAST(GETDATE() AS DATE)),
    Estado       VARCHAR(15) NOT NULL CONSTRAINT DF_Pedido_Estado DEFAULT 'CONFIRMADO',
    Canal        VARCHAR(30) NOT NULL,
    CONSTRAINT PK_Pedido PRIMARY KEY (PedidoID),
    CONSTRAINT FK_Pedido_Cliente FOREIGN KEY (ClienteID)
        REFERENCES dbo.Cliente(ClienteID),
    CONSTRAINT CK_Pedido_Estado CHECK (Estado IN ('CONFIRMADO','PENDIENTE','ANULADO')),
    CONSTRAINT CK_Pedido_Canal CHECK (Canal IN ('Web','Tienda','WhatsApp','Teléfono'))
);
GO

-- 7. Tabla DetallePedido
--    PrecioUnitario guarda el precio al momento de la venta, no el precio
--    actual del producto.
CREATE TABLE dbo.DetallePedido (
    DetalleID       INT IDENTITY(1,1) NOT NULL,
    PedidoID        INT           NOT NULL,
    ProductoID      INT           NOT NULL,
    Cantidad        INT           NOT NULL,
    PrecioUnitario  DECIMAL(10,2) NOT NULL,
    CONSTRAINT PK_DetallePedido PRIMARY KEY (DetalleID),
    CONSTRAINT FK_Detalle_Pedido FOREIGN KEY (PedidoID)
        REFERENCES dbo.Pedido(PedidoID),
    CONSTRAINT FK_Detalle_Producto FOREIGN KEY (ProductoID)
        REFERENCES dbo.Producto(ProductoID),
    CONSTRAINT UQ_Detalle_PedidoProducto UNIQUE (PedidoID, ProductoID),
    CONSTRAINT CK_Detalle_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_Detalle_PrecioUnitario CHECK (PrecioUnitario > 0)
);
GO

/* ============================================================
   DATOS BASE
   ============================================================ */

-- 8. Categorías
INSERT INTO dbo.Categoria (Nombre) VALUES
('Redes'),
('Seguridad'),
('Accesorios');
GO

-- 9. Clientes (10: 9 activos y 1 inactivo). Los ClienteID salen en orden.
INSERT INTO dbo.Cliente (Documento, Nombre, Ciudad, Correo, Telefono, Activo, FechaRegistro) VALUES
('70100001', 'Ana Ramírez Torres',     'Lima',     'ana.ramirez@correo.pe',     '987100001', 1, '2025-02-10'),
('70100002', 'Carlos Flores Medina',   'Arequipa', 'carlos.flores@correo.pe',   '987100002', 1, '2025-03-05'),
('70100003', 'Bertha Quispe Huamán',   'Cusco',    NULL,                        '987100003', 1, '2025-04-18'),
('70100004', 'Diego Salazar Vega',     'Lima',     'diego.salazar@correo.pe',   NULL,        1, '2025-06-22'),
('70100005', 'Elena Torres Paredes',   'Trujillo', 'elena.torres@correo.pe',    '987100005', 1, '2025-08-01'),
('70100006', 'Fabricio Mendoza Rojas', 'Piura',    'fabricio.mendoza@correo.pe','987100006', 1, '2025-09-14'),
('70100007', 'Gabriela Ríos Campos',   'Lima',     'gabriela.rios@correo.pe',   '987100007', 1, '2026-01-09'),
('70100008', 'Hugo Castillo Salas',    'Arequipa', NULL,                        NULL,        1, '2026-03-27'),
('70100009', 'Isabel Vargas León',     'Chiclayo', 'isabel.vargas@correo.pe',   '987100009', 1, '2026-06-30'),
('70100010', 'Jorge Palomino Cruz',    'Lima',     'jorge.palomino@correo.pe',  '987100010', 0, '2025-01-15');
GO

-- 10. Productos (10). Los ProductoID salen en orden de la lista.
--     Stock pensado para las pruebas de la Actividad 4:
--       - 2 Switch Gigabit:        stock 3  (pedir 2 entra, pedir 5 no entra)
--       - 6 Firewall UTM:          stock 1  (último en stock)
--       - 9 Tester de red:         stock 0  (agotado)
--       - 5 Repetidor WiFi:        inactivo (no se debe poder vender)
INSERT INTO dbo.Producto (CategoriaID, Nombre, PrecioLista, Stock, Activo) VALUES
(1, 'Router WiFi 6 AX1800',       289.90,  40, 1),
(1, 'Switch Gigabit 8 puertos',   119.90,   3, 1),
(1, 'Access Point empresarial',   459.00,  15, 1),
(1, 'Cable UTP Cat6 caja 305 m',  389.00,  12, 1),
(1, 'Repetidor WiFi doble banda',  99.90,  30, 0),
(2, 'Firewall UTM',              1890.00,   1, 1),
(2, 'Cámara IP 2MP',              189.00,  35, 1),
(3, 'Patch cord Cat6 2 m',         12.90, 300, 1),
(3, 'Tester de red RJ45',          79.90,   0, 1),
(3, 'Organizador de cables',       24.90, 150, 1);
GO

-- 11. Pedidos históricos (8). Los PedidoID salen en orden: 1 a 8.
INSERT INTO dbo.Pedido (ClienteID, FechaPedido, Estado, Canal) VALUES
(1, '2026-08-04', 'CONFIRMADO', 'Web'),
(2, '2026-08-19', 'CONFIRMADO', 'Tienda'),
(3, '2026-09-02', 'CONFIRMADO', 'WhatsApp'),
(1, '2026-09-15', 'CONFIRMADO', 'Web'),
(4, '2026-09-28', 'ANULADO',    'Teléfono'),
(5, '2026-10-06', 'CONFIRMADO', 'Web'),
(6, '2026-10-20', 'PENDIENTE',  'Tienda'),
(7, '2026-11-02', 'CONFIRMADO', 'Web');
GO

-- 12. Detalle de los pedidos históricos (16 líneas).
--     El stock de Producto ya refleja estas ventas: no se vuelve a descontar.
INSERT INTO dbo.DetallePedido (PedidoID, ProductoID, Cantidad, PrecioUnitario) VALUES
(1, 1, 1, 289.90),
(1, 8, 4, 12.90),
(2, 3, 1, 459.00),
(2, 2, 2, 119.90),
(2, 8, 3, 12.90),
(3, 7, 2, 189.00),
(3, 10, 2, 24.90),
(4, 4, 1, 389.00),
(4, 8, 2, 12.90),
(5, 6, 1, 1890.00),
(6, 1, 1, 289.90),
(6, 7, 1, 189.00),
(7, 3, 1, 459.00),
(7, 10, 3, 24.90),
(8, 7, 1, 189.00),
(8, 8, 6, 12.90);
GO

-- 13. Verificación de la carga
SELECT 'Cliente' AS Tabla, COUNT(*) AS Filas FROM dbo.Cliente
UNION ALL SELECT 'Categoria',     COUNT(*) FROM dbo.Categoria
UNION ALL SELECT 'Producto',      COUNT(*) FROM dbo.Producto
UNION ALL SELECT 'Pedido',        COUNT(*) FROM dbo.Pedido
UNION ALL SELECT 'DetallePedido', COUNT(*) FROM dbo.DetallePedido;

SELECT p.ProductoID, p.Nombre, c.Nombre AS Categoria, p.PrecioLista, p.Stock, p.Activo
FROM dbo.Producto AS p
JOIN dbo.Categoria AS c ON c.CategoriaID = p.CategoriaID
ORDER BY p.ProductoID;
GO

/* ============================================================
   DATOS PREPARADOS PARA LAS ACTIVIDADES
   (para que cada actividad sepa con qué probar)

   Actividad 2 - Mantenimiento
     - Alta de cliente con Documento repetido: usar '70100001' (ya existe).
     - Alta de cliente nuevo: cualquier Documento que no esté en 70100001-70100010.
     - Actualización de cliente: el 3 y el 8 no tienen Correo; el 4 y el 8
       no tienen Telefono.
     - Cliente inactivo: el 10. Producto inactivo: el 5.
     - Alta de producto con nombre repetido: 'Router WiFi 6 AX1800' (ya existe).

   Actividad 3 y 4 - Transacción (registrar un pedido y descontar stock)
     - Escenario que confirma: cliente 2 pide 2 unidades del producto 2
       (stock 3) y 1 del producto 1 (stock 40). Al final: stock 1 y 39,
       un pedido y dos líneas nuevas.
     - Escenario que cancela por stock: cliente 2 pide 1 unidad del producto 1
       y 5 del producto 2 (stock 3). El stock del producto 1 no debe quedar
       descontado ni debe quedar un pedido a medias.
     - Otros casos de cancelación: producto 9 (stock 0), producto 5 (inactivo),
       cliente 10 (inactivo), cliente 99 (no existe).
     - Último en stock: producto 6 (stock 1).
   ============================================================ */
