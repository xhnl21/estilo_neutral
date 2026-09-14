# Sistema de Diseño Visual Minimalista — Estilo Neutral
**Versión:** 1.0 (Fase 12)  
**Estándares:** Material Design 3, Apple Human Interface Guidelines, WCAG 2.2 AA, ISO 9241-110  
**Iconografía:** Cupertino Icons (`cupertino_icons: ^1.0.8`)  
**Política de Refresco:** CERO POLLING (Actualización exclusivamente bajo demanda del usuario)

---

## 1. Filosofía de Diseño
El sistema visual de **Estilo Neutral** se fundamenta en un minimalismo utilitario y sobrio. Cada elemento visual tiene un propósito funcional directo; se eliminan gradientes distractores, animaciones de rebote y decoraciones superfluas. Se privilegian los bordes nítidos y sutiles por encima de las sombras pesadas.

---

## 2. Paleta Cromática Base (Inmutable)

La paleta se rige estrictamente por 5 colores fundamentales:

| Token | Código Hex | Nombre | Rol Principal | Contraste sobre `#FCFFFF` | Nivel WCAG 2.2 |
| :--- | :---: | :--- | :--- | :---: | :---: |
| `blue900` | `#005187` | Azul Profundo | AppBar, títulos de alto énfasis, texto clave | ~8.4:1 | **AAA** (Texto normal) |
| `blue700` | `#4D82BC` | Azul Medio | Acciones primarias, botones, FAB, iconos activos | ~3.8:1 | **AA** (Texto grande/UI) |
| `blue400` | `#84B6F4` | Azul Claro | Estados hover, acentos, iconos de empty state | ~2.1:1 | Decorativo / Superficie |
| `blue100` | `#C4DAFA` | Azul Muy Claro | Contenedores, fondos de chips, indicador nav | — | Superficie Secundaria |
| `surface` | `#FCFFFF` | Blanco Azulado | Fondo principal de pantallas y tarjetas | — | Superficie Pura |

### Neutros Derivados y Semánticos
- `textPrimary`: `#0A1F33` (Contraste ~15.6:1 — **AAA**)
- `textSecondary`: `#4A5A6B` (Contraste ~5.8:1 — **AA**)
- `textDisabled`: `#9AA7B4`
- `border`: `#D6E2F0` (Bordes sutiles)
- `divider`: `#E8F0F9` (Divisores de listas)
- `success`: `#2E7D5B` (Abonos contables, balance en cero — ~5.3:1 **AA**)
- `warning`: `#B26A00` (Saldos por vencer — ~4.8:1 **AA**)
- `error`: `#B3261E` (Deudas pendientes, errores de validación — ~5.7:1 **AA**)

---

## 3. Escala Tipográfica (Inter)

La tipografía utiliza la fuente **Inter** por su alta legibilidad en interfaces digitales y soporte de cifras tabulares:

| Nivel | Tamaño | Peso | Altura de Línea | Uso |
| :--- | :---: | :---: | :---: | :--- |
| `displayLarge` | 32px | w600 | 1.2 | Títulos de impacto |
| `headlineMedium`| 24px | w600 | 1.3 | Encabezados de sección y AppBar |
| `titleLarge` | 18px | w600 | 1.4 | Títulos de tarjeta y diálogos |
| `bodyLarge` | 16px | w400 | 1.5 | Texto principal y campos de texto |
| `bodyMedium` | 14px | w400 | 1.5 | Texto secundario y descripciones |
| `labelSmall` | 12px | w500 | 1.4 | Chips, metadata, etiquetas de nav |

### Cifras Tabulares Financieras
Todas las cantidades monetarias renderizadas mediante `AppMoneyText` aplican:
```dart
fontFeatures: const [FontFeature.tabularFigures()]
```
Esto garantiza que los dígitos numéricos compartan el mismo ancho espacial, previniendo fluctuaciones visuales y desalineación en balances y tablas contables.

---

## 4. Espaciado Modular, Radios y Sombras

### Espaciado (Base 4)
- `xs`: 4px
- `sm`: 8px
- `md`: 12px
- `lg`: 16px
- `xl`: 24px
- `xxl`: 32px

### Radios
- `radiusSm`: 8px (Campos de entrada, botones de diálogo)
- `radiusMd`: 12px (Tarjetas `AppCard`)
- `radiusLg`: 16px (Diálogos modales)
- `radiusPill`: 999px (Botones primarios `AppButton`, `AppChip`)

### Sombras
- **Regla minimalista**: Priorizar el borde sutil `border: #D6E2F0`.
- Máximo 1 sombra sutil por pantalla:
  - `shadowSoft`: `BoxShadow(color: blue900.withValues(alpha: 0.06), blurRadius: 8, offset: (0, 2))`
  - `shadowCard`: `BoxShadow(color: blue900.withValues(alpha: 0.08), blurRadius: 16, offset: (0, 4))`

---

## 5. Catálogo de Iconografía (CupertinoIcons)

Queda estrictamente prohibido el uso de iconos del paquete Material en toda la interfaz. La iconografía es provista unívocamente por `CupertinoIcons`:

- **Navegación:** `house`, `back`, `forward`, `xmark`, `line_horizontal_3`
- **Entidades:** `person` (cliente), `cube_box` (producto), `cart` (venta), `arrow_down_circle` (compra de divisas), `money_dollar` (tesorería), `chart_bar` (tasas)
- **Operaciones:** `add`, `pencil`, `trash`, `checkmark`, `search`, `line_horizontal_3_decrease`, `arrow_clockwise`
- **Auditoría:** `doc_text` (resumen), `shield_lefthalf_fill` (auditoría), `exclamationmark_triangle` (cuarentena), `doc_chart` (reportes), `checkmark_seal` (ISO)
- **Estados:** `checkmark_circle` (éxito), `exclamationmark_circle` (alerta), `xmark_circle` (error), `info_circle` (información)

---

## 6. Componentes Reutilizables

1. `AppScaffold`: Estructura base con AppBar minimalista sin elevación y borde divisor sutil.
2. `AppButton`: Botón píldora en `blue700` con estado de carga integrado y soporte de icono Cupertino.
3. `AppOutlinedButton`: Botón secundario con borde en `blue700`.
4. `AppTextField`: Campo de entrada limpio sin sombras, con estados de foco y validación accesibles.
5. `AppCard`: Contenedor principal con fondo `surface`, borde sutil y padding modular.
6. `AppChip`: Etiqueta de estado en forma de píldora con variantes semánticas (`info`, `success`, `warning`, `error`).
7. `AppEmptyState`: Vista de estado vacío con icono Cupertino de 48px en `blue400`.
8. `AppErrorState`: Vista de error con icono Cupertino y botón de reintento manual.
9. `AppLoadingState`: Indicador de progreso sobrio en `blue700`.
10. `AppRefreshButton`: Control de actualización manual con animación durante la petición (CERO POLLING).
11. `AppMoneyText`: Renderizador tipográfico financiero con prefijos `$` / `Bs.` y cifras tabulares.

---

## 7. Reglas de Oro de Diseño (No Negociables)

1. **Inmutabilidad Cromática**: Los 5 colores de la paleta no admiten tonos no autorizados.
2. **Exclusividad Cupertino**: Cero iconos de Material en toda la aplicación.
3. **Cero Polling**: Todo refresco es iniciado por el usuario mediante botón manual o pull-to-refresh.
4. **Límite de Azules**: Máximo 3 tonos de azul presentes simultáneamente por pantalla.
5. **Límite de Sombras**: Máximo 1 sombra por pantalla.
6. **Accesibilidad WCAG 2.2 AA**: Contraste certificado y tap targets mínimos de 48x48 dp.
7. **Consistencia Modular**: Todo espaciado es múltiplo de 4.

---

## 8. Declaración Explícita de Cumplimiento

> **"Sistema visual minimalista aplicado. CupertinoIcons únicamente. NO polling."**
