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

1. Confirmá que el Apps Script desplegado tenga la acción `toggle_seguridad` (ver [Apps Script](apps-script.md)) — si el script vigente es una versión vieja (sin este handler), la llamada cae en el `default` y no hace nada.
2. Confirmá que `APPS_SCRIPT_URL` en tu `.env` apunte a la implementación correcta (comparar el Deployment ID).

## El `.xlsx` local "desaparece" o cambia de tamaño drásticamente

Si abrís el `.xlsx` con una app de oficina de terceros (ej. WPS Office) para revisarlo, puede quedar bloqueado momentáneamente o guardarse con mucho más peso del original (formato/metadata extra) al re-guardarlo. El contenido en sí no se corrompe, pero:

- Verificá siempre el contenido (`organizacion_id`, hoja `usuarios`, etc.) antes de subirlo con `upload_sheet.py`.
- Preferí editar el `.xlsx` directamente en Google Sheets, o con `openpyxl` desde un script, en vez de una app de oficina de terceros.
