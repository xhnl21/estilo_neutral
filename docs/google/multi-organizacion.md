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
| `ventas` | O (esquema de factura: la columna se corrió al eliminar `item_id`/`cantidad` de esta hoja — ver [Casos de Uso — UC-30](../casos-de-uso.md#uc-30-registrar-una-venta-factura-con-uno-o-mas-productos)) |
| `compras_divisas` | L |
| `resumen_diario` | I |
| `cuarentena` | I |
| `audit_log` | J |
| `reporte_migracion` | E (el encabezado real está en la fila 4, no en la 1 — esa hoja tiene un título/subtítulo arriba) |
| `checklist_iso` | G |

Además, la membresía usuario↔organización se modela con 3 hojas propias (no con una columna embebida en cada hoja de negocio):

- **`organizaciones`** (hoja nueva): la fuente de verdad de qué organizaciones existen.
  ```
  id                                     | nombre
  67774411-6aa1-4aa3-a4b2-d3fc6913b768   | Estilo Neutral
  ```
- **`usuarios`**: la entidad Usuario, sin ninguna referencia a organización — solo identifica cuentas de Google permitidas. Tiene su propio `id` (formato `u00000001`), igual que el resto de las entidades del sistema.
  ```
  id           | email                       | nombre
  u00000001    | neidapulgar1989@gmail.com   | Neida
  u00000002    | xhnl21@gmail.com            |
  ```
- **`usuario_organizacion`** (hoja nueva, **relación** 1:N — una organización tiene muchos usuarios): une `usuarios` con `organizaciones`.
  ```
  usuario_email               | organizacion_id
  neidapulgar1989@gmail.com   | 67774411-6aa1-4aa3-a4b2-d3fc6913b768
  xhnl21@gmail.com            | 67774411-6aa1-4aa3-a4b2-d3fc6913b768
  ```
  Se modela como hoja de relación separada (en vez de una columna `organizacion_id` directa en `usuarios`) para mantener separadas las entidades de su relación — ver [`UsuarioOrganizacion`](../../lib/models/usuario_organizacion.dart).
- **`seguridad`** (columnas A-C: `biometrico`, `desbloqueoFacial`, `dosFactores`, columna **D**: `usuario_email`). Es **una fila por usuario**, no por organización — ver la sección de abajo sobre por qué se corrigió este diseño.

> Las 9 hojas de negocio (`clientes`, `ventas`, etc.) siguen usando su columna `organizacion_id` embebida tal cual — ver tabla arriba. Ese es un 1:N correcto (muchos registros de negocio, una organización) y no necesita una hoja de relación separada; la relación explícita solo se justificó entre `usuarios` y `organizaciones`.
>
> **Excepción — `venta_items`:** los ítems de una factura (hoja `venta_items`, ver UC-30) **no** tienen su propia columna `organizacion_id`. Pertenecen a la organización de su venta/factura (`venta_items.venta_id` → `ventas.organizacion_id`), así que se filtran indirectamente a través de esa relación en vez de duplicar la columna.

## Por qué un UUID y no un slug legible

La primera versión usaba el string `estilo-neutral` como id. Se cambió a un UUID v4 (`67774411-6aa1-4aa3-a4b2-d3fc6913b768`) para que el identificador no dependa del nombre del negocio (si el negocio cambia de nombre, el id no debería cambiar) y para evitar colisiones si en el futuro se suman más organizaciones con nombres parecidos.

## Cómo se resuelve en runtime

1. Al hacer login (`login_page.dart`), después de que `AccessControlConfig` valida el email, se llama `SheetsDataService.organizacionIdForUsuario(email)`, que busca ese email en la hoja de relación `usuario_organizacion` (ya cargada) y devuelve su `organizacion_id`. Si el email no aparece ahí (por ejemplo, la hoja no se sincronizó todavía, o es un usuario nuevo sin membresía registrada), se usa un fallback seguro.
2. Se llama `dataService.setCurrentOrganizacion(organizacionId)` **y** `dataService.setCurrentUsuario(email)` — ambos quedan guardados en `SheetsDataService` y disparan `notifyListeners()`.
3. Todos los getters de las 9 hojas de negocio (`clientes`, `productos`, `ventas`, etc.) filtran automáticamente por `currentOrganizacionId` — ninguna pantalla necesita saber que existe el concepto de organización. El getter `seguridad`, en cambio, filtra por `currentUsuarioEmail` (ver más abajo).
4. Al cerrar sesión (`MainShell._handleLogout`), se limpia con `setCurrentOrganizacion(null)` y `setCurrentUsuario(null)` para que el próximo login resuelva de cero.
5. Los IDs de negocio (`c00000001`, `p00000001`, etc.) se siguen generando a partir del listado **completo** (`_clientes`, no el getter filtrado), así que siguen siendo únicos entre organizaciones aunque comparen el mismo Sheet — no hay riesgo de colisión.

## `set_metodo_seguridad` y por qué es por usuario, no por organización

**Diseño anterior (corregido):** la pantalla "Seguridad" ofrecía un único método por **organización**. Esto generaba un problema real: `SeguridadPage` detecta si el dispositivo actual soporta Biométrico/Face ID y, si el método activo dejó de ser compatible, lo resetea a "Ninguno" automáticamente. Como la fila de `seguridad` era compartida por toda la organización, un solo usuario abriendo la vista desde un equipo sin el hardware requerido **desactivaba el método para todos los demás usuarios**, incluidos los que sí tenían equipos compatibles.

**Diseño actual:** `seguridad` es **una fila por usuario** (columna D pasó de `organizacion_id` a `usuario_email`). Seleccionar un método llama a `SheetsDataService.setMetodoSeguridad(metodo)`, que:

1. Reemplaza la fila de `seguridad` del **usuario actual** (`currentUsuarioEmail`) con el nuevo estado (los 3 booleanos: solo el elegido en `true`, el resto en `false`).
2. Si ese usuario no tenía fila todavía, la crea.
3. Llama a `google_apps_script.js` con `action: "set_metodo_seguridad"`, mandando los 3 booleanos + `usuario_email` — el script escribe las 3 columnas de una sola vez en la fila correspondiente (ver [Apps Script](apps-script.md)).

Así, la auto-corrección de `SeguridadPage` por incompatibilidad de hardware solo afecta al usuario que abrió la vista desde ese dispositivo, no a toda la organización.

## Migrar los datos existentes (lo que ya se hizo una vez)

Cuando se agregó esta columna, las filas viejas no tenían valor — se les asignó el UUID de la organización por defecto (`67774411-6aa1-4aa3-a4b2-d3fc6913b768`, "Estilo Neutral") para que nada quedara huérfano ni oculto. Esto se hizo:

1. Editando el `.xlsx` local con un script de Python (`openpyxl`) que agregó la columna y el valor a cada hoja.
2. Subiendo ese `.xlsx` para reemplazar el contenido del Sheet real (ver [Automatización](automatizacion.md) para el modo automatizado, o "Archivo → Importar → Reemplazar hoja de cálculo" a mano).

Si en el futuro se suma una organización nueva, alcanza con crearla y asignarle usuarios desde los módulos **Organizaciones** y **Usuarios** de la app (ver abajo) — ya no hace falta editar el Sheet a mano para esto.

## Módulos "Usuarios" y "Organizaciones" en la app

Estas dos hojas (antes de mantenimiento manual únicamente en Google Sheets) tienen su propia vista en el menú lateral, bajo la categoría **Administración**, con CRUD completo:

- **Usuarios** (`UsuariosPage`, `lib/presentation/pages/usuarios_page.dart`): lista los usuarios autorizados y a qué organización pertenece cada uno. "Nuevo Usuario" pide email + nombre + organización, y crea a la vez la fila en `usuarios` y su membresía en `usuario_organizacion` (`SheetsDataService.addUsuario`). El email es **inmutable** una vez creado (es la clave que usan `seguridad` y el login) — al editar, solo se pueden cambiar el nombre y la organización (`updateUsuario`). Eliminar un usuario (`deleteUsuario`) borra su fila de `usuarios` y su membresía; no borra su fila de `seguridad` (queda huérfana pero inofensiva, nadie puede volver a loguearse con ese email para usarla).
- **Organizaciones** (`OrganizacionesPage`, `lib/presentation/pages/organizaciones_page.dart`): lista las organizaciones y cuántos usuarios tiene cada una. "Nueva Organización" solo pide el nombre — el `id` se genera como UUID v4 (`SheetsDataService._generarOrganizacionId`). Eliminar una organización con usuarios asignados está **bloqueado** (`deleteOrganizacion` devuelve `false` y la UI muestra un aviso) para no dejar membresías apuntando a una organización inexistente — hay que reasignar o eliminar esos usuarios primero. El ícono de personas en cada tarjeta abre un listado de sus miembros con dos acciones (`_showMiembrosDialog`): **agregar** un usuario existente (elegido de un desplegable que excluye a los que ya pertenecen a esta organización) o **mover** un miembro a otra organización — ambas llaman a `updateUsuario(usuario, organizacionId: ...)`, la misma función que usa el formulario de edición en Usuarios.

Ambos módulos persisten en el Sheet real vía `google_apps_script.js` (acciones `create`/`update`/`delete` sobre las 3 hojas, agregadas en el mismo despliegue que movió `seguridad` a clave por usuario).

## Salvaguarda: qué pasa si el Sheet real todavía no está migrado

**Incidente real:** antes de completar la migración manual del Sheet, editar un usuario desde el módulo **Usuarios** escribió datos corridos — el endpoint GViz, al no encontrar (o encontrar con otro formato) las hojas `organizaciones`/`usuario_organizacion` esperadas, devolvió filas de otra hoja del mismo documento, y la app las interpretó como si fueran válidas (por ejemplo, `usuario_email` terminó con el UUID de la organización en vez de un correo).

**Corrección aplicada:**

1. `SheetsDataService._fetchSheet` ahora acepta `expectedHeaders` y valida la fila 1 del CSV recibido contra el encabezado esperado antes de parsear. Si no coincide, la lectura se descarta (se trata como error de sincronización, no como datos válidos) — se usa para `usuarios`, `organizaciones`, `usuario_organizacion` y `seguridad`.
2. `SheetsDataService.schemaMultiOrgListo` (`bool`) es `true` solo si la hoja `organizaciones` fue leída con su encabezado nuevo (`id`, `nombre`) en la última sincronización.
3. `UsuariosPage` y `OrganizacionesPage` usan ese flag para **bloquear** crear/editar/eliminar (con un aviso visible y un diálogo explicativo) mientras el Sheet real no tenga el esquema migrado — en vez de operar sobre datos mal alineados.

Esto significa que, hasta que se haga la migración manual (agregar `id` a `usuarios`, crear `organizaciones` y `usuario_organizacion`, y cambiar la columna D de `seguridad`), estas dos vistas se muestran en modo solo lectura sobre los datos semilla en memoria.
