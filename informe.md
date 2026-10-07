# Informe de revisión de formularios — Pendientes

**Fecha de la revisión:** 2026-10-06 · **Última actualización:** 2026-10-07

Este documento conserva solo lo que **todavía no está resuelto**. Todos los hallazgos de código de la revisión ya se corrigieron y se quitaron de acá. Las reglas que evitan que vuelvan están en [docs/estandar-hojas.md](docs/estandar-hojas.md), y los tests de `test/standards/` y `test/shared/pendientes_informe_test.dart` las verifican.

Queda pendiente la [deuda técnica registrada](#1-deuda-técnica-registrada), con decisiones de producto que se postergaron a propósito, y la [configuración externa de las notificaciones FCM](#2-notificaciones-fcm-firebase-cloud-messaging) (§2). Los datos de producción se corrigieron el 2026-10-07 (lotes `tx_limpieza_datos_2026-10-07` y `tx_cedulas_demo_2026-10-07`, registrados en la bitácora). Las cédulas V-99000002 a V-99000005 de los clientes son valores demo definitivos.

---

## 1. Deuda técnica registrada

| ID | Qué | Detalle |
|---|---|---|
| DT-1 | No hay roles: cualquier usuario con sesión administra usuarios y organizaciones | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-1-no-hay-roles-cualquier-usuario-con-sesión-administra-usuarios-y-organizaciones) |
| DT-3 | La opción "2FA" de Seguridad no pide un segundo factor | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-3-la-opción-2fa-de-seguridad-no-pide-un-segundo-factor) |

---

## 2. Notificaciones FCM (Firebase Cloud Messaging)

**Implementado:** 2026-10-07 · **Estado:** listo en la app y en el script (producción @53). Configuración externa lista: pasos 1, 2, 5 (propiedad `FCM_SERVICE_ACCOUNT` cargada) y 6 (hojas `dispositivos` y `notificaciones` creadas en producción). Queda el paso 7: compilar la build nueva y probar.

### 2.1 Qué se puede hacer

Cualquier usuario que esté en la hoja `usuarios`, con membresía en una organización que exista, puede enviar una notificación a:

| Destino | Alcance | Cómo se elige |
|---|---|---|
| Todos | `global` | Todos los usuarios con acceso, de todas las organizaciones. |
| Una organización | `organizaciones` | Una organización. |
| Varias organizaciones | `organizaciones` | Varias organizaciones a la vez. |
| Un usuario de una organización | `usuarios` | Un email. |
| Varios usuarios de una o varias organizaciones | `usuarios` | Varios emails, de la misma o de distintas organizaciones. |

Se puede enviar de dos formas:

1. **Desde la app:** menú lateral → **Comunicación → Notificaciones**. Se elige el alcance, las organizaciones o los usuarios (agrupados por organización, con "Todos" por organización), el título y el mensaje.
2. **Desde la hoja de Google Sheets:** se carga una fila en `notificaciones` con estado `PENDIENTE` (ver el paso 6).

Reglas del servidor:

- Solo reciben los dispositivos de usuarios que **siguen teniendo acceso**, según la organización a la que pertenecen **hoy**, aunque los hayan movido después de registrar su teléfono.
- Una notificación que se toca abre la pantalla indicada en `ruta` (por ejemplo `/ventas`), si viene.
- Cada envío queda registrado en la hoja `notificaciones` y en la bitácora.
- Desde la app hay un límite de **30 envíos por hora por remitente**, para acotar el abuso (ver 2.6).

> **Sobre "clientes":** los destinatarios son **usuarios de la app**, porque son los únicos que tienen el teléfono registrado. Los clientes de la hoja `clientes` no usan la app y no pueden recibir notificaciones FCM. Para avisarles a ellos haría falta otro canal, como WhatsApp, SMS o email.

### 2.2 Hojas nuevas

Las crea el script la primera vez que se usan, o el paso 6.

**`dispositivos`** — un teléfono registrado por fila:

| Columna | Contenido |
|---|---|
| `id` | `dv00000001`… (lo genera el servidor) |
| `usuario_email` | Dueño del dispositivo. |
| `organizacion_id` | Organización del usuario al registrarlo (solo informativo: el envío usa la membresía actual). |
| `token` | Token FCM del teléfono. |
| `plataforma` | `android` o `ios`. |
| `actualizado` | Último registro (ISO 8601). |

El teléfono se registra al iniciar sesión y cuando FCM renueva el token, y se borra al cerrar sesión. Si FCM informa que un token venció, el script borra esa fila.

