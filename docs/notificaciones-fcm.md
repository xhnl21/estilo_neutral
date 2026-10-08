# Notificaciones push (Firebase Cloud Messaging)

Guía completa de las notificaciones de Estilo Neutral: qué hacen, cómo se configuraron paso a paso (con los enlaces de cada consola), cómo se envían, cómo se despliegan y cómo diagnosticar problemas.

**Puesta en marcha:** 2026-10-07 · **Plataforma:** Android, con costo cero · **iOS:** no configurado (ver §4.9)

---

## 1. Qué hace

Cualquier usuario que esté en la hoja `usuarios`, con membresía en una organización que exista, puede enviar una notificación al teléfono de otros usuarios de la app:

| Destino | Alcance | Ejemplo |
|---|---|---|
| Todos | `global` | Aviso general a todas las organizaciones. |
| Una organización | `organizaciones` | Solo a la sucursal Centro. |
| Varias organizaciones | `organizaciones` | A Centro y a Este. |
| Un usuario | `usuarios` | A `ana@…`. |
| Varios usuarios de una o varias organizaciones | `usuarios` | A `ana@…` (Centro) y `bea@…` (Este). |

- **Desde la app:** menú lateral → **Comunicación → Notificaciones**.
- **Desde la hoja de Google Sheets:** una fila en `notificaciones` con estado `PENDIENTE` (§5.2).

Reglas que aplica el servidor (Apps Script):

- Solo reciben los usuarios que **siguen teniendo acceso**, según la organización a la que pertenecen **hoy**.
- Una notificación que se toca abre la pantalla indicada en `ruta` (por ejemplo `/ventas`), si la trae.
- Cada envío queda en la hoja `notificaciones` y en la bitácora (`audit_log`).
- Cada organización tiene sus **límites de envío** (por hora, día, semana o mes; por usuario y para toda la organización), configurables en **Comunicación → Configuración de notificaciones** (§1.3). Sin configurar: **30 por hora por usuario**.

> Los destinatarios son **usuarios de la app**. Los clientes de la hoja `clientes` no tienen la app instalada y no pueden recibir notificaciones FCM.

### 1.1 Cómo funciona

```
 App (teléfono)                     Apps Script (/exec)                      Firebase (FCM)
 ──────────────                     ───────────────────                      ──────────────
 1. Inicia sesión ── registrar_dispositivo ──▶ hoja "dispositivos"
    (token FCM)

 2. "Enviar" ─────── enviar_notificacion ───▶ valida remitente y destino
                                              resuelve tokens (acceso de HOY)
                                              firma JWT (cuenta de servicio) ──▶ messages:send (v1)
                                              registra en "notificaciones"   ◀── resultado por token
                                              borra tokens vencidos
 3. Teléfono destino ◀───────────────────────────────────────────────── mensaje SOLO DE DATOS
    · la app arma SIEMPRE la notificación (abierta, en segundo plano o
      cerrada): monograma, color y logo incluidos en el APK, sin descargar

 4. Cierra sesión ── eliminar_dispositivo ──▶ borra su token
```

### 1.2 Cierre de sesión silencioso (usuario inactivado o eliminado)

Usuarios y clientes tienen un campo `status` (`activo` / `inactivo`): columna **F** de `usuarios` y **J** de `clientes`. Vacío cuenta como activo. Inactivar no borra el registro.

- **Cliente inactivo:** conserva ventas, deudas y abonos, pero no aparece al registrar una venta nueva.
- **Usuario inactivo:** no puede iniciar sesión, el servidor rechaza sus escrituras (`acceso_revocado`) y no recibe notificaciones.

Al inactivar o eliminar un usuario, el script (`_expulsarUsuario`) le envía a cada teléfono suyo un mensaje FCM **silencioso** (solo datos, `tipo: sesion_revocada`, sin título ni cuerpo) y borra sus filas de `dispositivos`:

| Estado de la app | Qué pasa |
|---|---|
| Abierta | `PushCubit` no muestra nada, relee las hojas de acceso y `ControlAccesoSesion` cierra la sesión con el motivo ("La cuenta … está inactiva."). |
| En segundo plano o cerrada | `manejadorSegundoPlano` no muestra nada y anota el aviso; al volver a la app se relee el acceso (sin esperar los 30 s habituales) y se cierra la sesión. Si estaba cerrada, el login la rechaza. |

La app no confía a ciegas en el aviso: siempre relee el acceso, así un aviso viejo (por ejemplo, de antes de reactivar la cuenta) no cierra una sesión válida. Si FCM falla, la sesión igual se cierra en la próxima escritura o al volver a la app.

