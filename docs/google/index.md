# Integraciones con Google

Estilo Neutral usa Google en cuatro capas independientes. Esta sección documenta cómo está configurada cada una, cómo reproducir el setup desde cero, y los errores más comunes que ya nos encontramos.

| Capa | Para qué sirve | Guía |
|---|---|---|
| **Google Sign-In** | Login de usuarios en la app (OAuth 2.0 en Android) | [Google Sign-In](sign-in.md) |
| **Lectura de datos** | La app lee las 14 hojas vía el endpoint público GViz CSV (sin auth) | [Multi-organización](multi-organizacion.md) |
| **Google Apps Script** | Backend que recibe las escrituras (crear/editar/borrar/togglear) desde la app y las aplica al Google Sheet | [Apps Script](apps-script.md) |
| **Automatización local** | Scripts para no tener que copiar/pegar código ni re-subir el `.xlsx` a mano | [Automatización](automatizacion.md) |

Si algo falla, empezá por [Troubleshooting](troubleshooting.md) — cubre los errores reales que ya pisamos mientras armábamos todo esto.

## Diagrama rápido del flujo completo

```
┌─────────────┐     Google Sign-In       ┌──────────────────┐
│  App Flutter │ ───────────────────────► │  Cuenta de Google │
│              │ ◄─────────────────────── │  (login_page.dart)│
└──────┬───────┘      cuenta autorizada   └──────────────────┘
       │
       │ Lee (GET, público, sin auth)
       ▼
┌─────────────────────────┐
│  Google Sheet            │◄────────────┐
│  "Estilo Neutral"         │             │ Escribe (POST)
│  (GViz CSV endpoint)      │             │
└─────────────────────────┘             │
       ▲                                 │
       │ google_apps_script.js           │
       └─────────────────────────────────┘
              (Web App /exec)
```

## IDs y valores de referencia

Estos son los identificadores reales del proyecto — útiles para no tener que volver a buscarlos:

- **Spreadsheet ID:** `1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI`
- **Apps Script — Script ID:** `1Rk-Cz_t6_dNx7SAp9ZMFJTA-b6wKrgEp-58_XTeL1XE7Xy4BWRyD4Je6`
- **Apps Script — Deployment ID:** `AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA`
- **Proyecto de Google Cloud:** "Maps Platform Demo Project" (`gmp-demo-project-093718520`) — el nombre es engañoso, es el proyecto real que usa la app, no lo confundas con otros proyectos viejos que puedan aparecer en tu cuenta.
- **UUID de la organización "Estilo Neutral":** `67774411-6aa1-4aa3-a4b2-d3fc6913b768`
