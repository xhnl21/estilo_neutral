# Estándar de hojas y escrituras

Reglas que debe cumplir toda hoja de Google Sheets y todo código que la lea o escriba. Surgen de los errores que se encontraron en la revisión del 2026-10-06 ([informe.md](../informe.md)). Cada regla dice qué error evita.

Las reglas R1 (columna `id`, ID del servidor, lectura con encabezado), R2, R4 y R7 las verifican automáticamente los tests de [`test/standards/estandar_hojas_test.dart`](../test/standards/estandar_hojas_test.dart). Si escribís código que no cumple, esos tests fallan. Esos tests tienen listas de pendientes que solo pueden achicarse; desde el 2026-10-06 están vacías, así que cualquier incumplimiento nuevo hace fallar la suite. No agregues entradas a esas listas: corregí el código.

---

## R1. Toda hoja tiene columna `id` en la columna A, generada por el servidor

- La columna A se llama `id` y tiene un prefijo propio, por ejemplo `c00000001` (clientes) o `rd00000001` (cierres). El prefijo se declara en `ID_PREFIXES` de `google_apps_script.js`.
- **El ID lo genera el servidor.** Al crear, la app no envía `id`: usa `_crearConRollback`, que devuelve el ID real.
- Editar y eliminar se hace **siempre por ID**. Nunca por la posición en una lista, porque las listas de la app están filtradas por organización, ni por otro campo, porque los demás campos pueden repetirse.
- Única excepción permitida: `organizaciones`, que usa un UUID v4 generado en el teléfono.

**Al leer:** cada `safeFetch` declara `expectedHeaders` empezando por `'id'`, y la URL de gviz lleva `headers=1`. Sin `headers=1`, gviz adivina cuántas filas son encabezado y en hojas solo de texto mezcla filas de datos con él; así la bitácora se leía vacía. Los modelos leen la fila con `FilaHoja.leer(row, '<prefijo>')`, que también acepta el formato anterior a la columna `id`.

**Migración de hojas existentes:** `migrarEsquema()` en el script (acción `migrar_esquema`) agrega la columna `id` a las hojas de `HOJAS_MIGRABLES` y numera las filas existentes. Es idempotente, y cada escritura en esas hojas la ejecuta antes de operar.

**Evita:** IDs duplicados cuando dos teléfonos crean a la vez; editar o borrar el registro equivocado (C3, C5, C8, C9, C10).

**Si una regla de negocio exige unicidad** (por ejemplo, un cierre por día y organización), se valida al crear, en la app y en el script. Eso no reemplaza al ID.

## R2. Toda hoja que la app crea o edita tiene una rama explícita en el script

- En `_handleCreate` y `_handleUpdate` de `google_apps_script.js` tiene que haber una rama `sheetName === "<hoja>"` que escriba cada columna **en su posición**.
- Si la hoja necesita reglas propias (unicidad, migración), se usa un manejador dedicado despachado en `doPost`, como `_handleResumenDiario`.
- La rama genérica `Object.values(data)` no se usa para hojas nuevas.

**Evita:** columnas escritas en otro orden, ediciones que responden "success" sin escribir nada (C6).

## R3. Los textos que parecen números o fechas se escriben como texto

Sheets convierte `"0414"` en `414`, `"070133805"` en `70133805`, `"2026-10-06"` en una fecha con formato local, y un número de orden de 20 dígitos pierde precisión.

- Los valores de este tipo (códigos, cédulas, RIF, teléfonos, fechas, números de orden, tallas) se escriben con `_comoTexto()` (anteponer `'`) o con la columna en formato texto (`setNumberFormat('@')`).
- Si una columna ya tiene valores mezclados, se normaliza la columna completa. gviz (con el que la app lee las hojas) devuelve **vacíos** los valores del tipo minoritario de una columna. Ejemplos: `_repararColumnaCodigosTelefono`, `_repararColumnaFechasResumen`.
- Al leer, la app tolera el formato viejo. Por ejemplo, `CodigoTelefono.normalizarCodigo` convierte `414` en `0414`.

**Evita:** C7 (códigos de teléfono), teléfonos sin el 0, fechas que la app lee como "hoy".

## R4. Toda escritura espera la confirmación del servidor y revierte si falla

En `SheetsDataService` **solo** estos helpers hablan con el servidor:

| Helper | Para |
|---|---|
| `_crearConRollback(hoja, data, revertir:)` | Crear. Devuelve el ID real; si falla, revierte y lanza `StateError`. |
| `_sincronizarConRollback(payload, revertir:)` | Editar y eliminar. Exige `{status: "success"}`; si no, revierte y lanza `StateError`. |
| `executeBatchTransaction(tx)` | Operaciones atómicas de varias hojas. El que lo llama revierte si falla (ver `registrarAbono`). |