Para inactivar desde la hoja (sin la app): escribir `inactivo` en la columna `status` de `usuarios`. El disparador de edición (`alEditarNotificaciones`, el mismo de §5.2, instalado con `crearTriggerNotificacionesDesdeHoja()`) envía el push silencioso igual que desde la app. Sin el disparador, la sesión se cierra en la siguiente lectura o escritura.

### 1.3 Límites de envío por organización

Se configuran en la app, en **Comunicación → Configuración de notificaciones**, o directamente en la hoja `config_notificaciones` (§6). Cada organización tiene su propia configuración:

| Campo | Qué es |
|---|---|
| Período | `hora`, `dia`, `semana` o `mes`. Es de calendario, en hora de Venezuela: el día empieza a las 00:00, la semana el lunes y el mes el día 1. |
| Por usuario | Cuántas puede enviar cada usuario de la organización en el período. `0` = sin límite. |
| Para toda la organización | Cuántas pueden enviar entre todos sus usuarios en el período. `0` = sin límite. |

- Una organización **sin fila** usa lo de siempre: 30 por hora por usuario, sin límite para la organización.
- Cuentan los envíos `ENVIADA` y `SIN_DESTINATARIOS` de la hoja `notificaciones`, desde la app **y** desde la hoja. Un envío a 50 teléfonos cuenta como 1.
- El límite de la organización suma los envíos de los usuarios que pertenecen a ella **hoy**.
- Al pasarse, el servidor rechaza el envío con el motivo y cuándo se renueva. Desde la app no se registra el intento; una fila cargada en la hoja queda en `ERROR` con ese motivo (no `PENDIENTE`).
- La pantalla **Notificaciones** muestra cuántas te quedan en el período (acción `uso_notificaciones`) y deshabilita el envío al llegar a 0. Cuando el cupo se agota aparece el diálogo **"Se acabaron las notificaciones"** con el motivo y cuándo se renueva: al entrar sin cupo, cuando el servidor rechaza un envío por límite (código `limite_notificaciones`) o cuando otro usuario agota el cupo de la organización con la pantalla abierta.
- **Actualización en los demás teléfonos (push silencioso):**

  | Cuándo | Tipo | A quién | Qué hace la app |
  |---|---|---|---|
  | Se crean o cambian los límites de una organización | `config_notificaciones` | Todos los usuarios con acceso | Relee `config_notificaciones` y vuelve a consultar el cupo. |
  | Alguien envía y su organización tiene límite de organización | `uso_notificaciones` | Los usuarios de esa organización | Vuelve a consultar el cupo (y muestra el diálogo si se agotó). |

  No muestran nada en el teléfono. Con la app cerrada o en segundo plano se ignoran: al **entrar** a Notificaciones o a su configuración la app relee los límites y el cupo igual.
- Mientras no haya roles (DT-1), cualquier usuario puede cambiar los límites de cualquier organización. Cada cambio guarda quién lo hizo (`actualizado_por`).

---

## 2. Estado de la configuración

| Componente | Valor |
|---|---|
| Proyecto de Firebase | **`estilo-neutral`** · plan **Spark** (sin facturación) · sender ID `932812955586` |
| Apps Android registradas | `com.estiloneutral.es` (prod), `com.estiloneutral.es.dev`, `com.estiloneutral.es.qa` |
| Configuración Android | `android/app/google-services.json` (una sola, con las tres apps; fuera de git) |
| API | Firebase Cloud Messaging API (v1), habilitada |
| Cuenta de servicio | `fcm-sender@estilo-neutral.iam.gserviceaccount.com`, rol *Administrador de la API de Firebase Cloud Messaging* |
| Credencial en el script | Propiedad `FCM_SERVICE_ACCOUNT` y, como respaldo, `credencial_fcm.js` que genera el deploy |
| Apps Script | Producción @62 (`AKfycby6Jg1o…`), test @21 (`AKfycbx6GOO7…`) |
| Hojas | `dispositivos` y `notificaciones`, creadas en la hoja de producción, con listas desplegables |
| Disparador | `alEditarNotificaciones` (envía las filas marcadas `PENDIENTE`) |
| Marca | Monograma "EN", color `#BC976F` y logo apaisado (`assets/notificaciones/logo_notificacion_2x1.jpg`), incluidos en el APK |
| Formato del envío | Mensajes **solo de datos** en Android (`titulo`, `cuerpo`, `ruta`…); la app arma la notificación |
| Versión de la app | `1.0.0+2023` (las anteriores a `1.0.0+2014` no muestran los mensajes solo de datos; las anteriores a `1.0.0+2017` no conocen el cierre de sesión silencioso; las anteriores a `1.0.0+2022` muestran vacíos los avisos de límites) |
| Probado | En las apps **prod** y **QA** (Android, Redmi Note 8): con la app abierta, en segundo plano y cerrada, y el cierre de sesión silencioso al inactivar un usuario. |

