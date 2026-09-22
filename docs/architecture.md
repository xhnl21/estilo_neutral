# 🏛️ Guía de Arquitectura, Bounded Contexts y Archivos de Barril

**Proyecto:** Estilo Neutral (Flutter + Google Sheets ORM)  
**Estándares:** Domain-Driven Design (DDD), Clean Architecture (Robert C. Martin), ISO/IEC 25010, ISO 8000  

!!! warning "El contexto `sales/` descrito en este documento fue eliminado"
    Esta guía usaba `lib/features/sales/` (Ventas/Clientes/Facturación) como ejemplo principal de Clean Architecture completa (dominio/aplicación/infraestructura/presentación). Ese módulo **nunca estuvo conectado** a los datos reales — `SalesPage` llamaba a `SheetsDataService` directamente, ignorando toda la capa de dominio — y se eliminó por completo al implementar el esquema de factura con múltiples ítems (ver `docs/manual-tecnico.md` y `docs/casos-de-uso.md` UC-30). Las referencias a `sales/` que quedan abajo son **históricas**: documentan un patrón que existía en el código pero que ya no debe replicarse. Para el patrón real y vigente de cualquier vista nueva (incluida la actual `VentasPage`), ver `docs/manual-tecnico.md` ("página simple + SheetsDataService").

---

## 1. Topología del Proyecto (Feature-First DDD)

El proyecto organiza su código fuente bajo una estructura orientada a **Bounded Contexts (Contextos Delimitados)** dentro de `lib/features/`, combinada con módulos horizontales compartidos:

```
lib/
├── app/                  # Composición de la aplicación, router y DI (ServiceLocator)
│   └── di/injection.dart # Único punto autorizado a instanciar implementaciones de infraestructura
├── config/               # Configuración global y credenciales
├── core/                 # Bloques de construcción DDD y sistema de diseño transversal
│   ├── core.dart         # Barril integrador de tipos, errores y utilidades
│   ├── design_system/    # Tokens (colores, tipografía, espaciado) y Widgets atómicos
│   ├── error/            # Excepciones y fallos de dominio
│   ├── events/           # EventBus en memoria
│   ├── network/          # Cliente HTTP/Dio
│   ├── types/            # AggregateRoot, DomainEvent, Either, Entity, ValueObject
│   ├── usecase/          # Interfaz base UseCase<Type, Params>
│   ├── utils/            # Logger estructurado
│   └── value_objects/    # Value Objects transversales (MoneyUsd, MoneyBs, IsoDate, etc.)
├── features/             # Bounded Contexts (Dominio específico de negocio)
│   ├── treasury/         # Contexto: Compras de Divisas y Tesorería
│   ├── reporting/        # Contexto: Cierre Diario, KPIs y Resumen Financiero
│   └── audit/            # Contexto: Auditoría ISO, Cuarentena e Integridad de Datos
├── models/               # Modelos de serialización de hojas Google Sheets
│   └── models.dart       # Barril unificado de modelos
├── presentation/         # Vistas de navegación global y Shell
│   ├── presentation.dart # Barril global de presentación
│   ├── pages/pages.dart  # Barril de páginas principales (incluye Ventas/Facturas)
│   └── shell/            # MainShell con navegación lateral y drawer
└── shared/               # Infraestructura de conectividad
    ├── shared.dart       # Barril para Google Sheets, Drive y Secure Token Storage
```

> `lib/features/sales/` y `lib/repositories/` (repositorio base ORM legacy, también sin uso real) ya no existen — ver la advertencia arriba.

---

## 2. Política de Archivos de Barril (Barrel Files)

### 2.1. Regla de Encapsulamiento de Infraestructura
- Cada feature expone un archivo barril raíz (ej. `lib/features/treasury/treasury.dart`).
- **PROHIBIDO:** El barril raíz de una feature NUNCA debe re-exportar `infrastructure/infrastructure.dart`.
- Las implementaciones concretas (`*SheetsDataSource`, `*RepositoryImpl`, `*Model`) residen en su propio barril interno y **solo** pueden ser consumidas por el inyector de dependencias (`lib/app/di/injection.dart`).
- La capa de presentación y los casos de uso deben interactuar exclusivamente con contratos del **Dominio** (`CustomerRepository`, `SaleRepository`) o DTOs de **Aplicación**.

### 2.2. Matriz de Barriles Oficiales

| Módulo / Capa | Archivo Barril | Contenido Exportado |
| :--- | :--- | :--- |
| **Core Design System** | `lib/core/design_system/design_system.dart` | Todos los tokens (colores, tipografía, espaciado, iconos, moción), tema y los 11 widgets reutilizables. |
| **Core Types** | `lib/core/types/types.dart` | Primitivas DDD: `AggregateRoot`, `DomainEvent`, `Either`, `Entity`, `ValueObject`. |
| **Core Value Objects** | `lib/core/value_objects/value_objects.dart` | `MoneyUsd`, `MoneyBs`, `ExchangeRate`, `IsoDate`, `EntityId`. |
| **Core Integrador** | `lib/core/core.dart` | Todos los tipos core, value objects, errores, use_case, logger y event_bus. |
| **Shared Services** | `lib/shared/shared.dart` | `SheetsDataService`, `SheetsAuth`, `SheetsClient`, `SecureTokenStorage`, `GoogleDriveHelper`. |
| ~~Feature Sales~~ | ~~`lib/features/sales/sales.dart`~~ | **Eliminado** — ver advertencia al inicio del documento. |
| **Feature Treasury** | `lib/features/treasury/treasury.dart` | Dominio y Presentación de compra de divisas. |
| **Feature Reporting** | `lib/features/reporting/reporting.dart` | Dominio y Presentación de reportes y resumen diario. |
| **Feature Audit** | `lib/features/audit/audit.dart` | Dominio y Presentación de auditoría forense y trazabilidad ISO. |
| **Presentation Pages** | `lib/presentation/pages/pages.dart` | Todas las páginas del menú de navegación. |
| **Models Global** | `lib/models/models.dart` | Modelos de mapeo de hojas de Google Sheets. |

---

## 3. Prevención de Import Bloat en la UI

Las pantallas y componentes de interfaz gráfica deben importar únicamente el barril de diseño correspondiente:

```dart
// ✅ FORMA CORRECTA: 1 sola importación limpia
import '../../core/design_system/design_system.dart';

// ❌ FORMA INCORRECTA (Import Bloat): Más de 10 líneas de imports atómicos
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/icons.dart';
import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/widgets/app_button.dart';
import '../../core/design_system/widgets/app_card.dart';
import '../../core/design_system/widgets/app_chip.dart';
// ...
```

---

## 4. Inyección de Dependencias y Reglas de Dependencia

1. **La UI no instancia dependencias:** Ninguna pantalla debe construir datasources ni repositorios directamente.
2. **Inyección en `MainShell`:** Las páginas reciben sus controladores o servicios a través del constructor provisto por `ServiceLocator` en `injection.dart`.
3. **Cero Polling:** Toda mutación o consulta a Google Sheets se realiza bajo demanda del usuario o por eventos disparados en la interfaz.
