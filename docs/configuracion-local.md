# Archivos ignorados y configuración

Este documento lista **todo lo que el proyecto necesita y que no está en git**: archivos que `.gitignore` excluye, porque tienen credenciales, datos personales o se generan en cada máquina, y configuraciones que viven fuera del repositorio (Apps Script, Google Cloud, Firebase). Para cada uno se indica para qué sirve, quién lo lee, cómo se obtiene y qué campos tiene.

**Regla:** ninguno de estos archivos se commitea ni se comparte por chat o email. Acá se documentan los **nombres de los campos**, nunca sus valores. Para ver qué archivos ignorados hay en una máquina:

```bash
git status --ignored --short | grep '^!!'
```

Última revisión: 2026-10-07.

---

## 1. Resumen

| Archivo / configuración | Para qué | Lo lee | ¿Obligatorio? | Cómo se obtiene |
|---|---|---|---|---|
| `.env`, `.env.dev`, `.env.test` | Variables de compilación por variante (hoja, Apps Script, logs) | `flutter run/build --dart-define-from-file` | Sí, para compilar bien | Copiar `.env.example` (§2.1) |
| `android/key.properties` | Contraseñas y alias del keystore de firma | `android/app/build.gradle.kts` | Para builds release | Se crea a mano (§2.2) |
| `android/app/upload-keystore.jks` | Certificado de firma de la app Android | Gradle (vía `key.properties`) | Para builds release | Se genera una vez con `keytool` (§2.2) |
| `android/local.properties` | Rutas del SDK de Android y de Flutter | Gradle | Sí | Lo genera Flutter (§2.3) |
| `android/app/google-services.json` | Configuración de Firebase para Android (FCM) | Plugin `google-services` | Para notificaciones | Consola de Firebase (§2.4) |
| `ios/Runner/GoogleService-Info.plist` | Configuración de Firebase para iOS (FCM) | Firebase en iOS | Para notificaciones en iOS | Consola de Firebase (§2.5) |
| `client_secret_*.json` (raíz) | Referencia de los clientes OAuth de Google Sign-In | Nadie (solo consulta) | No | Google Cloud Console (§2.6) |
| `tools/sheets_sync/client_secret.json` | Cliente OAuth de los scripts Python de migración | `tools/sheets_sync/*.py` | Solo para esos scripts | Google Cloud Console (§2.7) |
| `tools/sheets_sync/token.json` | Sesión OAuth cacheada de esos scripts | `tools/sheets_sync/*.py` | Se genera solo | Primera ejecución (§2.7) |
| `~/.clasprc.json` (fuera del repo) | Sesión de `clasp` para desplegar el Apps Script | `tools/apps_script*/deploy.sh` | Para desplegar | `bash tools/apps_script/login.sh` (§2.8) |
| `.claude/settings.local.json` | Permisos locales de Claude Code | Claude Code | No | Se crea a mano (§2.9) |
| `respaldos/` | Copias de la hoja de producción y lotes de corrección | Personas (restauración) | No | Se generan antes de cada corrección de datos (§2.10) |
| Propiedad del script `FCM_SERVICE_ACCOUNT` | Credencial para enviar notificaciones FCM | `google_apps_script.js` | Para notificaciones | Editor de Apps Script (§3.1) |

Además se ignoran archivos que **se generan solos** (§4).

---

## 2. Archivos ignorados, campo por campo

### 2.1 `.env`, `.env.dev`, `.env.test`

Variables de compilación (`--dart-define-from-file`). El modelo versionado es **`.env.example`**: se copia y se completa.

| Archivo | Variante (flavor) | Comando |
|---|---|---|
| `.env.dev` | `dev` (`com.estiloneutral.es.dev`) | `flutter run --flavor dev --dart-define-from-file=.env.dev` |
| `.env.test` | `qa` (`com.estiloneutral.es.qa`) | `flutter run --flavor qa --dart-define-from-file=.env.test` |
| `.env` | `prod` (`com.estiloneutral.es`) | `flutter run --flavor prod --dart-define-from-file=.env` |

