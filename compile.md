# Estilo Neutral — Guía para compilar y correr el proyecto en otra máquina

> Toda la información de este documento (contraseñas, IDs, tokens) es de
> **prueba/QA**, no son credenciales reales de producción. Aun así, no subas
> este archivo a ningún lado público — está pensado para pasarlo directo
> entre el equipo.

## 1. Requisitos

- Flutter **3.47.1** (canal `stable`), Dart **3.13.1** — corré `flutter --version` para confirmar; si no coincide, usá `fvm` o instalá esa versión.
- Java 17 (lo pide `android/app/build.gradle.kts`, `sourceCompatibility`/`targetCompatibility = JavaVersion.VERSION_17`).
- Android SDK con `minSdk = 26`.
- Node.js (solo si vas a tocar `google_apps_script.js` — usa `clasp`).
- Python 3 (solo si vas a correr los scripts de `tools/sheets_sync/`).

## 2. Clonar e instalar dependencias

```bash
git clone <url-del-repo> estilo_neutral
cd estilo_neutral
flutter pub get
```

## 3. Variables de entorno (`.env*`)

Estos archivos **no están en git** (`.gitignore` los excluye, salvo
`.env.example`) — hay que crearlos a mano. Son constantes de compilación
(`String.fromEnvironment`), no se leen en runtime: si no los pasás con
`--dart-define-from-file`, la app cae a los valores por defecto
hardcodeados en el código (que en este proyecto ya apuntan a esta misma
hoja de prueba, así que probablemente "funciona igual" salvo por
`ALLOWED_EMAILS`).

Creá estos 3 archivos en la raíz del proyecto (mismo contenido que usamos
en este equipo, apuntando a la hoja de Google Sheets de prueba):

### `.env.dev`
```env
ENVIRONMENT=dev
APP_NAME=Estilo Neutral DEV
SPREADSHEET_ID=1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI
APPS_SCRIPT_URL=https://script.google.com/macros/s/AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA/exec
API_BASE_URL=https://dev.api.example.com
DEBUG_MODE=true
ENABLE_LOGS=true
SHOW_TECHNICAL_INFO=true
APP_PACKAGE_NAME=com.estiloneutral.es
ALLOWED_EMAILS=neidapulgar1989@gmail.com,xhnl21@gmail.com
```

### `.env.test` (flavor QA)
```env
ENVIRONMENT=qa
APP_NAME=Estilo Neutral QA
SPREADSHEET_ID=1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI
APPS_SCRIPT_URL=https://script.google.com/macros/s/AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA/exec
API_BASE_URL=https://qa.api.example.com
DEBUG_MODE=true
ENABLE_LOGS=true
SHOW_TECHNICAL_INFO=true
APP_PACKAGE_NAME=com.estiloneutral.es
ALLOWED_EMAILS=neidapulgar1989@gmail.com,xhnl21@gmail.com
```

### `.env` (flavor prod)
```env
ENVIRONMENT=prod
APP_NAME=Estilo Neutral
SPREADSHEET_ID=1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI
APPS_SCRIPT_URL=https://script.google.com/macros/s/AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA/exec
API_BASE_URL=https://api.example.com
DEBUG_MODE=false
ENABLE_LOGS=false
SHOW_TECHNICAL_INFO=false
APP_PACKAGE_NAME=com.estiloneutral.es
ALLOWED_EMAILS=neidapulgar1989@gmail.com,xhnl21@gmail.com
```

**Importante — `ALLOWED_EMAILS`:** es la lista blanca real de acceso
post-login (`AccessControlConfig`). Si tu cuenta de Google no está en esa
lista, el login con Google va a funcionar pero la app te va a rechazar
después con "cuenta no autorizada". Agregá tu email separado por coma si
hace falta.

Los tres `.env*` apuntan a la **misma hoja de Google Sheets real de
prueba** (`SPREADSHEET_ID`) y al mismo Apps Script Web App
(`APPS_SCRIPT_URL`) — no hay hojas separadas por ambiente todavía.