**`notificaciones`** — una notificación por fila:

| Columna | Contenido |
|---|---|
| `id` | `nt00000001`… |
| `fecha` | Momento del envío. |
| `remitente_email` | Quién la envía. Tiene que estar en `usuarios`. |
| `alcance` | `global`, `organizaciones` o `usuarios`. |
| `organizacion_ids` | IDs **o nombres** de organizaciones, separados por coma (solo para `organizaciones`). |
| `usuarios` | Emails separados por coma (solo para `usuarios`). |
| `titulo` | Hasta 100 caracteres. |
| `cuerpo` | Hasta 500 caracteres. |
| `ruta` | Opcional: pantalla a abrir, por ejemplo `/ventas`. |
| `estado` | `PENDIENTE` → `ENVIADA`, `SIN_DESTINATARIOS` o `ERROR`. |
| `enviados` / `fallidos` | Resultado. |
| `detalle` | Motivo del error o tokens dados de baja. |

### 2.3 Paso a paso de configuración

**Paso 1. Proyecto de Firebase** — ✔ hecho el 2026-10-07

Se creó un proyecto de Firebase **aparte**, **`estilo-neutral`**, en el plan **Spark**: sin cuenta de facturación y sin costo. Gemini y Google Analytics quedaron desactivados.

No se usó `gmp-demo-project-093718520` (el de Google Sign-In) por dos motivos:
- agregarle Firebase lo habría pasado al plan Blaze si tenía facturación vinculada;
- borrar ese proyecto desde Firebase borraría también los clientes OAuth del login.

Requisito de **costo cero**: si alguna pantalla pide tarjeta, "Actualizar a Blaze" o "Vincular facturación", se cancela. Ningún paso de esta guía lo necesita.

Verificar que la API **Firebase Cloud Messaging API** (v1) esté habilitada en el proyecto nuevo: <https://console.cloud.google.com/apis/library/fcm.googleapis.com?project=estilo-neutral>

**Paso 2. Android** — ✔ hecho el 2026-10-07: 3 apps registradas en `estilo-neutral` y `android/app/google-services.json` instalado. Se verificó que el build `dev` usa la app `.dev` y el `prod` la principal.

1. En Firebase → **Configuración del proyecto → Tus apps → Agregar app → Android**. Registrar **tres** apps, una por variante de compilación:
   - `com.estiloneutral.es` (prod)
   - `com.estiloneutral.es.dev` (dev)
   - `com.estiloneutral.es.qa` (qa)
2. Descargar **`google-services.json`**. El de la consola trae las tres apps en un solo archivo.
3. Copiarlo en **`android/app/google-services.json`**. Está en el `.gitignore`: sus claves de cliente no son secretas, pero el repo no las publica.
4. Listo: el build lo detecta solo. `android/app/build.gradle.kts` aplica el plugin `com.google.gms.google-services` únicamente si ese archivo existe, y elige la app que corresponde a cada variante. Se verificó con AGP 9.1.
5. **Opcional, recomendado:** un ícono de notificación monocromo (blanco sobre transparente) en `android/app/src/main/res/drawable/ic_notificacion.png`. Después hay que cambiar `@mipmap/ic_launcher` por `@drawable/ic_notificacion` en `AndroidManifest.xml` (`default_notification_icon`) y en `push_firebase.dart` (`AndroidInitializationSettings`). Sin esto, Android muestra el ícono de la app como un cuadrado.

**Paso 3. iOS** — opcional, **tiene costo**: Apple Developer Program, USD 99 por año. Con el requisito de costo cero **se omite**. iOS funciona sin notificaciones.

1. En <https://developer.apple.com> → **Certificates, Identifiers & Profiles → Keys** → crear una clave con **Apple Push Notifications service (APNs)**. Descargar el `.p8` (se baja una sola vez) y anotar el **Key ID** y el **Team ID**.
2. En **Identifiers → `com.estiloneutral.es`**, activar la capability **Push Notifications**.
3. En Firebase → **Agregar app → iOS** con bundle `com.estiloneutral.es` → descargar **`GoogleService-Info.plist`**.
4. En Firebase → **Configuración del proyecto → Cloud Messaging → Configuración de apps de Apple** → subir el `.p8` con su Key ID y Team ID.
5. En Xcode (`ios/Runner.xcworkspace`):
   - arrastrar `GoogleService-Info.plist` a `Runner`, con *Copy items if needed* y el target `Runner` marcado (el archivo está en el `.gitignore`);
   - en **Signing & Capabilities**, elegir el Team y agregar **Push Notifications** (crea `Runner.entitlements`);
   - **Background Modes → Remote notifications** ya está en `Info.plist`; si Xcode no lo muestra marcado, marcarlo.
