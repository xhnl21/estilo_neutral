# Multi-organización

La app soporta separar los datos de distintas organizaciones dentro del **mismo** Google Sheet, sin necesitar una planilla por cliente. Esta página documenta el esquema y por qué se diseñó así.

## Contexto y limitación conocida

La app lee las hojas vía el endpoint público **GViz CSV** de Google Sheets (`.../gviz/tq?tqx=out:csv&sheet=...`), que no tiene autenticación — cualquiera con el link puede leer los datos crudos. Por eso, esta separación por organización es **aislamiento a nivel de UI de la app**, no seguridad real de servidor: filtra qué se muestra en pantalla, pero no impide que alguien con el link del Sheet vea todo. Si en el futuro se necesita aislamiento real, habría que migrar la lectura a la API oficial de Google Sheets con OAuth por usuario, o a un backend propio.

## Esquema

Cada una de las 9 hojas de datos originales ganó una columna `organizacion_id` (String) como **última columna**:

| Hoja | Columna nueva |
|---|---|
| `clientes` | G |
| `inventario` | J (la columna I sigue siendo la fórmula `=IMAGE(...)`, no se tocó) |
| `ventas` | Q |
| `compras_divisas` | L |
| `resumen_diario` | I |
| `cuarentena` | I |
| `audit_log` | J |
| `reporte_migracion` | E (el encabezado real está en la fila 4, no en la 1 — esa hoja tiene un título/subtítulo arriba) |
| `checklist_iso` | G |

Además:

- **`seguridad`** (columnas A-C: `biometrico`, `desbloqueoFacial`, `dosFactores`) ganó una columna **D** `organizacion_id`. Dejó de ser una fila global única — ahora es **una fila por organización**.
- **`usuarios`** (hoja nueva): mapea qué organización tiene cada cuenta de Google permitida.
  ```
  email                       | organizacion_id                       | nombre
  neidapulgar1989@gmail.com   | 67774411-6aa1-4aa3-a4b2-d3fc6913b768   | Neida
  xhnl21@gmail.com            | 67774411-6aa1-4aa3-a4b2-d3fc6913b768   |
  ```

## Por qué un UUID y no un slug legible

La primera versión usaba el string `estilo-neutral` como id. Se cambió a un UUID v4 (`67774411-6aa1-4aa3-a4b2-d3fc6913b768`) para que el identificador no dependa del nombre del negocio (si el negocio cambia de nombre, el id no debería cambiar) y para evitar colisiones si en el futuro se suman más organizaciones con nombres parecidos.

## Cómo se resuelve en runtime

1. Al hacer login (`login_page.dart`), después de que `AccessControlConfig` valida el email, se busca ese email en `SheetsDataService.usuarios` (la hoja `usuarios` ya cargada) y se obtiene su `organizacionId`. Si el email no aparece ahí (por ejemplo, la hoja no se sincronizó todavía), se usa un fallback seguro.
2. Se llama `dataService.setCurrentOrganizacion(organizacionId)`, que queda guardado en `SheetsDataService` y dispara `notifyListeners()`.
3. Todos los getters de listas (`clientes`, `productos`, `ventas`, etc.) filtran automáticamente por ese id — ninguna pantalla necesita saber que existe el concepto de organización.
4. Al cerrar sesión (`MainShell._handleLogout`), se limpia con `setCurrentOrganizacion(null)` para que el próximo login resuelva de cero.
5. Los IDs de negocio (`c00000001`, `p00000001`, etc.) se siguen generando a partir del listado **completo** (`_clientes`, no el getter filtrado), así que siguen siendo únicos entre organizaciones aunque comparen el mismo Sheet — no hay riesgo de colisión.

## `toggle_seguridad` y organización

Los toggles de la pantalla "Seguridad" (biométrico / facial / 2FA) llaman a `SheetsDataService.toggleBiometrico()` (etc.), que:

1. Busca en memoria la fila de `seguridad` que coincide con la organización actual.
2. Si existe, la actualiza; si no, crea una fila nueva.
3. Llama a `google_apps_script.js` con `action: "toggle_seguridad"`, incluyendo `organizacion_id` en el payload — el script busca (o crea) la fila correspondiente en la hoja real (ver [Apps Script](apps-script.md)).

## Migrar los datos existentes (lo que ya se hizo una vez)

Cuando se agregó esta columna, las filas viejas no tenían valor — se les asignó el UUID de la organización por defecto (`67774411-6aa1-4aa3-a4b2-d3fc6913b768`, "Estilo Neutral") para que nada quedara huérfano ni oculto. Esto se hizo:

1. Editando el `.xlsx` local con un script de Python (`openpyxl`) que agregó la columna y el valor a cada hoja.
2. Subiendo ese `.xlsx` para reemplazar el contenido del Sheet real (ver [Automatización](automatizacion.md) para el modo automatizado, o "Archivo → Importar → Reemplazar hoja de cálculo" a mano).

Si en el futuro se suma una organización nueva, alcanza con:

1. Agregar una fila en la hoja `usuarios` (email + el `organizacion_id` que corresponda — nuevo UUID si es una organización nueva).
2. No hace falta tocar las otras hojas: las filas nuevas que cree esa organización ya se van a guardar con su propio `organizacion_id` automáticamente.
