# Proceso de Aprendizaje 3 | Automatización y Transacciones

## Proyecto
  
  * **PA3** - Automatización y Transacciones
  * **Curso:** Programación Avanzada de Base de Datos (30627)
   
## Integrantes:

   * RODRIGO GOMEZ CARRASCO -  72207949@mail.isil.pE
   * MARIA FERNANDA LEON CATALAN -  75443768@mail.isil.pe
   * NADIA MABEL VINCES ASCA -  70474181@mail.isil.pe
   * LUIGI ALVA SANCHEZ -   48584750@mail.isil.pe


## Descripción: 
Se diseñó el siguiente proyecto para una organización que necesita administrar sus clientes, productos y operaciones comerciales. Actualmente, operaciones como el registro de ventas se ejecutan mediante sentencias separadas directamente desde la aplicación cliente. En la base de datos hemos resuelto este problema para evitar inconsistencias (como pedidos registrados a medias cuando falla el stock), trasladando la lógica de negocio al servidor.


## Objetivo:
Automatizar las operaciones del lado del servidor mediante procedimientos almacenados y proteger la coherencia de los cambios de la organización utilizando transacciones explícitas.  

## Desarrollo:
Dividimos el desarrollo en los siguientes puntos:  

* **Actividad 1 (Proceso a automatizar):** Identificamos el proceso de "Registro de un pedido" (cabecera, detalle y descuento de stock). Definimos las variables de entrada/salida y la regla de "todo o nada". Justificamos el uso de una arquitectura en dos capas para centralizar las reglas en el servidor.

* **Actividad 2 (Mantenimientos):** Programamos procedimientos almacenados (usp_Registrar_Cliente_Nuevo, usp_Actualizar_Datos_Clientes, usp_Eliminar_Cliente_ID) con parámetros de entrada, parámetros OUTPUT para IDs generados, y valores RETURN para manejar los distintos escenarios (éxito, error, duplicados).

* **Actividad 3 (Transacciones):** Desarrollamos el procedimiento usp_RegistrarPedido usando BEGIN TRANSACTION, COMMIT y ROLLBACK. Validamos que el stock no sea negativo, de modo que si un producto se agota durante la venta, toda la operación se cancela automáticamente.
* **Actividad 4 (Pruebas):** Ejecutamos los escenarios preparados en la base de datos base, comparando el estado de las tablas antes y después para un pedido confirmado y un pedido cancelado por falta de inventario.  


## Solución propuesta:
* Entregamos una solución estructurada que elimina la dependencia de autoconfirmación de SQL Server. 
* Con la transacción explícita en usp_RegistrarPedido, garantizamos la atomicidad de las ventas: ahora, si falla el descuento de stock de un solo producto, el bloque entero se revierte (ROLLBACK), protegiendo la consistencia de los datos.
* Centralizamos la validación de precios directamente desde Producto.PrecioListA en el servidor, impidiendo que la capa cliente pueda enviar precios alterados.  


## Indicaciones para ejecutar / revisar el proyecto:
Abrir SQL Server Management Studio (SSMS) y conectarse a la instancia local con Autenticación de Windows. Ejecutar los scripts en el siguiente orden:

*1 | 00 esquema y datos base.sql | Crea la BD PA3_NovaMarket, las 5 tablas y carga los datos de prueba. |
*2 | actividad1 proceso.sql | Documenta entradas/salidas y demuestra el problema de la autoconfirmación. |
*3 | actividad2_procedimientos.sql | Crea y ejecuta los SPs de mantenimiento de clientes. |
*4 | actividad3_transaccion.sql | Crea el procedimiento transaccional usp_RegistrarPedido. |
*5 | actividad4_pruebas.sql | Ejecuta la matriz de pruebas y muestra las capturas de estado. |



## Evidencias:


## Conclusiones:



## Video de Exposición:
Video público de YouTube:
