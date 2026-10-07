# Informe de revisión de formularios — Pendientes

**Fecha de la revisión:** 2026-10-06 · **Última actualización:** 2026-10-07

Este documento conserva solo lo que **todavía no está resuelto**. Todos los hallazgos de código de la revisión ya se corrigieron y se quitaron de acá. Las reglas que evitan que vuelvan están en [docs/estandar-hojas.md](docs/estandar-hojas.md), y los tests de `test/standards/` y `test/shared/pendientes_informe_test.dart` las verifican.

Queda pendiente la [deuda técnica registrada](#1-deuda-técnica-registrada), con decisiones de producto que se postergaron a propósito, y la [prueba de la build nueva con notificaciones FCM](#2-notificaciones-fcm-firebase-cloud-messaging) (§2). Los datos de producción se corrigieron el 2026-10-07 (lotes `tx_limpieza_datos_2026-10-07` y `tx_cedulas_demo_2026-10-07`, registrados en la bitácora). Las cédulas V-99000002 a V-99000005 de los clientes son valores demo definitivos.

---

## 1. Deuda técnica registrada

| ID | Qué | Detalle |
|---|---|---|
| DT-1 | No hay roles: cualquier usuario con sesión administra usuarios y organizaciones | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-1-no-hay-roles-cualquier-usuario-con-sesión-administra-usuarios-y-organizaciones) |
| DT-3 | La opción "2FA" de Seguridad no pide un segundo factor | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-3-la-opción-2fa-de-seguridad-no-pide-un-segundo-factor) |

---

## 2. Notificaciones FCM (Firebase Cloud Messaging)

**Implementado:** 2026-10-07 · **Estado:** listo en la app y en el script (producción @54). Configuración externa lista:
- pasos 1 y 2;
- paso 5: credencial de `fcm-sender@estilo-neutral`, cargada en la propiedad `FCM_SERVICE_ACCOUNT` y, como respaldo, embebida por `deploy.sh`;
- paso 6: hojas `dispositivos` y `notificaciones` creadas en producción y disparador de envío desde la hoja instalado.

Se verificó en producción con una notificación de prueba (`nt00000001`): la credencial firmó, FCM respondió y el token de prueba se dio de baja solo. La build de release ya está compilada. **Falta solo la prueba en un teléfono real.**

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

### 2.3 Pendiente: Build nueva y prueba final

La infraestructura externa (Firebase Spark, Google Cloud, Apps Script con `FCM_SERVICE_ACCOUNT` y las hojas `dispositivos` y `notificaciones` en producción) **ya está completamente configurada y lista** (detalle completo de infraestructura en [docs/configuracion-local.md](docs/configuracion-local.md)).

Solo queda pendiente la verificación de extremo a extremo:

1. **Instalar la build nueva.** Ya está compilada: versión `1.0.0+10`, `prod`, firmada con la clave de release.
   - APK: `build/app/outputs/flutter-apk/app-prod-release.apk`. Se instala con `adb install -r …` o copiándolo al teléfono.
   - AAB para Google Play: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`.
2. **Iniciar sesión:** la app solicita permiso de notificaciones (Android 13+ e iOS). Al aceptarlo, debe registrarse el teléfono automáticamente y aparecer una fila en `dispositivos`.
3. **Enviar notificación de prueba:** menú lateral → **Comunicación → Notificaciones** → enviarse una notificación a uno mismo (alcance **Usuarios**).
4. **Probar recepción:** en los tres escenarios: con la app abierta, en segundo plano y cerrada. Tocar la notificación debe abrir la app en la ruta indicada.
5. **Revisar la hoja:** verificar en `notificaciones` que la fila quede con estado `ENVIADA` y `enviados` mayor que 0.

### 2.4 Diagnóstico durante la prueba

| Síntoma | Causa probable |
|---|---|
| No aparece la fila en `dispositivos` | Falta `google-services.json` o `GoogleService-Info.plist`, el usuario no dio permiso, o en iOS falta la capability Push Notifications o la clave APNs. |
| `ERROR` con "falta la propiedad del script FCM_SERVICE_ACCOUNT" | Falta el paso 5. |
| `ERROR` con "Google rechazó la cuenta de servicio" | El JSON está incompleto, la clave fue revocada o la API FCM no está habilitada. |
| `ERROR` con 403 en `detalle` | A la cuenta de servicio le falta el rol de FCM, o es de otro proyecto. |
| `SIN_DESTINATARIOS` | Ninguno de los destinatarios tiene un teléfono registrado (nunca inició sesión con la build nueva o no dio permiso). |
| "dispositivos dados de baja" en `detalle` | Tokens vencidos (app desinstalada, datos borrados). Es normal; el script los limpia. |
| "Límite de 30 notificaciones por hora" | Ese remitente ya envió 30 en la última hora desde la app. |

### 2.5 Riesgos y límites

- **Remitente no autenticado (DT-1).** El `/exec` acepta pedidos anónimos, y el remitente es el email que declara la app. Alguien que conozca la URL y el email de un usuario podría enviar notificaciones a todos. Lo acotan el límite de 30 por hora y el registro de cada envío en `notificaciones` y en la bitácora. La solución completa es la de DT-1: verificar un token de Google en el script.
- **Sin roles (DT-1).** Cualquier usuario puede notificar a cualquier organización. Así se pidió; si más adelante se agregan roles, conviene restringir el alcance `global`.
- **Contenido.** El texto pasa por los servidores de Google y aparece en la pantalla bloqueada. No conviene incluir montos, cédulas ni datos de clientes.
- **Volumen.** La API v1 de FCM envía de a un dispositivo por pedido (el script los agrupa de a 50). Alcanza para decenas o cientos de dispositivos. Para miles, convendría usar topics de FCM.
- **Costo.** Cero para Android: Firebase en plan Spark (sin facturación), FCM gratis, Apps Script con la cuota gratuita. Lo único pago es iOS (Apple Developer Program, USD 99 por año), que se omite.

### 2.6 Ajustes del 2026-10-07 (cierre de la configuración)

| Qué | Detalle |
|---|---|
| Credencial embebida | `tools/apps_script/generar_credencial_fcm.sh` genera `credencial_fcm.js` (fuera de git) a partir de `fcm-clave-*.json`, y los dos `deploy.sh` lo suben junto al script. El script usa primero la propiedad `FCM_SERVICE_ACCOUNT` y después esa credencial. |
| Acción `preparar_notificaciones` | Crea las hojas con sus listas desplegables e instala el disparador de envío desde la hoja. Es idempotente y exige un usuario con acceso. Equivale a correr `prepararHojasNotificaciones` y `crearTriggerNotificacionesDesdeHoja` desde el editor. |
| Ícono de notificación | `android/app/src/main/res/drawable/ic_notificacion.xml` (campana monocroma) y `res/raw/keep.xml`, para que el build release no lo descarte. |
| URL por defecto del Apps Script | `lib/shared/google_sheets/sheets_config.dart` apuntaba a una implementación vieja. Ahora apunta a la de producción (`AKfycby6Jg1o…`). |
| Versión | `1.0.0+2011`. El teléfono de pruebas tenía `2009`, de un build viejo con `--split-per-abi`; ver `compile.md` §6.1. |
| Marca en las notificaciones | Color dorado del logo (`#BC976F`) en el ícono y el nombre de la app, y el **logo a color** (`assets/icons.png`) como imagen de la notificación. Con la app cerrada lo envía FCM desde una URL pública de Drive (`LOGO_NOTIFICACION_URL` en el script); con la app abierta sale del APK (`drawable-nodpi/ic_logo_notificacion.png`). El ícono chico sigue siendo una campana: Android lo exige monocromo, y para usar la silueta del monograma "EN" hace falta el logo en SVG o en PNG transparente. |
| Tests | 355 de Flutter y 32 del script (`node tools/apps_script/tests/notificaciones.test.js`). |

