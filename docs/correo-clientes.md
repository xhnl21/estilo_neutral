# Correo a clientes

Una organización envía por correo, a sus clientes, una **notificación guardada** (el título es el asunto y el mensaje es el cuerpo). Reutiliza el módulo de Notificaciones.

## Cómo se usa

1. **Administración → Organizaciones → Editar:** cargar el **Correo** de la organización (por ejemplo `ventas@tienda.com`). Sin correo, la organización no puede enviar.
2. **Comunicación → Notificaciones → Ver** (en la notificación que se quiere enviar) → **Enviar por: Correo a clientes**.
3. **Para:** **Todos** los clientes con correo, o **Elegir** (con buscador por nombre o correo).
4. **Enviar correo a N clientes.**

Reciben solo los clientes **activos** de la organización actual con un correo válido en la hoja `clientes` (columna `email`). La pantalla avisa cuántos no tienen correo cargado.

## Quién figura como remitente

Google solo permite enviar desde la cuenta dueña del Apps Script (la que lo despliega) o desde un alias verificado de esa cuenta. Por eso cada correo sale así:

| Campo | Valor |
|---|---|
| Nombre del remitente | El de la organización (por ejemplo "Estilo Neutral Centro"). |
| Dirección técnica | La cuenta dueña del Apps Script. |
| Responder a | El correo de la organización: las respuestas de los clientes le llegan a ella. |
| Pie del correo | Nombre de la organización y "Para responder, escribí a …". |

Se envía **un correo por cliente**: nadie ve las direcciones de los demás.

> **Para que la dirección técnica sea la de la organización** (segunda etapa, no implementada): agregar ese correo como alias en Gmail de la cuenta dueña (Configuración → Cuentas → "Enviar correo como", con verificación por código) y cambiar el envío a `GmailApp` con `from`, que pide un permiso de Gmail más amplio.

## Cupo diario de Google

`MailApp` permite unos **100 destinatarios por día** con una cuenta gmail y unos **1.500** con Google Workspace (cuenta de la cuenta dueña del script, compartido entre todas las organizaciones). La pantalla muestra cuántos quedan hoy y no deja enviar si los elegidos superan ese número; el servidor lo vuelve a comprobar antes de enviar.

## Hojas

- **`organizaciones`:** nueva columna **C `email`** (el script agrega el encabezado si falta). Vacío = la organización no envía correos.
- **`correos`** (la crea el script con el primer envío), una fila por envío:

| Columna | Contenido |
|---|---|
| `id` | `co00000001`… (lo genera el servidor). |
| `fecha`, `remitente_email`, `organizacion_id` | Cuándo, quién y desde qué organización. |
| `asunto`, `cuerpo` | Lo enviado. |
| `destinatarios` | IDs de los clientes. |
| `enviados`, `fallidos` | Resultado. |
| `estado` | `ENVIADO` o `ERROR`. |
| `detalle` | Errores (hasta 3). |

Cada envío también queda en `audit_log` (`envio_correo_clientes`).

## Permiso del Apps Script (una sola vez)

Enviar correo usa el permiso `script.send_mail`. Después de agregarlo, la cuenta dueña tiene que autorizarlo **antes** de publicar la versión (si no, Google rechaza todas las llamadas a la Web App):

1. Abrir el editor del proyecto (producción: <https://script.google.com/home/projects/1Rk-Cz_t6_dNx7SAp9ZMFJTA-b6wKrgEp-58_XTeL1XE7Xy4BWRyD4Je6/edit>; test: <https://script.google.com/home/projects/1tV_9i0gJfTUonOMmnLsguRdFSf-iohCixFdN1wKmECEF4Ug8Uwht3ACX/edit>).
2. Elegir la función **`autorizarCorreo`** y tocar **Ejecutar**.
3. Aceptar los permisos ("Enviar correo electrónico en tu nombre"). Si aparece "Google no verificó esta app": **Configuración avanzada → Ir a … (no seguro)**: es tu propio script.
4. El registro de ejecución muestra el cupo de hoy. Recién entonces: `bash tools/deploy.sh --script`.

## Archivos

| Parte | Archivos |
|---|---|
| Script | `_enviarCorreoClientes`, `autorizarCorreo`, `_validarEmailOrganizacion` (acciones `enviar_correo`, `uso_correo`) en `google_apps_script.js`; permiso en `appsscript.json` |
| Organización | `Organizacion.email` (`lib/models/organizacion.dart`), formulario en `organizaciones_page.dart` |
| App | `EnviarCorreoCubit`, `seccion_correo_clientes.dart`, canal en `enviar_notificacion_page.dart`; `SheetsDataService.enviarCorreoClientes`, `cupoCorreo`, `clientesConEmail` |
| Tests | `test/features/notificaciones/correo_clientes_test.dart`, `tools/apps_script/tests/correo.test.js` |