## 4. Android — firma y Google Sign-In (la parte que más rompe en máquina nueva)

### 4.1 Keystore de release (`upload-keystore.jks` + `key.properties`)

El keystore real está en este repo, pero **con el nombre cambiado** a
`upload-keystore.jks.md` (para que no lo pisen herramientas que ignoran
`*.jks`). Antes de compilar en modo **release**:

```bash
cp upload-keystore.jks.md android/app/upload-keystore.jks
```

Y creá `android/key.properties` (tampoco está en git) con:
```properties
storePassword=estiloneutral
keyPassword=estiloneutral
keyAlias=upload
storeFile=upload-keystore.jks
```

Sin este archivo, `build.gradle.kts` cae automáticamdo al firmado de
**debug** para el build type `release` (ver sección de abajo) — no falla,
pero firma con otra clave.

> ⚠️ Nota de seguridad: esta clave privada está en el historial de git
> (aunque disfrazada de `.md`). Si este repo va a dejar de ser privado, o
> si preferís no tener una clave de firma real versionada así, avisame y
> la rotamos / la sacamos del historial.

### 4.2 Google Sign-In en modo debug — el problema típico al clonar en otra máquina

Este proyecto **no usa `google-services.json`** — el login con Google
(`GoogleSignIn()` sin `clientId` explícito, en `lib/config/auth_config.dart`
y `lib/shared/google_sheets/sheets_auth.dart`) depende pura y
exclusivamente de que la huella **SHA-1** del certificado con el que
compilás esté autorizada en Google Cloud Console para el paquete
`com.estiloneutral.es`.

`flutter run` (modo debug) firma con `~/.android/debug.keystore` — un
archivo que Android genera automáticamente **por máquina**, con una huella
SHA-1 distinta en cada equipo. Por eso el login falla en una máquina nueva
aunque las variables de entorno estén bien puestas.

**Arreglo más simple** (mismo certificado en todo el equipo): copiar el
`debug.keystore` de una máquina que ya funciona a la nueva:
- macOS/Linux: `~/.android/debug.keystore`
- Windows: `%USERPROFILE%\.android\debug.keystore`

**Alternativa** (sin compartir el archivo): en la máquina nueva correr

```bash
cd android && ./gradlew signingReport
```

copiar el SHA-1 de la variante `debug`, y agregarlo en Google Cloud
Console → *APIs & Services* → *Credentials* → cliente OAuth Android de
`com.estiloneutral.es` (agregar huella adicional, no reemplazar la
existente).

Síntoma si esto está mal: el selector de cuenta de Google se abre bien,
pero al elegir la cuenta la app tira un error tipo
`PlatformException(sign_in_failed, ... DEVELOPER_ERROR ...)` /
`ApiException: 10`.

## 5. iOS

`ios/Runner.xcodeproj/project.pbxproj` ya usa
`PRODUCT_BUNDLE_IDENTIFIER = com.estiloneutral.es` (y
`com.estiloneutral.es.RunnerTests` para el target de tests) en las tres
configuraciones. Si al compilar para iOS ves referencias a `com.innovo.zas`
en archivos dentro de `ios/Flutter/` (`Generated.xcconfig`,
`flutter_export_environment.sh`, `ephemeral/`), son artefactos
autogenerados e ignorados por git de una build anterior — corré
`flutter clean && flutter pub get` para que se regeneren con el bundle ID
correcto.

## 6. Correr la app

