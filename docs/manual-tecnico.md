# Manual Técnico

Guía de referencia para desarrolladores que se suman al proyecto. Para arquitectura en profundidad ver [architecture.md](architecture.md), [domain_model.md](domain_model.md) y [context_map.md](context_map.md); para todo lo específico de Google ver [Integraciones con Google](google/index.md).

## Stack

| Capa | Tecnología |
|---|---|
| Framework | Flutter 3.47.x / Dart SDK `>=3.0.0 <4.0.0` |
| Navegación | `go_router` (rutas + `StatefulShellRoute.indexedStack` para las 10 vistas) |
| Estado | En su mayoría `ChangeNotifier` (`SheetsDataService`) + `ListenableBuilder`; algunas features nuevas (`sales`, `search`) usan `flutter_bloc` |
| Backend de datos | Google Sheets, sin servidor propio (ver más abajo) |
| Autenticación | `google_sign_in` (OAuth Android nativo) |
| Almacenamiento seguro | `flutter_secure_storage` (Keychain / EncryptedSharedPreferences) |
| Video | `video_player` (splash de introducción) |

## Cómo se leen y escriben los datos (el "ORM")

No hay backend propio ni base de datos real — Google Sheets **es** la base de datos:

- **Lectura:** `SheetsDataService` (`lib/shared/google_sheets/sheets_data_service.dart`) hace `fetchAllSheets()`, que dispara un `GET` por cada una de las 10 hojas contra el endpoint público de exportación CSV de Google Sheets (`.../gviz/tq?tqx=out:csv&sheet=<nombre>`). No requiere autenticación — la hoja debe estar compartida como "Cualquier persona con el enlace". Cada hoja tiene un parser dedicado (`_parseClientes`, `_parseProductos`, etc.) que mapea filas CSV a modelos Dart.
- **Escritura:** las mutaciones (`addCliente`, `addProducto`, `toggleChecklistEstado`, `toggleBiometrico`, etc.) actualizan primero la lista en memoria (para que la UI reaccione al instante) y, para algunas, además hacen un `POST` a **Google Apps Script** (`_postToAppsScript`, ver [Apps Script](google/apps-script.md)), que es el único componente con permiso real de escritura sobre el Sheet.
- **Sin polling:** ninguna pantalla refresca sola — ver [Política de Cero Polling](no_polling_policy.md).
- **Multi-organización:** todos los getters de listas filtran por la organización del usuario logueado — ver [Multi-organización](google/multi-organizacion.md).

## Estructura del proyecto (`lib/`)

```
lib/
├── app/di/              # ServiceLocator: arma e inyecta todas las dependencias (composition root)
├── config/               # AuthConfig (no usado actualmente, ver nota abajo)
├── core/
│   ├── config/           # EnvironmentConfig, AccessControlConfig
│   ├── design_system/    # Tokens (colores, tipografía, spacing) y widgets base (AppButton, AppCard, ...)
│   ├── router/            # go_router: AppRouter, RoutePaths, RouteNames, guards (auth, onboarding)
│   └── utils/             # Logger (con sanitización de PII)
├── features/
│   ├── auth/              # AuthNotifier, AuthState, LoginPage, OnboardingPage
│   ├── audit/              # Rutas de "Gobierno y Calidad ISO" (cuarentena, audit_log, reporte_migracion, checklist_iso, seguridad)
│   ├── sales/              # Único módulo con Clean Architecture completa (domain/infra/presentation) — demo, no conectado a Sheets real
│   ├── treasury/, reporting/, search/
├── models/                 # Los "DTOs": Cliente, Producto, Venta, ..., Seguridad, Usuario (fromRow/toMap)
├── presentation/
│   ├── pages/               # Las páginas simples de las 9+1 vistas (StatefulWidget + SheetsDataService)
│   ├── screens/splash/     # Video de introducción
│   └── shell/                # MainShell: drawer + bottom nav + IndexedStack de las 10 vistas
└── shared/
    └── google_sheets/       # SheetsDataService, SheetsAuth, SheetsClient, SheetsConfig
```

!!! note "Por qué la mayoría de las vistas no tienen Cubit/Repository"
    Las 9 vistas de negocio (Clientes, Inventario, Ventas, Compras Divisas, Resumen Diario, Cuarentena, Audit Log, Reporte Migración, Checklist ISO) y Seguridad son `StatefulWidget`/`StatelessWidget` planos que consumen `SheetsDataService` directamente vía `ListenableBuilder` — **no** usan Cubit ni Repository. El único módulo con Clean Architecture completa (`lib/features/sales`) es una demo interna con datos en memoria, no está conectado al Google Sheet real. Si vas a agregar una vista nueva, replicá el patrón "página simple + SheetsDataService", no el de `sales/`.

## Variables de entorno (`.env*`)

| Archivo | Uso |
|---|---|
| `.env` | prod (default) |
| `.env.dev` | flavor `dev` |
| `.env.test` | flavor `qa` |
| `.env.example` | plantilla, sin datos reales |

Variables clave: `SPREADSHEET_ID`, `APPS_SCRIPT_URL`, `ALLOWED_EMAILS`, `ENVIRONMENT`, `SHOW_TECHNICAL_INFO`, `DEBUG_MODE`/`ENABLE_LOGS`.

Se inyectan con `--dart-define-from-file`:

```bash
flutter run --flavor dev --dart-define-from-file=.env.dev
```

## Flavors

`dev` / `qa` / `prod`, definidos en `android/app/build.gradle.kts`. Cambian `applicationId` (sufijo `.dev`/`.qa` para no-prod) — cada combinación flavor+build type necesita su propia credencial de Google Sign-In (ver [Google Sign-In](google/sign-in.md)).

```bash
flutter run --flavor qa --dart-define-from-file=.env.test
flutter build apk --flavor prod --release --dart-define-from-file=.env
```

## Firma de release

Keystore en `android/app/upload-keystore.jks` (config en `android/key.properties`, gitignoreado). Ver [Google Sign-In → sacar el SHA-1](google/sign-in.md#sacar-el-sha-1-de-un-keystore).

## Testing

```bash
flutter analyze lib/ test/
flutter test
```

151 tests a la fecha de este documento (widgets, cubits, routing, config). `test/test_live_fetch.dart` es un test de integración manual contra una hoja externa vieja — no forma parte del suite estándar (su nombre no termina en `_test.dart`, así que `flutter test` no lo descubre automáticamente) y hoy está roto; no es necesario arreglarlo para el CI normal.

## Puntos de extensión comunes

- **Agregar una hoja/vista nueva:** modelo en `lib/models/` (`fromRow`/`toMap`) → registrar el fetch/parser en `SheetsDataService` → página en `lib/presentation/pages/` → ruta en `route_paths.dart`/`route_names.dart`/una `*Routes` existente → rama nueva en `AppRouter` (`StatefulShellBranch`) → entrada en `MainShell` (`_vistasInfo`, `_pages`, drawer). Si la hoja es multi-organización, agregar la columna `organizacion_id` y filtrar el getter (ver [Multi-organización](google/multi-organizacion.md)).
- **Agregar una acción de escritura real (Apps Script):** agregar el `case` correspondiente en `google_apps_script.js`, y desplegar con `tools/apps_script` (ver [Automatización](google/automatizacion.md)).
- **Agregar un usuario autorizado:** editar `ALLOWED_EMAILS` en el `.env` correspondiente, y agregar la fila en la hoja `usuarios` del Sheet real (con su `organizacion_id`).
