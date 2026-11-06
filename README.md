# Proceso de Aprendizaje 3 | NovaMarket - Automatización y Transacciones

  
  * **PA3** - Automatización y Transacciones
  * **Curso:** Programación Avanzada de Base de Datos (30627)
  * **Motor:** SQL Server | Autenticación de Windows | Instancia local
   
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

* **Actividad 1 (Identificación del proceso a automatizar):**
Analizamos el proceso de **Registro de un Pedido**, el cual involucra tres operaciones dependientes (crear cabecera, insertar líneas de detalle y descontar stock). Definimos entradas, salidas, reglas de negocio estrictas y demostramos por qué el método tradicional de enviar sentencias sueltas deja la base de datos inconsistente si ocurre un fallo a mitad de camino.

* **Actividad 2 (Mantenimientos):**
Programamos objetos reutilizables en el servidor para el mantenimiento de clientes (usp_Registrar_Cliente_Nuevo, usp_Actualizar_Datos_Clientes, usp_Eliminar_Cliente_ID) utilizando parámetros parametrizados, control de duplicados y validación de restricciones de integridad referencial.

* **Actividad 3 (Transacciones):**
 Implementamos el procedimiento almacenado central usp_RegistrarPedido integrando una **transacción explícita** (BEGIN TRANSACTION, COMMIT, ROLLBACK) y la directiva de seguridad XACT_ABORT ON. Esto garantiza que si el stock es insuficiente o ocurre un error, toda la operación se revierte automáticamente.

* **Actividad 4 (Pruebas):** Ejecutamos una batería rigurosa de 7 escenarios de prueba (tanto de confirmación exitosa como de cancelación por reglas de negocio o stock) contrastando el estado de las tablas antes y después de cada ejecución y validando el comportamiento con una matriz automatizada.


## Solución propuesta:
* Entregamos scripts ejecutables modulares que abarcan desde la creación de esquemas y datos base hasta la automatización server-side mediante objetos robustos (usp_RegistrarPedido y procedimientos de mantenimiento).
  
* Incorporamos contratos de retorno estructurados (RETURN 0 para éxito, 1 para cliente inválido, 2 para producto inválido, 3 por falta de stock y 4 por datos incompletos) que estandarizan la comunicación con cualquier aplicación cliente.
  
* Validamos técnicamente que las transacciones explícitas evitan registros parciales y garantizan la consistencia del inventario ante concurrencia y fallas lógicas.

## Indicaciones para ejecutar / revisar el proyecto:
Abrir SQL Server Management Studio (SSMS) y conectarse a la instancia local con Autenticación de Windows. Ejecutar los scripts en el siguiente orden:

*1. Conéctate a tu instancia local de SQL Server usando **Autenticación de Windows**.
*2. Ejecuta el script base del proyecto (`00_esquema_y_datos_base.sql) para crear la base de datos PA3_NovaMarket y cargar el estado inicial de tablas.
*3. Abre y ejecuta el script de la **Actividad 1** (actividad1_proceso.sql) para revisar el análisis del proceso y la demostración del problema con sentencias sueltas.
*4. Abre y ejecuta el script de la **Actividad 2** (actividad2_procedimientos.sql) para compilar los procedimientos de mantenimiento de clientes y sus casos de prueba.
*5. Abre y ejecuta el script de la **Actividad 3** (actividad3_transaccion.sql) para crear el procedimiento transaccional usp_RegistrarPedido.
*6. Abre y ejecuta el script de la **Actividad 4** (actividad4_pruebas.sql) completo (con F5) para correr los 7 escenarios de validación y desplegar la matriz de resultados comparativa.


## Evidencias:
###Actividad 1:
* **Arquitectura Cliente/Servidor y Flujo del Proceso:**
<img width="1038" height="1268" alt="image" src="https://github.com/user-attachments/assets/87e6eaf9-12a5-465d-9066-12a800769e59" />

* **Diagrama Entidad-Relación:**
<img width="848" height="1233" alt="image" src="https://github.com/user-attachments/assets/4870f3c2-3f1c-4431-b247-28b1dc39eb47" />

###Actividad 2:
* **Ejecución de Procedimientos de Mantenimiento:**
<img width="873" height="1210" alt="image" src="https://github.com/user-attachments/assets/33e7cdfb-7420-4fee-a0da-e357109d24e0" />
<img width="892" height="1269" alt="image" src="https://github.com/user-attachments/assets/b20fd473-b3df-4e79-baf6-6dbcaab11369" />

###Actividad 3:
* **Demostración de Transacción y ROLLBACK:**
<img width="874" height="1280" alt="image" src="https://github.com/user-attachments/assets/b49df30e-3bba-4285-9c4f-1c2a60113a74" />
<img width="873" height="466" alt="image" src="https://github.com/user-attachments/assets/380db605-99dd-433f-8e98-9b2a5417200d" />

###Actividad 4:
* **Matriz de Pruebas Automatizada:**
<img width="873" height="1262" alt="image" src="https://github.com/user-attachments/assets/1e76b294-828f-4e2d-b9b8-30ff0f90bd86" />


## Conclusiones:
* Trasladar la lógica operativa al servidor mediante **procedimientos almacenados** centraliza las reglas de negocio, permitiendo que cualquier aplicación cliente se comunique de forma estandarizada y segura.
* El uso de **transacciones explícitas** (BEGIN TRANSACTION y ROLLBACK) es indispensable para garantizar el principio de "todo o nada", previniendo que fallos por stock insuficiente dejen registros de pedidos huérfanos o inventarios alterados parcialmente.
* La implementación de contratos mediante valores de retorno (RETURN) facilita el manejo de excepciones lógicas en la capa cliente, mejorando la robustez general del sistema backend.


## Video de Exposición:
Video público de YouTube:
