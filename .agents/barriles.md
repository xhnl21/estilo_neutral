# Reestructuración y Estandarización de Archivos Barril (DDD & Clean Architecture) — Estilo Neutral

Este documento contiene el **Informe de Auditoría Inicial** y el **Plan de Trabajo Detallado** para la estandarización de archivos de barril (barrel files), reducción de import bloat y blindaje de las reglas de dependencia en el proyecto **Estilo Neutral** (Flutter + Google Sheets ORM).

> [!NOTE]
> ## Decisiones Arquitectónicas (DDD - Feature-First con Clean Architecture)
>
> Tras evaluar los principios de Domain-Driven Design (DDD), Clean Architecture y la topología actual del repositorio `estilo_neutral` (104 archivos Dart), se definen las siguientes directrices:
>
> 1. **Estructura Feature-First con Capas Limpias:** El proyecto organiza sus contextos delimitados en `lib/features/` (`sales`, `treasury`, `reporting`, `audit`), donde cada feature contiene sus propias capas (`domain`, `application`, `infrastructure`, `presentation`). Los componentes transversales residen en `lib/core`, `lib/shared`, `lib/presentation`, `lib/models` y `lib/app`.
> 2. **Encapsulamiento Estricto por Barril:**
>    - Cada feature expondrá un barril raíz (ej. `lib/features/sales/sales.dart`) que exporta exclusivamente su **Dominio**, **Aplicación** y **Presentación**.
>    - La capa **Infraestructura** (`*SheetsDataSource`, `*RepositoryImpl`, `*Model`) permanece aislada en su propio barril interno (`infrastructure/infrastructure.dart`), consumible únicamente por el inyector de dependencias (`lib/app/di/injection.dart`).
>    - Se erradicará el **Import Bloat** en la UI sustituyendo las 12-16 importaciones directas de tokens y widgets por el barril central del Design System (`design_system.dart`).

---

## 🔍 Informe de Auditoría Inicial (estilo_neutral)

### 1. Estado de los Archivos de Barril
- **Barriles Existentes Parciales:**
  - `lib/core/design_system/design_system.dart`: Existe y exporta tokens, theme y widgets, pero **ninguna** de las pantallas de `lib/presentation/pages/` o de `lib/features/*/presentation/` lo utiliza. Todas importan archivo por archivo.
  - `lib/core/design_system/widgets/widgets.dart`: Existe y agrupa los 11 widgets del sistema de diseño.
  - `lib/models/models.dart`: Existe y exporta los 11 modelos de hojas de cálculo, pero múltiples pantallas continúan importando los archivos individuales (ej. `checklist_iso.dart`, `reporte_migracion.dart`).
- **Barriles Faltantes:**
  - `lib/features/sales/`: No posee ningún archivo barril (ni en `domain`, `application`, `infrastructure`, `presentation` ni en la raíz de la feature).
  - `lib/features/treasury/`: Sin barriles.
  - `lib/features/reporting/`: Sin barriles.
  - `lib/features/audit/`: Sin barriles.
  - `lib/core/`: No posee barriles para `types`, `value_objects`, `error`, etc.
  - `lib/presentation/`: No posee barril para `pages/` ni para la capa de presentación global.

### 2. Deuda de Importaciones e Import Bloat
Se detectó un patrón masivo de **Import Bloat** en todas las vistas de usuario:
- Cada pantalla (`sales_page.dart`, `treasury_page.dart`, `reporting_page.dart`, `audit_page.dart`, `clientes_page.dart`, `inventario_page.dart`, `checklist_iso_page.dart`, `cuarentena_page.dart`, `reporte_migracion_page.dart`) contiene entre **12 y 16 líneas de imports relativos profundos** (`../../../../core/design_system/...`), por ejemplo:
  ```dart
  import '../../../../core/design_system/tokens/colors.dart';
  import '../../../../core/design_system/tokens/icons.dart';
  import '../../../../core/design_system/tokens/spacing.dart';
  import '../../../../core/design_system/tokens/typography.dart';
  import '../../../../core/design_system/widgets/app_button.dart';
  import '../../../../core/design_system/widgets/app_card.dart';
  import '../../../../core/design_system/widgets/app_chip.dart';
  import '../../../../core/design_system/widgets/app_empty_state.dart';
  import '../../../../core/design_system/widgets/app_money_text.dart';
  import '../../../../core/design_system/widgets/app_outlined_button.dart';
  import '../../../../core/design_system/widgets/app_refresh_button.dart';
  import '../../../../core/design_system/widgets/app_scaffold.dart';
  import '../../../../core/design_system/widgets/app_text_field.dart';
  ```
  Esto fragiliza el código ante refactorizaciones y ensucia la legibilidad.

### 3. Salud del Código
- `flutter analyze`: **0 advertencias / 0 errores** (estado limpio).
- `flutter test`: **50/50 pruebas unitarias y de widgets aprobadas**.

---

## 🛠️ Plan de Trabajo Detallado (Propuesta de Ejecución)

### Fase 1: Barriles Nucleares en `lib/core` y `lib/shared`
Crear barriles modulares y un barril integrador:
- `lib/core/types/types.dart`: Exporta `AggregateRoot`, `DomainEvent`, `Either`, `Entity`, `ValueObject`.
- `lib/core/value_objects/value_objects.dart`: Exporta `EntityId`, `ExchangeRate`, `IsoDate`, `MoneyBs`, `MoneyUsd`.
- `lib/core/error/error.dart`: Exporta `exceptions.dart` y `failures.dart`.
- `lib/core/core.dart`: Barril integrador de tipos fundamentales, value objects y utilidades transversales.
- `lib/shared/shared.dart`: Barril para servicios transversales de Google Sheets, Google Drive y Storage.

### Fase 2: Barriles por Bounded Context (`lib/features/*`)
Implementar barriles granulares por capa y el barril público de cada feature:

1. **Feature Sales (`lib/features/sales/`)**:
   - `domain/domain.dart`: Exporta entidades (`Sale`, `Customer`, `Product`, `SaleItem`), repositorios (interfaces), servicios de dominio (`SaleCalculator`, `StockValidator`), eventos y value objects de ventas.
   - `application/application.dart`: Exporta casos de uso (`CreateSaleUseCase`, `RegisterPaymentUseCase`, etc.) y DTOs.
   - `infrastructure/infrastructure.dart`: Exporta `SalesSheetsDataSource`, implementaciones de repositorios y modelos de persistencia (solo para consumo del Service Locator).
   - `presentation/presentation.dart`: Exporta `SalesPage`, `SalesController` y widgets públicos.
   - `sales.dart`: Barril raíz de la feature que exporta `domain/domain.dart`, `application/application.dart` y `presentation/presentation.dart` (**nunca** infrastructure).

2. **Feature Treasury (`lib/features/treasury/`)**:
   - `domain/domain.dart`: Exporta `CurrencyPurchase`, `CurrencyPurchaseRepository`, value objects y eventos.
   - `infrastructure/infrastructure.dart`: Exporta `TreasurySheetsDataSource` y `CurrencyPurchaseRepositoryImpl`.
   - `presentation/presentation.dart`: Exporta `TreasuryPage`.
   - `treasury.dart`: Exporta domain y presentation.

3. **Feature Reporting (`lib/features/reporting/`)**:
   - `domain/domain.dart`, `infrastructure/infrastructure.dart`, `presentation/presentation.dart`, y `reporting.dart`.

4. **Feature Audit (`lib/features/audit/`)**:
   - `domain/domain.dart`, `infrastructure/infrastructure.dart`, `presentation/presentation.dart`, y `audit.dart`.

5. **Presentation Global (`lib/presentation/`)**:
   - `pages/pages.dart`: Exporta todas las pantallas de navegación principal.
   - `presentation.dart`: Exporta `MainShell`, cubits y el barril de páginas.

### Fase 3: Refactorización y Limpieza de Imports
- Reemplazar en todas las pantallas (`lib/presentation/pages/` y `lib/features/*/presentation/pages/`) la cadena de imports individuales de tokens/widgets por el barril `design_system.dart`.
- Reemplazar imports directos a modelos individuales por `package:estilo_neutral/models/models.dart`.
- Actualizar `lib/app/di/injection.dart` y `lib/presentation/shell/main_shell.dart` para consumir los nuevos barriles estandarizados.

### Fase 4: Blindaje Arquitectónico y Documentación
- Documentar en `docs/ARCHITECTURE.md` las reglas de barriles, jerarquía de capas DDD y la política de exportación pública/privada.
- Verificar integridad estática completa con `flutter analyze` y ejecución de la suite de 50 tests con `flutter test`.

---

## ✅ Verification Plan

### Automated Tests & Static Analysis
- `flutter analyze`: Comprobar 0 issues tras la incorporación de barriles y reestructuración de imports.
- `flutter test`: Comprobar que los 50 tests existentes sigan pasando al 100% sin regresiones.
- Script de verificación de dependencias: Validar que ninguna clase de `presentation` importe directamente desde `infrastructure`.

### Manual Verification
- Inspeccionar visualmente `main_shell.dart` y las páginas principales para verificar limpieza y consistencia en los encabezados de imports.
