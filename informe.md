# Pendientes

**Última actualización:** 2026-10-09

Este documento lista solo lo que **todavía no está resuelto**. Lo terminado se documentó aparte:

- Notificaciones push (FCM): [docs/notificaciones-fcm.md](docs/notificaciones-fcm.md), con la configuración paso a paso y los enlaces de cada consola.
- Archivos fuera de git y configuración: [docs/configuracion-local.md](docs/configuracion-local.md).
- Reglas para hojas y escrituras: [docs/estandar-hojas.md](docs/estandar-hojas.md).
- Deploy: `compile.md` §6.1 (`tools/deploy.sh`).

---

## 1. Deuda técnica

| ID   | Qué                                                                                                                                                                                                                                                                            | Detalle                                                                                                                            |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| DT-1 | No hay roles: cualquier usuario con sesión administra usuarios y organizaciones, y puede enviar notificaciones a cualquier organización. (La autenticación ya está: token de Google verificado y obligatorio desde el 2026-10-09, ver [docs/seguridad.md](docs/seguridad.md).) | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-1-no-hay-roles-cualquier-usuario-con-sesión-administra-usuarios-y-organizaciones) |
| DT-3 | La opción "2FA" de Seguridad no pide un segundo factor.                                                                                                                                                                                                                        | [docs/deuda-tecnica.md](docs/deuda-tecnica.md#dt-3-la-opción-2fa-de-seguridad-no-pide-un-segundo-factor)                           |

---

## 2. Notificaciones FCM

| #   | Pendiente                                                                       | Qué hacer                                                                                                |
| --- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| 2.1 | **iOS sin notificaciones**, por costo: Apple Developer Program, USD 99 por año. | Solo si se decide pagarlo: pasos en [§4.9 de la guía](docs/notificaciones-fcm.md#49-ios-no-configurado). |

---

## 3. Configuración

Observaciones de [docs/configuracion-local.md](docs/configuracion-local.md) §6 que siguen abiertas:

| #   | Pendiente                                                                            | Impacto                                                                                                                    | Qué hacer                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| --- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 3.1 | Las variantes `dev` y `qa` usan la **hoja y el Apps Script de producción**.          | Las pruebas escriben datos reales: las notificaciones de prueba de hoy quedaron en la hoja `notificaciones` de producción. | Ya existe una hoja de test (`1vtdKdAm…`, la del script de test), pero la app no puede usarla: **es privada** (gviz responde 401) y la **implementación de test pide login de Google**. Para usarla: compartir la hoja de test como "Cualquier persona con el enlace: lector", publicar la implementación de test con acceso "Cualquier usuario", y apuntar `SPREADSHEET_ID` y `APPS_SCRIPT_URL` de `.env.dev` y `.env.test` a ella. Además, cada usuario de prueba tiene que estar en su hoja `usuarios`. |
| 3.2 | Google Sign-In **no está configurado en iOS** (falta `GIDClientID` en `Info.plist`). | El login no funcionaría en iPhone.                                                                                         | Solo si se publica en iOS: crear el cliente OAuth de iOS y agregarlo a `Info.plist`.                                                                                                                                                                                                                                                                                                                                                                                                                      |

---

## 4. Seguridad: pasos del dueño

Detalle en [docs/seguridad.md](docs/seguridad.md) §2. Ya hechos (2026-10-09): token obligatorio, `OAUTH_CLIENTES_PERMITIDOS` en producción y test, hojas de producción y test en **Restringido**, app QA permitida (verificado: gviz responde 401 desde afuera y la app carga por el Apps Script).

| #   | Pendiente                                                                                                                                                                       | Qué hacer                                                                                                                    |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 4.1 | Actualizar **todos** los teléfonos a `1.0.0+2025` o posterior (las anteriores ya no pueden guardar: el token es obligatorio desde `@68`) y comprobar que los datos se ven bien. | Si algo se ve mal: propiedad del script `LECTURA_POR_SERVIDOR` = `no`.                                                       |
| 4.2 | Revisar accesos.                                                                                                                                                                | Hoja, carpeta de Drive, proyecto de Apps Script, Google Cloud/Firebase; permisos viejos en myaccount.google.com/permissions. |

Firebase App Tester La distribución de APK de prueba, si la usaste. Es inofensiva.

Seguridad: lo que queda por diseñar
Separar las organizaciones en el servidor. Hoy el servidor verifica quién sos, pero leer_hojas devuelve los datos de todas las organizaciones, y la app es la que filtra. Con una sola organización no hay riesgo. Antes de sumar una segunda, el servidor tiene que filtrar por organización al leer y al escribir.
Roles y permisos (DT-1). Hoy cualquier usuario registrado puede hacer cualquier cambio. Faltan perfiles, por ejemplo vendedor y administrador.
Verificación en dos pasos en la app (DT-3). La columna dos_factores existe en la hoja, pero no está implementada.
QA y dev usan la hoja de producción. Las pruebas tocan datos reales. Hay que apuntarlas a la hoja de test.
Copias de seguridad automáticas de la hoja, por ejemplo una copia semanal en la carpeta privada, sin costo.

Producto
App de catálogo. Quedó en pausa para hacer primero la seguridad. Con las fotos ya separadas por organización y públicas solo para ver, la base está lista.
Logs detallados en QA. Quedó anotado como mejora para depurar más fácil.
