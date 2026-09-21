# Google Apps Script

El backend de escritura de la app es un único archivo: **[`google_apps_script.js`](../../google_apps_script.js)**, en la raíz del repo. Es la **única fuente de verdad** — no hay ninguna otra copia en el proyecto (hubo una vendorizada como string de Dart, `apps_script_source.dart`, pero se eliminó por quedar duplicada y desincronizada; no la recrees).

## Qué hace

Recibe peticiones HTTP (`doGet` / `doPost`) de la app Flutter y opera directamente sobre las hojas del Google Sheet:

- `doGet` — healthcheck, devuelve el ID/nombre de la planilla y la lista de hojas.
- `doPost` con `action`:
  - `create` / `update` / `delete` — CRUD sobre `clientes`, `inventario`, `ventas`, `compras_divisas` (y genérico para el resto).
  - `toggle_checklist` — cambia el estado de un ítem de `checklist_iso`.
  - `toggle_seguridad` — cambia un campo de la hoja `seguridad`, **por organización** (ver [Multi-organización](multi-organizacion.md)).
  - `upload_image` — sube una imagen a la carpeta de Google Drive configurada (`DRIVE_FOLDER_ID`) y devuelve la URL pública.

Todas las mutaciones quedan además registradas en la hoja `audit_log` vía `_appendAuditLog(...)`.

## Configuración de plataforma (`appsscript.json`)

```json
{
  "timeZone": "America/Caracas",
  "dependencies": {},
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8",
  "webapp": {
    "access": "ANYONE_ANONYMOUS",
    "executeAs": "USER_DEPLOYING"
  }
}
```

`executeAs: USER_DEPLOYING` es importante: el script corre con los permisos de quien lo desplegó (no de quien lo invoca), así la app no necesita su propio acceso a la planilla — solo necesita la URL pública del Web App.

## Desplegar manualmente (sin `clasp`)

Si preferís no usar la automatización (ver [Automatización](automatizacion.md)):

1. Abrí el Sheet real → **Extensiones → Apps Script**.
2. Borrá el contenido de `Código.gs` (o el archivo que exista) y pegá el contenido completo de `google_apps_script.js`.
3. Guardar (`Cmd+S`).
4. **Implementar → Administrar implementaciones → ✏️ (editar la implementación existente) → Versión: Nueva versión → Implementar.**

    ⚠️ Es clave editar la implementación **existente**, no crear una nueva — así la URL `/exec` no cambia y no hay que tocar `.env`. Si por error creás una implementación nueva, vas a tener que actualizar `APPS_SCRIPT_URL` en los 4 archivos `.env*` con la URL nueva.

5. Si es la primera vez, Google va a pedir autorizar el script (Avanzado → Ir a Estilo Neutral, no seguro → Permitir).

## Referencia rápida de IDs

- **Script ID** (identifica el proyecto completo, para `clasp clone`/`.clasp.json`): en el editor → ⚙️ Configuración del proyecto → "ID".
  Valor actual: `1Rk-Cz_t6_dNx7SAp9ZMFJTA-b6wKrgEp-58_XTeL1XE7Xy4BWRyD4Je6`
- **Deployment ID** (identifica una implementación Web App específica, la que define la URL `/exec`): se muestra al desplegar, o en Administrar implementaciones.
  Valor actual: `AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA`

## Requisito de cuenta: API de Apps Script

Para que `clasp` (o cualquier llamada programática a la Apps Script API) pueda leer/escribir el proyecto, hay que activar, **una vez por cuenta de Google**:

👉 [script.google.com/home/usersettings](https://script.google.com/home/usersettings) → activar **"API de Google Apps Script"**.

Sin esto, cualquier intento de `clasp push`/`clasp pull` falla con:
```
User has not enabled the Apps Script API.
```