El proyecto de Google Cloud del login (`gmp-demo-project-093718520`, "Maps Platform Demo Project") **no tiene Firebase**. Se mantuvo separado para no activar facturación y para que borrar un proyecto no afecte al otro.

---

## 3. Enlaces de configuración

Todos piden iniciar sesión con la cuenta dueña de los proyectos.

### Firebase

| Qué | Enlace |
|---|---|
| Panel del proyecto | <https://console.firebase.google.com/project/estilo-neutral/overview> |
| Apps registradas y descarga de `google-services.json` | <https://console.firebase.google.com/project/estilo-neutral/settings/general> |
| Cloud Messaging (APNs de iOS, sender ID) | <https://console.firebase.google.com/project/estilo-neutral/settings/cloudmessaging> |
| Uso y plan (verificar que siga en Spark) | <https://console.firebase.google.com/project/estilo-neutral/usage> |

### Google Cloud (proyecto `estilo-neutral`)

| Qué | Enlace |
|---|---|
| Firebase Cloud Messaging API (v1) | <https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=estilo-neutral> |
| Cuentas de servicio (`fcm-sender`, claves) | <https://console.cloud.google.com/iam-admin/serviceaccounts?project=estilo-neutral> |
| Permisos IAM | <https://console.cloud.google.com/iam-admin/iam?project=estilo-neutral> |
| Facturación (tiene que decir "sin cuenta de facturación") | <https://console.cloud.google.com/billing/linkedaccount?project=estilo-neutral> |

### Apps Script, hoja y Drive

| Qué | Enlace |
|---|---|
| Editor del script de **producción** | <https://script.google.com/d/1Rk-Cz_t6_dNx7SAp9ZMFJTA-b6wKrgEp-58_XTeL1XE7Xy4BWRyD4Je6/edit> |
| Disparadores del script de producción | <https://script.google.com/home/projects/1Rk-Cz_t6_dNx7SAp9ZMFJTA-b6wKrgEp-58_XTeL1XE7Xy4BWRyD4Je6/triggers> |
| Editor del script de **test** | <https://script.google.com/d/1tV_9i0gJfTUonOMmnLsguRdFSf-iohCixFdN1wKmECEF4Ug8Uwht3ACX/edit> |
| Hoja de producción (`dispositivos`, `notificaciones`) | <https://docs.google.com/spreadsheets/d/1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI/edit> |
| Carpeta de Drive con el logo (y las fotos de productos) | <https://drive.google.com/drive/folders/1hgdY89REZHD0xWfojjIgnbfhmJ0JluYD> |
| Logo apaisado publicado | <https://lh3.googleusercontent.com/d/1jNICNjXmmthS4f7jSyE5p5g_jAktB30p> |

### Apple (solo si se configura iOS)

| Qué | Enlace |
|---|---|
| Claves (APNs `.p8`) | <https://developer.apple.com/account/resources/authkeys/list> |
| Identificadores (capability Push Notifications) | <https://developer.apple.com/account/resources/identifiers/list> |

### Documentación oficial

| Tema | Enlace |
|---|---|
| FCM en Flutter | <https://firebase.google.com/docs/cloud-messaging/flutter/client> |
| API HTTP v1 de FCM | <https://firebase.google.com/docs/cloud-messaging/send/v1-api> |
| Campos de la notificación Android (color, imagen, canal) | <https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages#androidnotification> |
| FlutterFire Messaging | <https://firebase.flutter.dev/docs/messaging/overview> |
| Planes y precios de Firebase | <https://firebase.google.com/pricing> |
| `flutter_local_notifications` | <https://pub.dev/packages/flutter_local_notifications> |

---

## 4. Paso a paso de la configuración

Así se configuró el 2026-10-07. Sirve para rehacerlo en otro proyecto o revisar cada parte.

**Regla de costo cero:** si alguna pantalla pide tarjeta, "Actualizar a Blaze" o "Vincular facturación", se cancela. Ningún paso lo necesita.

### 4.1 Crear el proyecto de Firebase

1. Entrar a <https://console.firebase.google.com> → **Crear un proyecto de Firebase nuevo**.
2. Nombre: `estilo-neutral`. No se permite `_`; el ID queda igual al nombre si está libre.
3. **Gemini en Firebase:** desactivado. Es un asistente de la consola, no aporta nada acá y puede usar las consultas para entrenar el modelo.
4. **Google Analytics:** desactivado. La app no incluye `firebase_analytics`.
5. **Crear proyecto.** Queda en plan **Spark**.

> **No usar "Agregar Firebase a un proyecto de Google Cloud"** con `gmp-demo-project-093718520`: si ese proyecto tiene facturación, Firebase pasa a Blaze, y borrar el proyecto desde Firebase borraría también los clientes OAuth del login.

### 4.2 Verificar la API de FCM

Abrir <https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=estilo-neutral>. Tiene que decir **API habilitada**; si muestra **Habilitar**, tocarlo. Es la *Firebase Cloud Messaging API* (v1), no la "legacy".

### 4.3 Registrar las apps Android

1. Panel del proyecto → **+ Agregar app** → **Android**.
2. Nombre del paquete, uno por app:
   - `com.estiloneutral.es`
   - `com.estiloneutral.es.dev`
   - `com.estiloneutral.es.qa`
3. Sobrenombre opcional. **SHA-1: vacío**, porque FCM no lo necesita.
4. En "Descargar google-services.json" y "Agregar el SDK", tocar **Siguiente**: el código y Gradle ya están preparados.
5. Después de las tres, descargar **`google-services.json`** desde <https://console.firebase.google.com/project/estilo-neutral/settings/general>. El último que se descarga trae las tres apps.
6. Copiarlo a **`android/app/google-services.json`**. Está en el `.gitignore`.
7. Verificación: `flutter build apk --flavor dev --debug` compila y `build/app/generated/res/processDevDebugGoogleServices/values/values.xml` muestra `project_id = estilo-neutral` y el `google_app_id` de la app `.dev`.

### 4.4 Cuenta de servicio para el envío

1. Abrir <https://console.cloud.google.com/iam-admin/serviceaccounts?project=estilo-neutral>.
2. **No usar** `firebase-adminsdk-…`, porque tiene permisos de administrador sobre todo Firebase. Tocar **+ Crear cuenta de servicio**.
3. Nombre `fcm-sender`, descripción "Envío de notificaciones FCM desde Apps Script" → **Crear y continuar**.
4. Rol: **Administrador de la API de Firebase Cloud Messaging** (`roles/firebasecloudmessaging.admin`). No sirven ni el "Visualizador" ni el "Administrador de Firebase Cloud Messaging", que es para campañas de la consola.
5. Paso 3, "Principales con acceso": vacío → **Listo**.
6. Entrar a `fcm-sender` → **Claves → Agregar clave → Crear clave nueva → JSON**. Se descarga `estilo-neutral-<id>.json`.
7. Guardarlo en la raíz del repo como **`fcm-clave-estilo-neutral-<id>.json`**: está en el `.gitignore` y lo usa el deploy. **Nunca** pegarlo en un chat ni subirlo al repo.

### 4.5 Cargar la credencial en el Apps Script

Hay dos formas, y alcanza con una. El script usa la primera que encuentra:

1. **Propiedad del script, recomendada:** en el editor de producción → **⚙ Configuración del proyecto → Propiedades del script → Agregar propiedad**. Nombre `FCM_SERVICE_ACCOUNT`, valor: el JSON completo. Repetir en el script de test.
2. **Embebida por el deploy:** `tools/apps_script/generar_credencial_fcm.sh` toma `fcm-clave-*.json` (o la ruta en `FCM_CLAVE`) y genera `credencial_fcm.js`, que los `deploy.sh` suben junto al script. El archivo generado no se versiona.

No hace falta volver a autorizar el script: el envío usa permisos que ya tenía (`script.external_request`).

### 4.6 Preparar la hoja

Crea `dispositivos` y `notificaciones` con su encabezado, las listas desplegables de `alcance` y `estado`, una nota de ayuda en `notificaciones!A1`, y el disparador de envío desde la hoja. Es idempotente. Hay dos formas:

- **Desde el editor:** ejecutar `prepararHojasNotificaciones` y después `crearTriggerNotificacionesDesdeHoja`.
- **Desde la terminal:**
  ```bash
  curl -sL -H 'Content-Type: application/json' \
    -d '{"action":"preparar_notificaciones","usuario_sesion":"<email con acceso>"}' \
    "https://script.google.com/macros/s/AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA/exec"
  ```

### 4.7 Marca de las notificaciones

| Elemento | Dónde está | Cómo se ve |
|---|---|---|
| Ícono chico | `android/app/src/main/res/drawable-*/ic_notificacion_en.png` (monograma "EN", 24 a 96 px) | Android lo pinta de **un solo color**: es la silueta del monograma, trazada sobre el logo. La campana `drawable/ic_notificacion.xml` queda como alternativa. |
| Color | `colorNotificacion` en `push_firebase.dart` (`#BC976F`); también `color_notificacion` en `res/values/colors.xml` | Ícono y nombre de la app en dorado. |
| Logo | `res/drawable-nodpi/ic_logo_notificacion.png` (miniatura) y `logo_notificacion_2x1.jpg` (al expandir) | Miniatura cuadrada a la derecha; al expandir, el logo apaisado. |

**Por qué la notificación la arma la app, siempre.** Al principio el script enviaba `notification` + `image`: con la app cerrada, la armaba Android y **descargaba** el logo de Drive. En Xiaomi/MIUI, con la app dormida, la descarga no llegaba en los pocos segundos que espera Firebase y la notificación salía sin logo. Desde la versión `1.0.0+2014` el script envía mensajes **solo de datos** y la app arma la notificación con las imágenes que trae el APK (`manejadorSegundoPlano` y `mostrarNotificacionLocal` en `push_firebase.dart`).

Con la app **cerrada**, Android primero tiene que arrancar la app en segundo plano: en el build debug de QA tardó unos 23 s; en release es más rápido. La imagen sale siempre.

`assets/notificaciones/logo_notificacion_2x1.jpg` (1024×512) y la miniatura `ic_logo_notificacion.png` se generan desde `assets/icons.png` **sin modificar el original**, con `python3 tools/iconos/generar_logo_notificacion.py`:
- **Apaisada:** el logo completo sobre la tela del fondo, porque Android muestra la imagen en proporción 2:1 y el logo cuadrado salía recortado.
- **Recorte redondeado:** el logo se recorta con la forma de su marco (esquinas de ~110 px sobre 1024). Por fuera del marco, el original tiene un fondo gris beige liso que se veía como un recuadro detrás del marco.
- **Miniatura:** queda con las esquinas transparentes.

**Cambiar el logo:** reemplazar `assets/icons.png`, correr `python3 tools/iconos/generar_logo_notificacion.py` (y `generar_monograma.py`, si cambia el monograma) y compilar la app. Si el nuevo logo tiene otro radio de esquinas, ajustar `RADIO` en el script. El script ya no envía imágenes; el logo publicado en Drive (`logo_notificacion_2x1_estilo_neutral.jpg`) quedó sin uso.

**Ícono chico (monograma "EN"):** el logo es un render 3D y no se puede recortar su silueta automáticamente, así que se **trazó a mano** sobre `assets/icons.png` (sin modificarlo), con trazos gruesos para que se lea a 24 px. Lo genera `python3 tools/iconos/generar_monograma.py`:
- `assets/notificaciones/monograma_en.png`: la fuente, de 1024 px;
- los `drawable-{mdpi…xxxhdpi}/ic_notificacion_en.png`.

Para ajustarlo, se editan las coordenadas o el `GROSOR` del script y se vuelve a ejecutar. Si algún día hay un SVG oficial del monograma, conviene reemplazar estos PNG por un vector generado desde él.

### 4.8 Desplegar

```bash
bash tools/deploy.sh --script                            # solo el Apps Script (test → producción)
bash tools/deploy.sh --app prod --instalar --version 1.0.0+2013
bash tools/deploy.sh --todo --version 1.0.0+2013         # tests + script + prod + instalar
bash tools/deploy.sh --todo --simular                    # ver los pasos sin ejecutar
```

Detalle en `compile.md` §6.1. Para versiones y firmas, ver §7.

### 4.9 iOS (no configurado)

Requiere el **Apple Developer Program, que cuesta USD 99 por año**, así que se omitió. El código ya lo soporta: sin `GoogleService-Info.plist`, iOS funciona sin notificaciones. Para activarlo:

1. En <https://developer.apple.com/account/resources/authkeys/list>, crear una clave **APNs** y descargar el `.p8` (anotar el Key ID y el Team ID).
2. En <https://developer.apple.com/account/resources/identifiers/list> → `com.estiloneutral.es`, activar **Push Notifications**.
3. Firebase → **Agregar app → iOS** con bundle `com.estiloneutral.es` → descargar `GoogleService-Info.plist` y agregarlo al target `Runner` en Xcode.
4. En <https://console.firebase.google.com/project/estilo-neutral/settings/cloudmessaging> → configuración de apps de Apple → subir el `.p8` con el Key ID y el Team ID.
5. En Xcode → **Signing & Capabilities**: elegir el equipo, agregar **Push Notifications** y confirmar **Background Modes → Remote notifications** (ya está en `Info.plist`).
6. `cd ios && pod install` y probar en un iPhone real.

