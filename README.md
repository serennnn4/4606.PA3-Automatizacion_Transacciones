# 📊 PA3 | NovaMarket - Automatización y Transacciones

> **Programación Avanzada de Base de Datos (30627) · ISIL**  
> **Motor:** Microsoft SQL Server | Autenticación de Windows | Instancia local

_
   
## 👥 Integrantes:

   * RODRIGO GOMEZ CARRASCO -  72207949@mail.isil.pE
   * MARIA FERNANDA LEON CATALAN -  75443768@mail.isil.pe
   * NADIA MABEL VINCES ASCA -  70474181@mail.isil.pe
   * LUIGI ALVA SANCHEZ -   48584750@mail.isil.pe
     
---

## Descripción: 
NovaMarket es una organización que necesita administrar clientes, productos y operaciones comerciales. Identificamos un problema crítico: el registro de ventas se ejecutaba mediante sentencias separadas desde la aplicación cliente. Si ocurría un fallo a mitad del proceso (ej. falta de stock), los pedidos quedaban registrados "a medias", corrompiendo la integridad de la información.

## Objetivo:
Automatizar las operaciones críticas directamente del lado del servidor mediante **procedimientos almacenados** y proteger la coherencia absoluta de los datos utilizando **transacciones explícitas** (principio de "todo o nada").

---

## 🛠️ Desarrollo por Actividades
Dividimos el desarrollo en los siguientes puntos:  

*   **Actividad 1 | Identificación del proceso a automatizar:** 
    Analizamos el proceso de **Registro de un Pedido**, que exige tres pasos inseparables: crear cabecera, insertar detalle y descontar stock. Definimos reglas de negocio y demostramos los peligros de la autoconfirmación (sentencias sueltas).
    
*   **Actividad 2 | Mantenimientos Parametrizados:** 
    Programamos objetos reutilizables (usp_Registrar_Cliente_Nuevo, usp_Actualizar_Datos_Clientes, usp_Eliminar_Cliente_ID) con parámetros de entrada/salida, control de duplicados y protección de integridad referencial.
    
*   **Actividad 3 | Diseño Transaccional:** 
    Creamos el procedimiento central usp_RegistrarPedido blindado con una **transacción explícita** (BEGIN TRANSACTION, COMMIT, ROLLBACK) y XACT_ABORT ON. Si el stock es insuficiente, toda la operación se revierte automáticamente.
    
*   **Actividad 4 | Batería de Pruebas:** 
    Ejecutamos 7 escenarios de validación (confirmaciones exitosas y cancelaciones forzadas), contrastando el estado de las tablas *antes y después* mediante una matriz de resultados.

---

## Solución propuesta:
Para resolver las necesidades de la organización, entregamos:
1. **Scripts modulares:** Desde el DDL inicial hasta la lógica de negocio encapsulada.
2. **Contratos de retorno (RETURN):** Códigos estandarizados para que cualquier app cliente entienda el resultado (0: Éxito, 1: Cliente inválido, 2: Producto inválido, 3: Falta de stock, 4: Datos incompletos).
3. **Garantía ACID:** Validación técnica de que el inventario y las ventas son consistentes incluso ante errores de red o fallas lógicas concurrentes.

---

## Ejecución
Abre **SQL Server Management Studio (SSMS)**, conéctate usando *Autenticación de Windows* y ejecuta los scripts en el siguiente orden estricto:

1. 00_esquema_y_datos_base.sql — Crea la BD PA3_NovaMarket y carga las tablas.
2. actividad1_proceso.sql — Demostración del problema inicial (sentencias sueltas).
3. actividad2_procedimientos.sql — Compila y prueba los mantenimientos de clientes.
4. actividad3_transaccion.sql — Crea el procedimiento transaccional usp_RegistrarPedido.
5. actividad4_pruebas.sqL — Ejecuta los 7 escenarios y despliega la matriz de validación.


---

## Evidencias:

### Actividad 1: Arquitectura y Modelado
*Arquitectura en dos capas y Diagrama de Entidad-Relación de la solución.*
<img width="1038" height="1268" alt="Flujo de Proceso" src="https://github.com/user-attachments/assets/87e6eaf9-12a5-465d-9066-12a800769e59" />
<img width="848" height="1233" alt="Diagrama ER" src="https://github.com/user-attachments/assets/4870f3c2-3f1c-4431-b247-28b1dc39eb47" />

### Actividad 2: Procedimientos de Mantenimiento
*Validación de respuestas y control de duplicados en la base de datos.*
<img width="873" height="1210" alt="Mantenimiento 1" src="https://github.com/user-attachments/assets/33e7cdfb-7420-4fee-a0da-e357109d24e0" />
<img width="892" height="1269" alt="Mantenimiento 2" src="https://github.com/user-attachments/assets/b20fd473-b3df-4e79-baf6-6dbcaab11369" />

### Actividad 3: Comportamiento Transaccional
*Demostración de ROLLBACK al intentar vender unidades sin stock disponible.*
<img width="874" height="1280" alt="Transacción 1" src="https://github.com/user-attachments/assets/b49df30e-3bba-4285-9c4f-1c2a60113a74" />
<img width="873" height="466" alt="Transacción 2" src="https://github.com/user-attachments/assets/380db605-99dd-433f-8e98-9b2a5417200d" />

### Actividad 4: Validación y Consistencia
*Matriz automatizada demostrando el paso exitoso (OK) de los 7 escenarios de prueba.*
<img width="873" height="1262" alt="Matriz de Pruebas" src="https://github.com/user-attachments/assets/1e76b294-828f-4e2d-b9b8-30ff0f90bd86" />

---


## Conclusiones:
* **Centralización:** Trasladar la lógica operativa al servidor centraliza las reglas de negocio; ya no importa si la venta viene por Web o Tienda, las validaciones son idénticas y seguras.
* **Integridad:** El uso de transacciones explícitas (BEGIN TRANSACTION y ROLLBACK) previno de forma demostrable que errores por falta de stock generaran registros de pedidos "huérfanos".
* **Escalabilidad:** Implementar contratos con valores RETURN facilita a los desarrolladores Frontend o Backend (capa cliente) capturar excepciones y mostrar mensajes claros al usuario final.

---

## Video de Exposición:
Video público de YouTube: https://youtu.be/632iR2fMAb0