| Campo | ¿La app lo lee? | Qué hace | Valor por defecto en el código | Ejemplo |
|---|---|---|---|---|
| `ENVIRONMENT` | Sí (`EnvironmentConfig`, `Logger`) | Nombre del entorno: `dev`, `qa` o `prod`. | `prod` | `dev` |
| `SPREADSHEET_ID` | Sí (`SheetsConfig`) | ID de la hoja de Google Sheets que la app lee. | La hoja de producción | `1V8x…` |
| `APPS_SCRIPT_URL` | Sí (`SheetsConfig`) | URL `/exec` de la implementación del Apps Script que recibe las escrituras. | **Una implementación vieja** (ver §6) | `https://script.google.com/macros/s/<id>/exec` |
| `DEBUG_MODE` | Sí (`Logger`) | Activa el modo depuración del log. | `false` | `true` |
| `ENABLE_LOGS` | Sí (`Logger`) | Escribe logs en consola. | `false` | `true` |
| `SHOW_TECHNICAL_INFO` | Sí (`EnvironmentConfig`) | Muestra nombres de hojas y metadatos técnicos en pantalla. | `false` | `false` |
| `APP_NAME` | No | Informativo. El nombre visible sale de cada variante en `build.gradle.kts`. | — | `Estilo Neutral` |
| `API_BASE_URL` | No | Sin uso actual. | — | — |
| `APP_PACKAGE_NAME` | No | Informativo. El paquete real lo fija cada variante. | — | `com.estiloneutral.es` |
| `ALLOWED_EMAILS` | **No (obsoleto)** | Antes era la lista blanca de acceso. Desde el 2026-10-06 el acceso lo decide la hoja `usuarios`. Se puede borrar. | — | — |

> **Atención:** hoy los tres `.env*` apuntan a la **misma hoja y al mismo Apps Script de producción**. Las variantes `dev` y `qa` escriben datos reales. Para aislarlas, `.env.dev` y `.env.test` tendrían que apuntar a una copia de la hoja y a la implementación de test (`AKfycbx6GOO7…`, ver §3.2).

### 2.2 `android/key.properties` y `android/app/upload-keystore.jks`

Firma de las builds release de Android. Están excluidos por `android/.gitignore` (`key.properties`, `**/*.jks`).

`key.properties`:

| Campo | Qué es |
|---|---|
| `storeFile` | Ruta del keystore, relativa a `android/app/` o a `android/`. Hoy: `upload-keystore.jks`. |
| `storePassword` | Contraseña del keystore. |
| `keyAlias` | Alias de la clave dentro del keystore. |
| `keyPassword` | Contraseña de la clave. |

- Si `key.properties` no existe, `build.gradle.kts` firma el release con la clave de **debug**, que Google Play no acepta.
- Cómo generar el keystore: `upload-keystore.jks.md` en la raíz.
- **Respaldo obligatorio:** guardar el `.jks` y sus contraseñas en un gestor de contraseñas. Si se pierden y la app no usa *Play App Signing*, no se pueden publicar actualizaciones.
- La huella **SHA-1** de este keystore tiene que estar registrada en el cliente OAuth Android de Google Cloud, si no Google Sign-In falla (ver `docs/google/sign-in.md`).

### 2.3 `android/local.properties`

Lo genera Flutter (`flutter pub get` / `flutter build`). No se edita a mano.

| Campo | Qué es |
|---|---|
| `sdk.dir` | Ruta del Android SDK. |
| `flutter.sdk` | Ruta del SDK de Flutter. `settings.gradle.kts` falla si falta. |
| `flutter.buildMode` | Modo de la última compilación. |
| `flutter.versionName` / `flutter.versionCode` | Versión tomada de `pubspec.yaml` (`version:`). |

### 2.4 `android/app/google-services.json` (Firebase, Android)

Se descarga de la consola de Firebase (paso a paso en `informe.md` §2.3, paso 2). Un solo archivo trae las tres apps: `com.estiloneutral.es`, `.dev` y `.qa`.

| Campo | Qué es |
|---|---|
| `project_info.project_number` | Número del proyecto (es el *sender ID* de FCM). |
| `project_info.project_id` | ID del proyecto de Firebase / Google Cloud. |
| `project_info.storage_bucket` | Bucket de Storage (no se usa). |
| `client[].client_info.mobilesdk_app_id` | ID de la app en Firebase (uno por variante). |
| `client[].client_info.android_client_info.package_name` | Paquete de la variante. Tiene que coincidir exactamente. |
| `client[].api_key[].current_key` | Clave de API de cliente. No es secreta, pero no se publica. |
| `client[].oauth_client` | Clientes OAuth asociados (no se usan para FCM). |

- `android/app/build.gradle.kts` aplica el plugin `com.google.gms.google-services` **solo si este archivo existe**. Sin él, la app compila y las notificaciones quedan desactivadas.
- El plugin elige la app que corresponde a cada variante. Se verificó con AGP 9.1.

### 2.5 `ios/Runner/GoogleService-Info.plist` (Firebase, iOS)