Con VS Code, usá directamente los launch configs ya armados en
`.vscode/launch.json` ("Android - DEV (Debug)", "Android - TEST/QA
(Debug)", "Android - PROD (Debug)", y sus equivalentes iOS) — ya incluyen
el flag `--dart-define-from-file` correcto para cada flavor.

Por línea de comandos:
```bash
# DEV
flutter run --flavor dev --dart-define-from-file=.env.dev

# QA
flutter run --flavor qa --dart-define-from-file=.env.test

# PROD
flutter run --flavor prod --dart-define-from-file=.env
```

## 7. La hoja de Google Sheets y el backend (Apps Script)

- **Spreadsheet (datos):** https://docs.google.com/spreadsheets/d/1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI/edit
  Tiene que estar compartida como "Cualquier persona con el enlace: Lector" para que la lectura vía GViz CSV funcione sin login adicional.
- **Apps Script Web App (escritura/CRUD):** `https://script.google.com/macros/s/AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA/exec`
  Es el mismo deployment para los tres `.env*`. El código fuente vive en `google_apps_script.js` en la raíz del repo; se sube con `clasp` (ver sección 8).

## 8. Herramientas opcionales (solo si vas a tocar el backend)

### 8.1 Desplegar cambios a `google_apps_script.js`

```bash
cd tools/apps_script
npm install
npm run deploy
```

Requiere haber corrido antes `npx clasp login` (o `npm run login`) con una
cuenta de Google que tenga acceso de edición al proyecto de Apps Script
(`scriptId` en `.clasp.json` de la raíz del repo:
`1Rk-Cz_t6_dNx7SAp9ZMFJTA-b6wKrgEp-58_XTeL1XE7Xy4BWRyD4Je6`).

### 8.2 Scripts de migración / limpieza de datos (`tools/sheets_sync/`)

Son scripts Python que usan la Sheets API directamente (no pasan por el
Apps Script Web App). Necesitan:
- `tools/sheets_sync/client_secret.json` — credenciales OAuth de un
  proyecto de Google Cloud con la Sheets API + Drive API habilitadas
  (no están versionadas; pedilas si necesitás correr estos scripts).
- `tools/sheets_sync/token.json` — se genera solo la primera vez que
  corrés cualquier script (abre un flujo OAuth en el navegador).

### 8.3 Hoja de pruebas separada (para no ensuciar la hoja real al correr `flutter test`)

Los tests de `test/shared/*_test.dart` y algunos de `test/presentation/`
hacen CRUD real contra Google Sheets. Para no escribir en la hoja de
producción, apuntan a una copia separada, configurada en
`test/test_sheets_config.dart`:

- **Spreadsheet de test:** `1vtdKdAmM2AeuOceSC0eDaSAAAT8za_gLKB_QkU-Si9s`
- **Apps Script de test (`/exec`):** `https://script.google.com/macros/s/AKfycbx6GOO7X-T5L6sBYMfJX-3fzjcss21MxQFvk7ilx4huUwWOPKTk5pOmALdZcPunAw8kwA/exec`
  (proyecto Apps Script `scriptId`: `1tV_9i0gJfTUonOMmnLsguRdFSf-iohCixFdN1wKmECEF4Ug8Uwht3ACX`, fuente en `tools/apps_script_test/`)

Si ese deployment de test devuelve 403 al correr los tests, hay que
entrar una vez al editor de ese script
(https://script.google.com/d/1tV_9i0gJfTUonOMmnLsguRdFSf-iohCixFdN1wKmECEF4Ug8Uwht3ACX/edit)
→ Deploy → Manage deployments → confirmar el deployment existente (Google
exige un toque manual la primera vez para activar el acceso anónimo en un
deployment creado por API).

## 9. Checklist rápido para "no me anda en esta máquina"

- [ ] `flutter --version` da `3.47.1` / Dart `3.13.1`
- [ ] Existen `.env`, `.env.dev`, `.env.test` en la raíz (no solo `.env.example`)
- [ ] Tu email de Google está en `ALLOWED_EMAILS`
- [ ] Corriste con `--dart-define-from-file` (o el launch config correcto de VS Code), no un `flutter run` a secas
- [ ] El SHA-1 de tu `debug.keystore` está autorizado en Google Cloud Console (o copiaste el `debug.keystore` de otra máquina que ya funciona)
- [ ] Si es release: existen `android/app/upload-keystore.jks` y `android/key.properties`
- [ ] La hoja de Google Sheets sigue compartida como "Cualquier persona con el enlace"
