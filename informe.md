# Pendientes

**Última actualización:** 2026-10-07

Este documento lista solo lo que **todavía no está resuelto**. Lo terminado se documentó aparte:

- Notificaciones push (FCM): [docs/notificaciones-fcm.md](docs/notificaciones-fcm.md), con la configuración paso a paso y los enlaces de cada consola.
- Archivos fuera de git y configuración: [docs/configuracion-local.md](docs/configuracion-local.md).
- Reglas para hojas y escrituras: [docs/estandar-hojas.md](docs/estandar-hojas.md).
- Deploy: `compile.md` §6.1 (`tools/deploy.sh`).

---

## 1. Deuda técnica

| ID | Qué | Detalle |
|---|---|---|
| DT-1 | No hay roles: cualquier usuario con sesión administra usuarios y organizaciones, y puede enviar notificaciones a cualquier organización. El Apps Script tampoco autentica al remitente. | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-1-no-hay-roles-cualquier-usuario-con-sesión-administra-usuarios-y-organizaciones) |
| DT-3 | La opción "2FA" de Seguridad no pide un segundo factor. | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-3-la-opción-2fa-de-seguridad-no-pide-un-segundo-factor) |

---

## 2. Notificaciones FCM

| # | Pendiente | Qué hacer |
|---|---|---|
| 2.1 | **Probar en la app `prod`.** Todas las pruebas llegaron a la app QA: en `dispositivos` solo está registrado el teléfono desde QA. | Abrir **Estilo Neutral** (sin "QA"), iniciar sesión y aceptar el permiso de notificaciones. Tiene que aparecer una segunda fila en `dispositivos`. Después, enviarse una desde **Comunicación → Notificaciones**. |
| 2.2 | **Ícono chico con el monograma "EN"** (opcional). Hoy es una campana dorada, porque Android exige un ícono monocromo y el logo es un render 3D. | Conseguir el monograma en **SVG** o en **PNG con fondo transparente** para convertirlo en vector (ver [§4.7 de la guía](docs/notificaciones-fcm.md#47-marca-de-las-notificaciones)). |
| 2.3 | **iOS sin notificaciones**, por costo: Apple Developer Program, USD 99 por año. | Solo si se decide pagarlo: pasos en [§4.9 de la guía](docs/notificaciones-fcm.md#49-ios-no-configurado). |

---

## 3. Configuración

Observaciones de [docs/configuracion-local.md](docs/configuracion-local.md) §6 que siguen abiertas:

| # | Pendiente | Impacto | Qué hacer |
|---|---|---|---|
| 3.1 | Las variantes `dev` y `qa` usan la **hoja y el Apps Script de producción**. | Las pruebas escriben datos reales: las notificaciones de prueba de hoy quedaron en la hoja `notificaciones` de producción. | Ya existe una hoja de test (`1vtdKdAm…`, la del script de test), pero la app no puede usarla: **es privada** (gviz responde 401) y la **implementación de test pide login de Google**. Para usarla: compartir la hoja de test como "Cualquier persona con el enlace: lector", publicar la implementación de test con acceso "Cualquier usuario", y apuntar `SPREADSHEET_ID` y `APPS_SCRIPT_URL` de `.env.dev` y `.env.test` a ella. Además, cada usuario de prueba tiene que estar en su hoja `usuarios`. |
| 3.2 | Google Sign-In **no está configurado en iOS** (falta `GIDClientID` en `Info.plist`). | El login no funcionaría en iPhone. | Solo si se publica en iOS: crear el cliente OAuth de iOS y agregarlo a `Info.plist`. |