Se descarga de la consola de Firebase y se agrega al target `Runner` en Xcode (`informe.md` §2.3, paso 3).

| Clave | Qué es |
|---|---|
| `GOOGLE_APP_ID` | ID de la app iOS en Firebase. |
| `GCM_SENDER_ID` | Sender ID de FCM (número del proyecto). |
| `PROJECT_ID` | ID del proyecto. |
| `BUNDLE_ID` | Tiene que ser `com.estiloneutral.es`. |
| `API_KEY` | Clave de API de cliente. |

Sin este archivo, ni `lib/firebase_options.dart` configurado con `flutterfire configure`, iOS funciona sin notificaciones.

### 2.6 `client_secret_*.json` (raíz del repo)

Hay tres descargas de clientes OAuth del proyecto de Google Cloud **`gmp-demo-project-093718520`**: `…_dev.json`, `…_pro.json` y uno sin sufijo. Son de tipo `installed`.

| Campo (`installed.*`) | Qué es |
|---|---|
| `client_id` | ID del cliente OAuth (`312343708119-….apps.googleusercontent.com`). |
| `project_id` | Proyecto de Google Cloud. |
| `auth_uri` / `token_uri` / `auth_provider_x509_cert_url` | Endpoints estándar de Google OAuth. |

**Ni la app ni las herramientas leen estos archivos.** En Android, Google Sign-In valida por paquete y SHA-1, sin un client ID en el código. Se conservan solo como referencia de qué cliente corresponde a cada variante. Quedan ignorados por la regla `client_secret*.json`.

### 2.7 `tools/sheets_sync/client_secret.json` y `token.json`

Credenciales de los scripts Python que bajan y suben la hoja y aplican migraciones de esquema (`download_sheet.py`, `upload_sheet.py`, `migrate_*.py`). Ver `docs/google/automatizacion.md`.

`client_secret.json` (cliente OAuth de escritorio, `installed.*`):

| Campo | Qué es |
|---|---|
| `client_id` / `client_secret` | Credenciales del cliente OAuth de escritorio. **Secreto.** |
| `project_id`, `auth_uri`, `token_uri`, `auth_provider_x509_cert_url` | Proyecto y endpoints. |
| `redirect_uris` | URIs de retorno del flujo local. |

`token.json` (se crea en la primera ejecución, después de autorizar en el navegador):

| Campo | Qué es |
|---|---|
| `token` | Token de acceso (vence en ~1 h). |
| `refresh_token` | Permite renovar el acceso sin volver a autorizar. **Secreto.** |
| `token_uri`, `client_id`, `client_secret` | Para renovar. |
| `scopes` | Permisos concedidos (Drive / Sheets). |
| `expiry` | Vencimiento del token de acceso. |
| `account`, `universe_domain` | Cuenta y dominio de Google. |

Si `token.json` se borra o deja de servir, se vuelve a generar en la próxima ejecución.

### 2.8 `~/.clasprc.json` (fuera del repo)

Sesión de `clasp`, la herramienta que sube `google_apps_script.js` y lo publica. Se crea con `bash tools/apps_script/login.sh`. Contiene tokens OAuth de la cuenta dueña del script (**secreto**). La regla del `.gitignore` sobre `tools/apps_script*/.clasprc.json` existe por si se crea una copia local en esas carpetas.

Archivos relacionados **que sí están en git**:

| Archivo | Campos |
|---|---|
| `.clasp.json` (raíz) | `scriptId`: proyecto de Apps Script de **producción**. `rootDir`: `.`. |
| `.claspignore` | Solo sube `appsscript.json` y `google_apps_script.js`. |
| `tools/apps_script_test/.clasp.json` | `scriptId` y `parentId` del proyecto de **test**. |
| `tools/apps_script/deploy.sh` | `DEPLOYMENT_ID` de producción (la URL `/exec` no cambia al desplegar). |
| `tools/apps_script_test/deploy.sh` | `DEPLOYMENT_ID` de test; copia `google_apps_script.js` antes de subir. |

### 2.9 `.claude/settings.local.json`

Permisos locales de Claude Code para este proyecto.

| Campo | Valor actual |
|---|---|
| `permissions.allow` | `Bash(bash tools/apps_script/deploy.sh)`: permite desplegar el Apps Script a producción sin pedir confirmación cada vez. |

### 2.10 `respaldos/`

Copias de la hoja de producción tomadas antes de corregir datos. **Tienen datos personales de clientes.**

