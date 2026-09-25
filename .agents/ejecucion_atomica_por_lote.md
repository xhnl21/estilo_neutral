# PROMPT: Implementación de Transacciones Atómicas por Lote (All-or-Nothing) en Flutter + Google Apps Script

## Contexto y Problema a Resolver

Actualmente, las operaciones compuestas (por ejemplo: registrar una venta con múltiples ítems, descontar stock de inventario, registrar un abono y asentar en `audit_log`) se envían al backend en múltiples peticiones HTTP independientes hacia Google Apps Script. Si una de las peticiones falla por latencia o error de red, la base de datos de Google Sheets queda en un estado inconsistente y parcialmente corrupto (violación de atomicidad).

## Objetivo General

## Implementar un sistema de **Transacciones Atómicas por Lote (Batch Transactions)** en el stack completo (Google Apps Script + Cliente Flutter Dart), garantizando el principio de **"Todo o Nada" (All-or-Nothing)**: si una sola operación del lote falla, ninguna de las operaciones del lote debe persistirse.

## Restricciones Obligatorias del Proyecto

1. **Regla de Estado Estricta:** BLoC / Cubit (`flutter_bloc`) con estados inmutables `Equatable` es el único patrón permitido en la capa de presentación (ver `AGENTS.md`). Ningún widget de presentación debe llamar directamente al servicio de datos ni usar `ListenableBuilder`.
2. **Límite Estricto de Tamaño de Archivo:** NINGÚN archivo nuevo o modificado puede superar las **500 líneas de código**. Si un módulo o servicio crece, debe particionarse en clases auxiliares, handlers o mixins especializados.
3. **Cero Polling y Prevención de Inyección:** Mantener la sanitización contra inyección de fórmulas (CWE-1236) al escribir en celdas de Sheets.
4. **Verificación:** Al finalizar, `flutter analyze` debe arrojar 0 advertencias/errores y `flutter test` debe pasar al 100%.

---

## Requerimientos Técnicos

### 1. Backend: Google Apps Script (`google_apps_script.js`)

- Agregar el handler de acción `"batch"` dentro de `doPost(e)`:
  ```json
  {
    "action": "batch",
    "transactionId": "tx-1727271234",
    "operations": [
      { "action": "create", "sheet": "ventas", "data": { ... } },
      { "action": "batch_create", "sheet": "venta_items", "dataList": [ ... ] },
      { "action": "update_cell", "sheet": "inventario", "id": "p001", "field": "stock", "newValue": 15 },
      { "action": "create", "sheet": "audit_log", "data": { ... } }
    ]
  }
  Control de Concurrencia y Bloqueo: Utilizar LockService.getScriptLock() con espera de hasta 10 segundos antes de comenzar la transacción.
  Mecanismo de Atomicidad (Rollback / Staging en Memoria):
  Leer los datos necesarios antes de escribir y validar todas las pre-condiciones (ej. existencia de IDs, stock suficiente).
  Si alguna validación falla o una fila no puede insertarse/actualizarse, revertir cualquier cambio en memoria y responder con error HTTP (status: "error", code: 400/409), asegurando que la hoja no se modifique.
  Si todas las operaciones son válidas, aplicar los cambios en bloque (Range.setValues() / appendRow) y registrar la auditoría correspondiente dentro del mismo lock.
  ```

2. Frontend: Modelos y Abstracción de Transacciones Dart
   Crear una entidad inmutable para operaciones y transacciones en lib/models/batch_transaction.dart:
   BatchOperation: define sheet, action (create, update, delete, updateField), data o dataList, y claves de identificación.
   BatchTransaction: identificador de transacción único (UUID), lista inmutable de operaciones y timestamp.
   BatchTransactionResult: estado del lote (success / failure), errores detallados y datos retornados.
3. Frontend: Capa de Red y Repositorio (SheetsDataService)
   Implementar el método transaccional:
   dart
   Future<BatchTransactionResult> executeBatchTransaction(BatchTransaction transaction);
   En caso de éxito, actualizar de forma sincrónica la memoria caché local de las colecciones afectadas y notificar a los Cubits escuchas en un único ciclo de refresco (evitando re-renderizados innecesarios).
   En caso de fallo de red o error de servidor, garantizar que la memoria local permanezca inalterada.
4. Integración en Cubits de Presentación
   Refactorizar las operaciones complejas (especialmente en VentasCubit al registrar una venta completa con ítems y actualizar stock) para que compongan un BatchTransaction y lo despachen mediante executeBatchTransaction(...).
   Emitir estados de progreso claros (loading, success, failure) sin romper la UI ni los contratos existentes.
5. Pruebas Automatizadas
   Crear pruebas unitarias para BatchTransaction y BatchTransactionResult en test/models/batch_transaction_test.dart.
   Crear pruebas de integración/unitarias simulando respuestas exitosas y de fallo en test/shared/google_sheets/batch_transaction_test.dart.
   Entregables Esperados
   Código fuente modificado en google_apps_script.js con el soporte para transacciones por lote atómicas.
   Nuevos modelos y métodos de servicio en Flutter.
   Integración en VentasCubit o el cubit de negocio relevante.
   Pruebas unitarias ejecutadas con éxito.
   Reporte de conformidad confirmando que ningún archivo sobrepasa las 500 líneas y que flutter analyze arroja 0 errores.