Patrón obligatorio para un método público de escritura:

1. Validar. Si algo falla, lanzar `ArgumentError` sin tocar nada.
2. Aplicar el cambio local (la UI lo ve al instante) y llamar a `notifyListeners()`.
3. Llamar al helper con una función `revertir` que deshaga **exactamente** ese cambio, buscando por ID.
4. El Cubit hace `await`, captura `StateError` y `ArgumentError`, y muestra el mensaje (sin el prefijo "Bad state:").

**Contadores (stock, deuda del cliente):** se envían como diferencia con `BatchOperation.increment` (el script la suma al valor que tenga la celda en ese momento, y devuelve el resultado en `results`), nunca como valor final calculado en el teléfono. Un valor absoluto pisa lo que otro dispositivo haya cambiado en el ínterin. Las columnas que se pueden incrementar están en `COLUMNAS_INCREMENTABLES` del script.

Consecuencia: **sin conexión no se puede escribir.** El cambio se revierte y el usuario ve el error. No hay cola de cambios pendientes; si alguna vez hace falta, tiene que diseñarse aparte y no reintroducir los registros "pendientes locales".

Prohibido: llamar a `_postToAppsScript` o `_crearEnServidor` sin `await`, o sin revertir si fallan; y mostrar "éxito" sin la confirmación del servidor.

**Evita:** cambios que solo existen en el teléfono y se pierden al refrescar (C4); éxitos falsos (C6, P2); abonos contados dos veces (C3).

## R5. Editar parte del original: `copyWith`, nunca reconstruir el modelo

- Para editar se usa `original.copyWith(campo: valor)`. Reconstruir el modelo a mano (`Modelo(...)`) hace que los campos omitidos tomen su valor por defecto. Así se perdía `organizacionId`, que caía en la organización por defecto, y la cédula del cliente.
- Los campos que son clave (ID, organización y, si aplica, la fecha del cierre) **no se editan**. El servicio los copia del registro original.

**Evita:** C1 de Clientes, P1, la cédula borrada al registrar ventas.

## R6. Todo dato se filtra y se busca dentro de la organización actual

- Las listas públicas de `SheetsDataService` filtran por `_matchesCurrentOrg`.
- Las operaciones buscan por ID y, si la hoja tiene `organizacion_id`, verifican que coincida, tanto en la app como en el script.

**Evita:** que una organización modifique datos de otra (C5, C8, C9).

## R7. Sin valores inventados

- No hay usuarios de auditoría ficticios (`'Antigravity Senior Agent'`, `'Operador App'`, `'Auditor Manual'`). Se usa `currentUsuarioEmail`; si no hay usuario, la acción no se permite.
- No hay valores de respaldo para datos de negocio: `double.tryParse(x) ?? 474` o `?? 0` con un monto mal escrito tienen que mostrar un error de validación, no guardar un número inventado.
- Los formularios no vienen precargados con montos ni datos de ejemplo que se puedan guardar por error: se usa `hint`.
- Al leer, una fecha ilegible no se convierte en "hoy": se usa `parseFechaHoja` / `fechaHojaObligatoria` (`lib/models/fecha_hoja.dart`) y la fila se descarta con una advertencia en el log.

## R8. El estado de pantalla vive en Cubits

Ver [CLAUDE.md](../CLAUDE.md). Cada formulario que escribe tiene su Cubit, que valida, llama al servicio, espera el resultado y emite el error o el éxito. Ejemplos de referencia: `ClienteFormCubit`, `NuevaVentaCubit`, `AbonoCubit`.

---

## Checklist para una hoja o un formulario nuevo

- [ ] Columna `id` en A, con prefijo en `ID_PREFIXES` (R1).
- [ ] Ramas explícitas en `_handleCreate` y `_handleUpdate`, o un manejador propio (R2).
- [ ] Columnas de texto protegidas con `_comoTexto` o formato `@` (R3).
- [ ] Métodos del servicio con `_crearConRollback` / `_sincronizarConRollback` y `revertir` (R4).
- [ ] Edición con `copyWith`; ID y organización no editables (R5).
- [ ] Búsqueda por ID dentro de la organización actual (R6).
- [ ] Validación sin valores inventados (R7).
- [ ] Cubit propio para el formulario (R8).
- [ ] Encabezados de la hoja en `expectedHeaders` del fetch, si aplica.
- [ ] Tests con un servidor simulado (`FakeHttpClientAdapter` o un `HttpClientAdapter` propio), que cubran el éxito y el rollback.
- [ ] Desplegar el script primero en test (`tools/apps_script_test/deploy.sh`) y después en producción (`tools/apps_script/deploy.sh`).