---

## 5. Cómo enviar

### 5.1 Desde la app

Menú lateral → **Comunicación → Notificaciones**. Las notificaciones se **guardan para reutilizarlas** (hoja `plantillas_notificacion`, por organización):

1. **Nueva notificación:** tipo (Pago quincenal, Recordatorio de pago, Cumpleaños, Reunión, Recordatorio, Evento, Otro, o uno nuevo con el botón **+**), título (hasta 100 caracteres) y mensaje (hasta 500) → **Guardar**.
2. El listado se filtra por tipo (chips arriba). Cada notificación tiene **Ver**, **Editar** y **Eliminar**. Eliminar la quita del listado; los envíos ya hechos siguen en la hoja `notificaciones`.
3. **Ver** muestra la notificación y, debajo, los destinatarios:
   - **Todos**;
   - **Organizaciones** (una o varias);
   - **Usuarios**: agrupados por organización, con un botón **Todos** por organización.
4. **Enviar notificación.** El aviso dice a cuántos dispositivos llegó. La misma notificación se puede volver a enviar cuantas veces haga falta (dentro de los límites, §1.3).

### 5.2 Desde la hoja

En la hoja `notificaciones`, agregar una fila:

| Columna | Qué poner |
|---|---|
| `remitente_email` | Un email que esté en `usuarios` y tenga acceso. |
| `alcance` | `global`, `organizaciones` o `usuarios` (lista desplegable). |
| `organizacion_ids` | IDs **o nombres**, separados por coma (para `organizaciones`). |
| `usuarios` | Emails separados por coma (para `usuarios`). |
| `titulo`, `cuerpo` | El texto. |
| `ruta` | Opcional, por ejemplo `/ventas`. |
| `estado` | **`PENDIENTE`**, al final. |

Dejar vacíos `id`, `fecha`, `enviados`, `fallidos` y `detalle`. Con el disparador instalado, se envía al poner `PENDIENTE`; si no, ejecutar `enviarNotificacionesPendientes` desde el editor. Una fila ya procesada no se reenvía.

### 5.3 Desde la terminal (pruebas)

```bash
curl -sL -H 'Content-Type: application/json' -d '{
  "action": "enviar_notificacion",
  "usuario_sesion": "<email remitente con acceso>",
  "data": { "alcance": "usuarios", "usuarios": ["<email destino>"],
            "titulo": "Prueba", "cuerpo": "Hola", "datos": { "ruta": "/ventas" } }
}' "https://script.google.com/macros/s/AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA/exec"
```

Respuesta: `{"status":"success","id":"nt…","enviados":N,"fallidos":M}`.

---

## 6. Hojas

**`dispositivos`** (una fila por teléfono y app):

| Columna | Contenido |
|---|---|
| `id` | `dv00000001`… (lo genera el servidor). |
| `usuario_email` | Dueño. |
| `organizacion_id` | Organización al registrarlo. Es informativa: el envío usa la membresía actual. |
| `token` | Token FCM. Cada app (prod, qa, dev) tiene el suyo. |
| `plataforma` | `android` o `ios`. |
| `actualizado` | Último registro. |

El teléfono se registra al iniciar sesión y cuando FCM renueva el token, y se borra al cerrar sesión. Los tokens vencidos los borra el script.

**`tipos_notificacion`** (catálogo común; la crea el script con Pago quincenal, Recordatorio de pago, Cumpleaños, Reunión, Recordatorio, Evento y Otro):

| Columna | Contenido |
|---|---|
| `id` | `tn00000001`… (lo genera el servidor). |
| `nombre` | Único, sin importar mayúsculas (hasta 40 caracteres). |
| `status` | `activo` / `inactivo`. Un tipo inactivo no se ofrece para notificaciones nuevas. |

**`plantillas_notificacion`** (notificaciones guardadas para reutilizar; cada organización ve las suyas):

| Columna | Contenido |
|---|---|
| `id` | `pn00000001`… (lo genera el servidor). |
| `organizacion_id` | Organización dueña. |
| `tipo_id` | FK a `tipos_notificacion.id`. |
| `titulo`, `cuerpo` | Hasta 100 y 500 caracteres. |
| `creado_por`, `actualizado_en` | Autor y último cambio. |

Crear, editar o eliminar una notificación guardada o un tipo envía el aviso silencioso `config_notificaciones` (§1.3), así el listado se actualiza en los teléfonos que lo tienen abierto.

**`config_notificaciones`** (una fila por organización; la crea el script al guardar la primera, o `prepararHojasNotificaciones()`):