6. `cd ios && pod install`. El Podfile ya fija iOS 15.
7. Las notificaciones push en iOS se prueban en un **iPhone real**. En simulador solo funcionan con Xcode 14 o superior y Mac con Apple Silicon.

**Paso 4. (Alternativa) `firebase_options.dart`**

No hace falta si se hicieron los pasos 2 y 3: la app usa primero `google-services.json` y `GoogleService-Info.plist`. Si se prefiere la configuración en Dart:

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=estilo-neutral --platforms=android
```

Eso reemplaza `lib/firebase_options.dart`. Tiene una limitación: solo guarda **una** app Android (la de prod). Para las variantes dev y qa, igual hace falta `google-services.json`.

**Paso 5. Credencial para que el Apps Script envíe** — ✔ hecho el 2026-10-07: cuenta `fcm-sender@estilo-neutral.iam.gserviceaccount.com` creada con rol `Firebase Cloud Messaging API Admin` y propiedad `FCM_SERVICE_ACCOUNT` cargada en Apps Script.

1. En Google Cloud Console → **IAM y administración → Cuentas de servicio → Crear cuenta de servicio**:
   - Nombre: `fcm-sender`.
   - Rol: **Firebase Cloud Messaging API Admin** (`roles/firebasecloudmessaging.admin`).
   - Paso 3 ("Otorgar acceso a los usuarios a esta cuenta de servicio"): **dejar los dos campos vacíos y tocar Listo.** Esos campos sirven para que otras cuentas de Google puedan actuar como `fcm-sender` o administrarla. No hace falta: Apps Script usa la clave JSON directamente. Además, si se completaran, esas personas podrían enviar notificaciones con esta cuenta.
2. En la lista de cuentas de servicio:
   - Tocar `fcm-sender@estilo-neutral.iam.gserviceaccount.com`.
   - Ir a la pestaña **Claves → Agregar clave → Crear clave nueva → JSON → Crear**.
   - Se descarga el archivo de clave (`fcm-clave-estilo-neutral-b0072e1b908a.json`).
3. **Cargar en Apps Script:** ✔ cargado en las propiedades del script de producción como `FCM_SERVICE_ACCOUNT`.
4. **Respaldo técnico:** Se conserva una copia segura en `respaldo_tecnico/firebase/` (ignorado en git) junto con los demás secretos del proyecto para otros usuarios y entornos técnicos.

No hace falta volver a desplegar ni volver a autorizar el script: el envío usa permisos que ya tenía (`script.external_request`).

**Paso 6. Preparar la hoja** — ✔ hecho el 2026-10-07: se ejecutó `prepararHojasNotificaciones` en la hoja de producción. Las pestañas `dispositivos` y `notificaciones` quedaron creadas con encabezados, formatos y listas desplegables.

1. **`prepararHojasNotificaciones`**: ✔ ejecutado. Hojas `dispositivos` y `notificaciones` listas en la hoja de producción.
2. **Opcional, `crearTriggerNotificacionesDesdeHoja`**: instala el disparador que envía en cuanto en una fila de `notificaciones` se pone `estado = PENDIENTE`. Sin el disparador, las filas pendientes se envían corriendo **`enviarNotificacionesPendientes`** a mano.

Para enviar desde la hoja: completar `remitente_email` (tiene que estar en `usuarios`), `alcance`, `organizacion_ids` o `usuarios`, `titulo` y `cuerpo`, y poner `estado` en `PENDIENTE` al final. Dejar vacíos `id`, `fecha`, `enviados`, `fallidos` y `detalle`: los completa el script. Una fila ya enviada no se reenvía.

**Paso 7. Build nueva y prueba**

1. Compilar e instalar la build nueva (`compile.md`).
2. Iniciar sesión: la app pide permiso de notificaciones (Android 13+ e iOS). Al aceptarlo, aparece una fila en `dispositivos`.
3. Menú → **Notificaciones** → enviarse una a uno mismo (alcance **Usuarios**).
4. Probar las tres situaciones: con la app abierta (se muestra igual), en segundo plano y cerrada. Tocar la notificación abre la app.
5. Revisar la fila en `notificaciones`: `ENVIADA`, con `enviados` mayor que 0.

Los archivos y propiedades de esta configuración, campo por campo, están en [docs/configuracion-local.md](docs/configuracion-local.md).

### 2.4 Diagnóstico

| Síntoma | Causa probable |
|---|---|
| No aparece la fila en `dispositivos` | Falta `google-services.json` o `GoogleService-Info.plist`, el usuario no dio permiso, o en iOS falta la capability Push Notifications o la clave APNs. |
| `ERROR` con "falta la propiedad del script FCM_SERVICE_ACCOUNT" | Falta el paso 5. |
| `ERROR` con "Google rechazó la cuenta de servicio" | El JSON está incompleto, la clave fue revocada o la API FCM no está habilitada. |
| `ERROR` con 403 en `detalle` | A la cuenta de servicio le falta el rol de FCM, o es de otro proyecto. |
| `SIN_DESTINATARIOS` | Ninguno de los destinatarios tiene un teléfono registrado (nunca inició sesión con la build nueva o no dio permiso). |
| "dispositivos dados de baja" en `detalle` | Tokens vencidos (app desinstalada, datos borrados). Es normal; el script los limpia. |
| "Límite de 30 notificaciones por hora" | Ese remitente ya envió 30 en la última hora desde la app. |

### 2.5 Qué se cambió

| Parte | Archivos |
|---|---|
| Dependencias | `pubspec.yaml`: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`. |
| Android | `android/settings.gradle.kts` (plugin google-services), `android/app/build.gradle.kts` (plugin condicional y desugaring), `AndroidManifest.xml` (permiso `POST_NOTIFICATIONS`, canal e ícono por defecto). |
| iOS | `ios/Runner/Info.plist` (`UIBackgroundModes: remote-notification`), `ios/Podfile` (iOS 15). |
| Arranque | `lib/main.dart` (inicializa Firebase si hay configuración), `lib/app/di/injection.dart` (`PushCubit`), `lib/firebase_options.dart` (provisorio). |
| Feature | `lib/features/notificaciones/`: `DestinoNotificacion`, `PushGateway` / `PushFirebase` / `PushNoDisponible`, `PushCubit` (registro del dispositivo y apertura), `EnviarNotificacionCubit` y `EnviarNotificacionPage`. |
| Navegación | Ruta `/notificaciones` (rama 16 del shell) y sección **Comunicación** en el menú lateral. |
| Servicio | `SheetsDataService.registrarDispositivo`, `eliminarDispositivo`, `enviarNotificacion` y el helper `_accionEnServidor` (agregado a `docs/estandar-hojas.md` R4 y a `CLAUDE.md`). |
| Script | `google_apps_script.js`: módulo NOTIFICACIONES, `ID_PREFIXES` `dv` y `nt`, acciones `registrar_dispositivo`, `eliminar_dispositivo` y `enviar_notificacion`, y las funciones `prepararHojasNotificaciones`, `enviarNotificacionesPendientes` y `crearTriggerNotificacionesDesdeHoja`. |
| Tests | `test/features/notificaciones/notificaciones_test.dart` (18 casos) y `tools/apps_script/tests/notificaciones.test.js` (29 casos del script con Node: `node tools/apps_script/tests/notificaciones.test.js`). |

