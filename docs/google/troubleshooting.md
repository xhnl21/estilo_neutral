# Troubleshooting

Errores reales que ya nos encontramos configurando todo esto, y cómo se resolvieron.

## `ApiException: 10` (`DEVELOPER_ERROR`) al tocar "Continuar con Google"

```
PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)
```

**Causa:** no existe una credencial **OAuth Client ID → Android** registrada para la combinación exacta `applicationId` + SHA-1 del certificado con el que se firmó el APK que estás corriendo.

**Diagnóstico:** los logs de la app suelen estar silenciados en release (`Logger` depende de `kDebugMode`/`ENABLE_LOGS`). Para ver el error real:
```bash
flutter run --flavor <dev|qa|prod>
```
y mirar la consola — el error completo aparece con tag `flutter`.

**Fix:** ver [Google Sign-In → Credenciales Android](sign-in.md#2-credenciales-android-una-por-combinacion-package-certificado). Hay que registrar una credencial por cada combinación flavor × build type que efectivamente uses.

## Login falla con `access_denied` (SHA-1 correcto)

**Causa:** la pantalla de consentimiento OAuth está en modo **Testing** y la cuenta que intenta loguearse no está en la lista de "Test users".

**Fix:** Google Auth Platform → Audience → Test users → Add users.

## `User has not enabled the Apps Script API`

Al correr `clasp push`/`clasp pull`/`clasp login`.

**Fix:** [script.google.com/home/usersettings](https://script.google.com/home/usersettings) → activar el switch. Puede tardar 1-2 minutos en propagar.

## `Security Error: srcDir "../.." escapes project root` (clasp)

**Causa:** `clasp` v3 no permite que `rootDir` en `.clasp.json` apunte fuera del directorio desde el que se ejecuta el comando.

**Fix:** correr `clasp` con el directorio de trabajo en la raíz del repo (donde vive `.clasp.json` con `rootDir: "."`), no desde una subcarpeta. Ver [Automatización](automatizacion.md#por-que-claspjson-vive-en-la-raiz-del-repo-no-en-toolsapps_script).

## `Google Drive API has not been used in project ... or it is disabled`

Al correr `tools/sheets_sync/upload_sheet.py`.

**Fix:** habilitar la API en el link que trae el mismo error, o directo en [console.cloud.google.com/apis/library/drive.googleapis.com](https://console.cloud.google.com/apis/library/drive.googleapis.com), en el proyecto correcto.

## No aparece el botón para descargar el JSON de una credencial OAuth

Los client secrets de tipo Web/Desktop solo se pueden ver/descargar **en el momento de creación** del cliente. Si cerraste el diálogo sin descargar:

- Entrá al detalle del cliente (click en su nombre en la lista de Credenciales) → sección "Secretos del cliente" → hay un ícono de descarga (⬇) junto al secreto enmascarado, que sí permite bajar el JSON después.
- Si eso no aparece: borrar el cliente y crear uno nuevo.

## Confusión de proyecto de Google Cloud

Si tu cuenta tiene varios proyectos, es fácil terminar creando una credencial en el proyecto equivocado (por ejemplo, el proyecto demo que Google crea automáticamente, "Maps Platform Demo Project"). **Para este proyecto, "Maps Platform Demo Project" (`gmp-demo-project-093718520`) es en realidad el correcto** — ahí viven las 4 credenciales de Sign-In y la de Sheets Sync. Confirmalo mirando la sección "IDs de clientes de OAuth 2.0" en Credenciales: si ves `Estilo Neutral - Dev Debug`, `Estilo Neutral - Prod Release`, etc., estás en el proyecto correcto.

## El toggle de "Seguridad" no persiste en el Sheet

Si los switches cambian en la app pero no se ven reflejados en la hoja `seguridad`:

1. Confirmá que el Apps Script desplegado tenga la acción `set_metodo_seguridad` (ver [Apps Script](apps-script.md)) — si el script vigente es una versión vieja (sin este handler), la llamada cae en el `default` y no hace nada.
2. Confirmá que `APPS_SCRIPT_URL` en tu `.env` apunte a la implementación correcta (comparar el Deployment ID).

## GViz devuelve un CSV corrupto para una hoja con columnas booleanas (encabezado "fusionado" con datos)

Síntoma real: `SheetsDataService` tira `Exception: La hoja "seguridad" no tiene el encabezado esperado ...` aunque la hoja SÍ tiene el encabezado correcto si la mirás en Google Sheets. Al inspeccionar la respuesta cruda de `.../gviz/tq?tqx=out:csv&sheet=seguridad`, la fila 1 aparece como algo como:

```
"biometrico FALSE","desbloqueo_facial FALSE","dos_factores FALSE","usuario_email neidapulgar1989@gmail.com"
"TRUE","FALSE","FALSE","xhnl21@gmail.com"
```

— el encabezado real ("biometrico", "desbloqueo_facial", ...) aparece pegado con el valor de la primera fila de datos, y falta una fila.

**Causa real (no es un bug de la app, es una hoja con tipos de celda mezclados):** el endpoint GViz interpreta cada hoja como una tabla tipada (`DataTable`) para poder graficarla, e infiere el tipo de cada columna a partir de sus celdas. Si una columna booleana (`biometrico`, `desbloqueo_facial`, `dos_factores`) tiene **algunas filas como boolean nativo de Sheets y otras como texto literal `"TRUE"`/`"FALSE"`**, la heurística de detección de encabezado de GViz se rompe y serializa el CSV de forma incorrecta — sin ningún error visible del lado de Google.

Esto pasa fácil porque `Range.setValues()` de Apps Script **siempre** convierte las cadenas `"TRUE"`/`"FALSE"` a boolean nativo (no hay forma de forzar texto plano desde Apps Script), mientras que escribir esas mismas cadenas vía la API de Sheets con `valueInputOption=RAW` (como hacían los scripts de migración en `tools/sheets_sync/`) las deja como texto. Si una fila se creó por un camino y otra fila por el otro, quedan tipos mezclados en la misma columna.

**Diagnóstico:** comparar el tipo real de las celdas con la API de Sheets (`spreadsheets.get` con `includeGridData=true` y `fields=sheets.data.rowData.values.effectiveValue`) — vas a ver `{"boolValue": true}` en unas filas y `{"stringValue": "FALSE"}` en otras de la misma columna.

**Arreglo:**
1. Igualar el tipo de **todas** las filas de esa columna (todas boolean nativo, o todas texto — no mezclado). Se puede reescribir la columna entera vía `spreadsheets.values.update` con `valueInputOption=USER_ENTERED` pasando booleans nativos de Python/JS (no las cadenas `"TRUE"`/`"FALSE"`).
2. Si el problema reaparece, revisar que todo lo que escribe en esa hoja (Apps Script y cualquier script de migración) escriba el mismo tipo — ver el comentario en `_handleSetMetodoSeguridad` de `google_apps_script.js`.
3. `SheetsDataService._fetchSheet` valida el encabezado esperado antes de parsear cualquier hoja con esquema nuevo (`usuarios`, `seguridad`, `organizaciones`, `usuario_organizacion`, `ventas`, `venta_items`) — por eso este bug se manifiesta como una excepción clara en los logs en vez de datos silenciosamente corruptos.

## `Exception: Access denied: DriveApp.` al subir una foto de producto

**Causa:** el código llamaba a `file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW)` después de crear el archivo — Google bloquea esa operación puntual (hacer un archivo público vía API) para apps no verificadas, como medida antiabuso. El resto del acceso a Drive (crear el archivo, leerlo) funcionaba bien; solo esa línea específica fallaba.

**Diagnóstico:** los "Registros de Cloud" del editor no se pueblan para ejecuciones de tipo Aplicación web en este proyecto. Hubo que devolver `Session.getEffectiveUser().getEmail()` y `err.stack` directo en la respuesta JSON de error para ver que la cuenta era la correcta y que el fallo apuntaba exactamente a la línea de `setSharing`, no a `getFolderById`/`createFile`.

**Fix:** sacar el `setSharing()` — es innecesario porque `DRIVE_FOLDER_ID` ya tiene el permiso "cualquiera con el enlace" configurado a nivel de carpeta, y los archivos nuevos lo heredan.

Caso completo (diseño de la feature, diagnóstico paso a paso y el runbook de reautorización de scopes que se usó en el camino): ver [Galería de fotos](galeria-fotos.md).

## `pumpAndSettle timed out` / el test se cuelga hasta el timeout de 10 minutos

**Causa:** un `testWidgets()` disparó, directa o indirectamente, una llamada real de `dio` (a través de `SheetsDataService`) — por ejemplo `ServiceLocator().init()`, `addCliente()`, `addVenta()`. Ese `Future` no se resuelve nunca dentro del zone "fake async" de Flutter Test a menos que corra dentro de `tester.runAsync()`.

**Fix:** envolver la llamada en `runAsync`. Detalle completo, por qué pasa y por qué `package:http` no lo sufría de la misma forma: ver [Cliente HTTP § Testing con dio](red-http.md#testing-con-dio).

## APK de release demasiado grande

Ver [Optimización de Build (APK)](../build-optimizacion-apk.md) — diagnóstico completo (assets sin comprimir, R8 desactivado, APK FAT multi-arquitectura) y los pasos ya aplicados con los números medidos.

## El `.xlsx` local "desaparece" o cambia de tamaño drásticamente

Si abrís el `.xlsx` con una app de oficina de terceros (ej. WPS Office) para revisarlo, puede quedar bloqueado momentáneamente o guardarse con mucho más peso del original (formato/metadata extra) al re-guardarlo. El contenido en sí no se corrompe, pero:

- Verificá siempre el contenido (`organizacion_id`, hoja `usuarios`, etc.) antes de subirlo con `upload_sheet.py`.
- Preferí editar el `.xlsx` directamente en Google Sheets, o con `openpyxl` desde un script, en vez de una app de oficina de terceros.