| Columna | Contenido |
|---|---|
| `id` | `cn00000001`… (lo genera el servidor). |
| `organizacion_id` | Organización (una sola fila por organización). |
| `periodo` | `hora`, `dia`, `semana` o `mes` (lista desplegable). |
| `limite_por_usuario` | Entero; `0` = sin límite. |
| `limite_organizacion` | Entero; `0` = sin límite. |
| `actualizado_en`, `actualizado_por` | Último cambio (lo completa el script / la app). |

**`notificaciones`** (una fila por envío):

| Columna | Contenido |
|---|---|
| `id` | `nt00000001`… |
| `fecha` | Momento del envío. |
| `remitente_email` | Quién envió. |
| `alcance`, `organizacion_ids`, `usuarios` | Destino, ya normalizado. |
| `titulo`, `cuerpo`, `ruta` | Contenido. |
| `estado` | `PENDIENTE` → `ENVIADA`, `SIN_DESTINATARIOS` o `ERROR`. |
| `enviados`, `fallidos` | Resultado. |
| `detalle` | Motivo del error o tokens dados de baja. |

---

## 7. Diagnóstico

| Síntoma | Causa | Qué hacer |
|---|---|---|
| No aparece la fila en `dispositivos` | Sin `google-services.json` en el build, permiso de notificaciones denegado, o la app nunca inició sesión con la build nueva. | Revisar el permiso en Ajustes → Apps → Estilo Neutral → Notificaciones; volver a iniciar sesión. |
| `ERROR` "falta la propiedad del script FCM_SERVICE_ACCOUNT" | No hay credencial. | §4.5. |
| `ERROR` "Google rechazó la cuenta de servicio" | La clave fue revocada, el JSON está incompleto o la API está deshabilitada. | Crear una clave nueva (§4.4) y verificar la API (§4.2). |
| `ERROR` con `403` en `detalle` | A `fcm-sender` le falta el rol, o la clave es de otro proyecto. | <https://console.cloud.google.com/iam-admin/iam?project=estilo-neutral> |
| `SIN_DESTINATARIOS` | Ningún destinatario tiene un teléfono registrado. | Que inicien sesión con la build nueva y acepten el permiso. |
| "dispositivos dados de baja" en `detalle` | Tokens vencidos (app desinstalada o datos borrados). | Nada: el script los limpia. |
| "Llegaste al límite de N notificaciones…" o "Tu organización llegó a su límite…" | Se agotó el cupo del período de esa organización (§1.3). | Esperar a la fecha que indica el mensaje, o subir el límite en **Configuración de notificaciones**. |
| No llega nada, pero el envío figura `ENVIADA` | La app instalada es anterior a `1.0.0+2014` y no sabe mostrar los mensajes solo de datos. | Instalar la versión actual. |
| Llega varios segundos tarde con la app cerrada | Android tiene que arrancar la app en segundo plano para armarla (más lento en builds debug). | Normal. En Xiaomi/MIUI: Ajustes → Apps → Estilo Neutral → **Ahorro de batería: sin restricciones** e **Inicio automático** activado. |
| Aparece una notificación **vacía** (sin título ni texto) | App anterior a `1.0.0+2022`: no conoce los avisos silenciosos `config_notificaciones` / `uso_notificaciones`. | Instalar la versión actual. |
| Un usuario inactivado sigue con la sesión abierta | App anterior a `1.0.0+2017` (no conoce el aviso silencioso), sin conexión, o se inactivó a mano en la hoja sin el disparador instalado. | Se cierra igual al volver a la app o al intentar guardar. Instalar la versión actual. |
| `INSTALL_FAILED_VERSION_DOWNGRADE` al instalar | El teléfono tiene un `versionCode` mayor. Builds viejos con `--split-per-abi` usaban `2009`. | `--version X.Y.Z+<mayor>`. El deploy lo detecta y sugiere el número. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | La app instalada tiene otra firma (por ejemplo, debug de `flutter run`). | Instalar el build debug encima, o desinstalar y poner el release (se pierden los datos locales). |

Comandos útiles, con el teléfono por USB:

```bash
adb logcat -s FirebaseMessaging                    # recepción y descarga de la imagen
adb shell dumpsys notification --noredact | grep -A14 "<texto de la notificación>"
node tools/apps_script/tests/notificaciones.test.js # tests del script, sin Google
```

---

## 8. Seguridad, privacidad y costo