Verificado: análisis sin problemas, 355 tests de Flutter, 29 del script, build Android `dev` (sin `google-services.json` y con uno de prueba) y build iOS sin firmar.

### 2.6 Riesgos y límites

- **Remitente no autenticado (DT-1).** El `/exec` acepta pedidos anónimos, y el remitente es el email que declara la app. Alguien que conozca la URL y el email de un usuario podría enviar notificaciones a todos. Lo acotan el límite de 30 por hora y el registro de cada envío en `notificaciones` y en la bitácora. La solución completa es la de DT-1: verificar un token de Google en el script.
- **Sin roles (DT-1).** Cualquier usuario puede notificar a cualquier organización. Así se pidió; si más adelante se agregan roles, conviene restringir el alcance `global`.
- **Contenido.** El texto pasa por los servidores de Google y aparece en la pantalla bloqueada. No conviene incluir montos, cédulas ni datos de clientes.
- **Volumen.** La API v1 de FCM envía de a un dispositivo por pedido (el script los agrupa de a 50). Alcanza para decenas o cientos de dispositivos. Para miles, convendría usar topics de FCM.
- **Costo.** Cero para Android: Firebase en plan Spark (sin facturación), FCM gratis, Apps Script con la cuota gratuita. Lo único pago es iOS (Apple Developer Program, USD 99 por año), que se omite.