| Contenido | Qué es |
|---|---|
| `AAAA-MM-DD_HHMMSS[_motivo]/estilo_neutral.xlsx` | Planilla completa (todas las hojas, con formato), exportada de Google Sheets. Sirve para restaurar. |
| `…/csv/<hoja>.csv` | Una hoja por archivo, tal como la lee la app (gviz). |
| `limpieza_2026-10-07.json`, `cedulas_demo_2026-10-07.json` | Lotes atómicos aplicados en producción (acción `batch`), para trazabilidad. |

Lotes aplicados, registrados en la bitácora (`audit_log`):

- `tx_limpieza_datos_2026-10-07`
- `tx_cedulas_demo_2026-10-07`

---

## 3. Configuración fuera del repositorio

### 3.1 Apps Script

| Qué | Dónde | Valor / estado |
|---|---|---|
| Implementación de **producción** | `tools/apps_script/deploy.sh` | `AKfycby6Jg1o…` (la usan los tres `.env*`) |
| Implementación de **test** | `tools/apps_script_test/deploy.sh` | `AKfycbx6GOO7…` (pide login de Google para llamarla) |
| Acceso de la Web App | `appsscript.json` → `webapp` | `access: ANYONE_ANONYMOUS`, `executeAs: USER_DEPLOYING`: se ejecuta como la cuenta que despliega, sin login del que llama (ver DT-1) |
| Permisos (scopes) | `appsscript.json` → `oauthScopes` | `spreadsheets`, `drive`, `script.external_request`, `script.scriptapp`, `userinfo.email`. Si se agrega uno, hay que volver a autorizar el script desde el editor. |
| Hoja de cálculo | `google_apps_script.js` → `DEFAULT_SPREADSHEET_ID` | La hoja de producción. |
| Carpeta de fotos | `google_apps_script.js` → `DRIVE_FOLDER_ID` | Carpeta de Drive compartida "cualquiera con el enlace". |
| **Propiedad del script `FCM_SERVICE_ACCOUNT`** | Editor → Configuración del proyecto → Propiedades del script | JSON completo de la cuenta de servicio de FCM: `type`, `project_id`, `private_key_id`, `private_key`, `client_email`, `client_id`, `token_uri`… El script usa `client_email`, `private_key` y `project_id`. **Cargado en producción.** |
| Disparador diario de tasas | `crearTriggerDiarioTasas()` | Corre `obtenerTasaBCV` todos los días. |
| Disparador de notificaciones desde la hoja | `crearTriggerNotificacionesDesdeHoja()` | Opcional: envía las filas de `notificaciones` marcadas `PENDIENTE`. Pendiente de instalar. |
| Funciones para correr a mano | Editor → Ejecutar | `prepararHojasNotificaciones` (✔ ejecutada en prod), `enviarNotificacionesPendientes`, `migrarEsquema`, `repararCodigosTelefono`, `configurarValidacionesDatos`, `auditarIntegridadReferencial`. |

### 3.2 Google Cloud / Firebase

| Qué | Valor / estado |
|---|---|
Hay **dos proyectos** de Google Cloud, con funciones separadas:

| Proyecto | Para qué | Plan / costo |
|---|---|---|
| `gmp-demo-project-093718520` ("Maps Platform Demo Project") | Google Sign-In (clientes OAuth) y los scripts de `tools/sheets_sync`. | No se le agregó Firebase. |
| `estilo-neutral` (Firebase) | Notificaciones FCM. | **Spark, sin facturación, costo cero.** |

| Qué | Proyecto | Valor / estado |
|---|---|---|
| Clientes OAuth | `gmp-demo-project-093718520` | Android por variante (paquete + SHA-1), ver `docs/google/sign-in.md`. |
| Pantalla de consentimiento | `gmp-demo-project-093718520` | Si está en modo *Testing*, cada cuenta que inicia sesión tiene que estar en *Test users*. |
| Firebase | `estilo-neutral` | Creado el 2026-10-07 (sender ID `932812955586`). Gemini y Analytics desactivados. Apps Android registradas: `com.estiloneutral.es`, `.dev` y `.qa`. |
| Firebase Cloud Messaging API (v1) | `estilo-neutral` | Verificar que esté habilitada. |
| Cuenta de servicio de FCM | `estilo-neutral` | Creada: `fcm-sender@estilo-neutral.iam.gserviceaccount.com` con rol `Firebase Cloud Messaging API Admin`. Clave cargada en `FCM_SERVICE_ACCOUNT` del script de producción. |
| Apple (APNs) | `estilo-neutral` | **Omitido**: requiere Apple Developer Program (USD 99 por año). iOS funciona sin notificaciones. |