- **Remitente no autenticado (DT-1).** El `/exec` acepta pedidos anónimos y el remitente es el email que declara la app. Alguien que conozca la URL y el email de un usuario podría enviar notificaciones a todos. Lo acotan los límites de envío de cada organización (§1.3) y el registro de cada envío; como cualquiera puede cambiar esos límites, no reemplazan a la autenticación. La solución completa es la de DT-1 (`docs/deuda-tecnica.md`): verificar un token de Google en el script.
- **Sin roles.** Cualquier usuario puede notificar a cualquier organización, y así se pidió. Si se agregan roles, conviene restringir el alcance `global`.
- **Contenido.** Pasa por Google y aparece en la pantalla bloqueada: no incluir montos, cédulas ni datos de clientes.
- **Credencial.** `fcm-sender` solo puede enviar mensajes. Para rotar la clave: crear una nueva, reemplazar el archivo local y la propiedad, desplegar y **borrar la vieja** en Google Cloud. Las versiones anteriores del script conservan la credencial embebida, así que la única forma de invalidarla es borrarla en Google Cloud.
- **Costo:** cero. Firebase en Spark sin facturación, FCM gratis, Apps Script y Drive dentro de la cuota gratuita. Lo único pago sería iOS (USD 99 por año).
- **Volumen.** La API v1 envía de a un dispositivo por pedido (el script agrupa de a 50). Alcanza para cientos de dispositivos; para miles, convendría usar topics.

---

## 9. Archivos involucrados

| Parte | Archivos |
|---|---|
| App: canal push | `lib/features/notificaciones/infrastructure/push_gateway.dart`, `push_firebase.dart` |
| App: estado | `presentation/cubit/push_cubit.dart` (registro y apertura), `enviar_notificacion_cubit.dart` |
| App: pantallas | `presentation/pages/notificaciones_page.dart` (listado, filtro por tipo y formulario; ruta `/notificaciones`) y `enviar_notificacion_page.dart` (Ver: destinatarios y envío; ruta `/notificaciones/:id`) |
| App: notificaciones guardadas | `plantillas_notificacion_cubit.dart`, `plantilla_form_cubit.dart`; modelo `lib/models/plantilla_notificacion.dart`; `SheetsDataService.addPlantillaNotificacion`, `updatePlantillaNotificacion`, `deletePlantillaNotificacion`, `addTipoNotificacion` |
| App: límites | `presentation/pages/config_notificaciones_page.dart` + `config_notificaciones_cubit.dart`, ruta `/configuracion-notificaciones`; modelo `lib/models/config_notificaciones.dart`; `SheetsDataService.guardarConfigNotificaciones`, `usoNotificaciones` |
| Script: notificaciones guardadas | `_hojaTiposNotificacion` (crea el catálogo inicial), `_validarPlantillaNotificacion`, `_validarTipoNotificacion` |
| Script: avisos silenciosos | `_enviarSilencioso`, `_avisarSilencioso`, `_avisarUsoOrganizacion` (y `_expulsarUsuario`) |
| Script: límites | `_validarConfigNotificaciones`, `_configNotificaciones`, `_limitesPeriodo`, `_cuotaNotificaciones`, `_usoNotificaciones` en `google_apps_script.js` |
| App: servicio | `SheetsDataService.registrarDispositivo`, `eliminarDispositivo`, `enviarNotificacion` (`_accionEnServidor`) |
| App: cierre silencioso | `PushCubit.atenderSesionRevocada`, `manejadorSegundoPlano` + `consumirAvisoRevocacion`, `lib/features/auth/application/control_acceso_sesion.dart` |
| Script: estado y expulsión | `_estadoActivo`, `_asegurarColumnaEstado`, `_expulsarUsuario`, `_enviarMensajesFcm` en `google_apps_script.js` |
| Arranque | `lib/main.dart`, `lib/app/di/injection.dart`, `lib/firebase_options.dart` (provisorio) |
| Android | `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `res/drawable/ic_notificacion.xml`, `res/drawable-nodpi/*`, `res/values/colors.xml`, `res/raw/keep.xml` |
| iOS | `ios/Runner/Info.plist` (`remote-notification`), `ios/Podfile` |
| Script | `google_apps_script.js`, módulo NOTIFICACIONES |
| Deploy | `tools/deploy.sh`, `tools/apps_script/deploy.sh`, `tools/apps_script_test/deploy.sh`, `tools/apps_script/generar_credencial_fcm.sh` |
| Tests | `test/features/notificaciones/notificaciones_test.dart`, `tools/apps_script/tests/notificaciones.test.js` |
| Archivos fuera de git | `android/app/google-services.json`, `fcm-clave-*.json`, `credencial_fcm.js` (ver `docs/configuracion-local.md`) |