> **Costo cero:** no vincular una cuenta de facturación ni aceptar "Actualizar a Blaze" en `estilo-neutral`. FCM no lo necesita.

### 3.3 Hojas de Google Sheets que crea o espera el sistema

Las columnas de cada hoja están en `docs/estandar-hojas.md` y en el modelo correspondiente de `lib/models/`. Las hojas de notificaciones (`dispositivos`, `notificaciones`) están en `informe.md` §2.2.

---

## 4. Ignorados que se generan solos

No hace falta crearlos. Si faltan o se rompen, se regeneran.

| Ruta | Lo genera | Cómo regenerar |
|---|---|---|
| `build/`, `.dart_tool/` | Flutter | `flutter clean && flutter pub get` |
| `android/.gradle/`, `android/gradlew`, `android/gradlew.bat`, `android/gradle/wrapper/gradle-wrapper.jar` | Flutter / Gradle | `flutter build apk` (Flutter los recrea) |
| `android/app/src/main/java/` (`GeneratedPluginRegistrant.java`) | Flutter | `flutter pub get` |
| `ios/Pods/`, `ios/Flutter/Flutter.podspec`, `ios/Flutter/flutter_export_environment.sh`, `ios/Runner/GeneratedPluginRegistrant.*` | Flutter / CocoaPods | `flutter pub get && cd ios && pod install` |
| `tools/apps_script*/node_modules/` | npm | `cd tools/apps_script && npm install` (y lo mismo en `apps_script_test`) |
| `doc/api/` | `dart doc` | `dart doc` |
| `site/` | MkDocs | `mkdocs build` |
| `*.iml`, `.idea/`, `.widget_preview/` | IDE | El IDE los recrea |

---

## 5. Checklist para una máquina nueva

1. Clonar el repo e instalar Flutter, Android Studio / SDK y, en macOS, Xcode y CocoaPods.
2. `flutter pub get` (genera `local.properties` y los archivos de §4).
3. Crear `.env`, `.env.dev` y `.env.test` a partir de `.env.example` (§2.1).
4. Para releases de Android: copiar `upload-keystore.jks` y crear `android/key.properties` (§2.2), y registrar el SHA-1 en Google Cloud si es otro keystore.
5. Para notificaciones: `android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist` (§2.4 y §2.5).
6. Para desplegar el Apps Script: `cd tools/apps_script && npm install`, lo mismo en `apps_script_test`, y `bash tools/apps_script/login.sh` (§2.8).
7. Para los scripts Python: `tools/sheets_sync/client_secret.json` y `pip install -r tools/sheets_sync/requirements.txt` (§2.7).
8. Verificar: `flutter analyze`, `flutter test`, `node tools/apps_script/tests/notificaciones.test.js` y `node tools/apps_script/tests/acceso.test.js`.

---

## 6. Observaciones encontradas al documentar

| # | Qué | Impacto | Sugerencia |
|---|---|---|---|
| 1 | El valor por defecto de `APPS_SCRIPT_URL` en `lib/shared/google_sheets/sheets_config.dart` apunta a una implementación **distinta** (`AKfycbyDwgo8…`) de la que actualiza `deploy.sh` (`AKfycby6Jg1o…`). | Una build hecha **sin** `--dart-define-from-file` escribiría en un script viejo, sin las reglas actuales (acceso revocado, increment, notificaciones). | Cambiar el valor por defecto a la implementación de producción, o hacer que la app no escriba si falta la variable. |
| 2 | `ALLOWED_EMAILS` sigue en los tres `.env*`. | Ninguno (se ignora). Puede confundir. | Borrarlo de los `.env*` y de `.env.example`. |
| 3 | `APP_NAME`, `API_BASE_URL` y `APP_PACKAGE_NAME` no los lee la app. | Ninguno. | Dejarlos como informativos o borrarlos. |
| 4 | `dev` y `qa` usan la hoja y el script de producción. | Las pruebas escriben datos reales. | Una copia de la hoja para test y `.env.dev` / `.env.test` apuntando a ella y a la implementación de test. |
| 5 | `ios/Runner/Info.plist` no tiene `GIDClientID` ni el URL scheme de Google. | Google Sign-In en iOS no está configurado (en Android no hace falta). | Si se va a publicar en iOS, crear un cliente OAuth de iOS en Google Cloud y agregar `GIDClientID` y su URL scheme invertido a `Info.plist`. Hoy no está documentado en `docs/google/sign-in.md`. |
