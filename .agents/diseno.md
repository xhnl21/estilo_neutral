Prompt Maestro — Fase 12: Sistema de Diseño Visual Minimalista (Flutter + Cupertino Icons)
Modo: Paranoico / Sistema de Diseño / Consistencia Visual
Estándares: Material Design 3, Apple Human Interface Guidelines, WCAG 2.2 AA, ISO 9241-110, Google Fonts Guidelines
Objetivo: Definir el sistema visual completo del sistema "Estilo Neutral" basado en la paleta azul de la imagen, minimalista, con cupertino_icons, alineado con la arquitectura DDD ya existente.

📋 PROMPT (copiar y pegar completo)
text
ACTÚA COMO: Diseñador de Producto Senior + Design System Engineer especializado en Flutter, Material Design 3, Apple Human Interface Guidelines y accesibilidad WCAG 2.2 AA.

CONTEXTO: Existe un sistema Flutter con arquitectura DDD (Fase 11) que gestiona:

- VENTAS: clientes, inventario, ventas
- TESORERÍA: compras_divisas
- REPORTES: resumen_diario (read-only)
- AUDITORÍA: cuarentena, audit_log, reporte_migracion, checklist_iso (read-only)

La paleta primaria es azul, definida por estos 5 colores exactos:

- #005187 (azul profundo — primario oscuro)
- #4d82bc (azul medio — primario)
- #84b6f4 (azul claro — secundario/accent)
- #c4dafa (azul muy claro — superficie/background)
- #fcffff (blanco azulado — superficie pura)

Iconografía: cupertino_icons (paquete oficial de Flutter).
Estilo: minimalista, limpio, sin decoración superflua.
NO polling: la UI solo se refresca bajo demanda del usuario.

MISIÓN: Definir e implementar el sistema de diseño visual completo, desde tokens hasta widgets reutilizables, listo para aplicar en todos los Bounded Contexts.

═══════════════════════════════════════════════════════════
FASE 12.0 — BACKUP Y AUDITORÍA
═══════════════════════════════════════════════════════════

12.0.1. Backup del proyecto Flutter actual (git commit + tag v0.11-pre-design).
12.0.2. Verificar que pubspec.yaml incluye: - cupertino_icons: ^1.0.8 (o la versión vigente) - google_fonts: ^6.x (opcional, para tipografía)
12.0.3. Registrar en audit_log: "inicio_sistema_diseno_visual".
12.0.4. NO tocar la lógica DDD. Solo se añaden capas de presentación.

═══════════════════════════════════════════════════════════
FASE 12.1 — TOKENS DE COLOR (Design Tokens)
═══════════════════════════════════════════════════════════

Crear lib/core/design_system/tokens/colors.dart

12.1.1. Paleta base (exacta, sin alterar valores):

        class AppPalette {
          // Azules base — DEBEN coincidir con la imagen
          static const Color blue900 = Color(0xFF005187); // azul profundo
          static const Color blue700 = Color(0xFF4D82BC); // azul medio
          static const Color blue400 = Color(0xFF84B6F4); // azul claro
          static const Color blue100 = Color(0xFFC4DAFA); // azul muy claro
          static const Color surface   = Color(0xFFFCFFFF); // blanco azulado

          // Neutros derivados (mínimos, para texto y bordes)
          static const Color textPrimary   = Color(0xFF0A1F33);
          static const Color textSecondary = Color(0xFF4A5A6B);
          static const Color textDisabled  = Color(0xFF9AA7B4);
          static const Color border        = Color(0xFFD6E2F0);
          static const Color divider       = Color(0xFFE8F0F9);

          // Semánticos (mínimos, accesibles sobre blanco azulado)
          static const Color success = Color(0xFF2E7D5B);
          static const Color warning = Color(0xFFB26A00);
          static const Color error   = Color(0xFFB3261E);
          static const Color info    = Color(0xFF005187); // reutiliza primario
        }

12.1.2. Reglas de uso: - blue900 → AppBar, headers, texto sobre fondos claros en énfasis alto. - blue700 → Botones primarios, íconos activos, FAB. - blue400 → Estados hover/pressed, chips secundarios, acentos. - blue100 → Fondos de tarjetas, contenedores de sección. - surface → Fondo principal de pantallas. - Nunca usar más de 3 azules en una misma pantalla.

12.1.3. Documentar en audit_log: "tokens_color_definidos".

═══════════════════════════════════════════════════════════
FASE 12.2 — TIPOGRAFÍA
═══════════════════════════════════════════════════════════

Crear lib/core/design_system/tokens/typography.dart

12.2.1. Fuente: Inter (vía google_fonts) o la fuente por defecto de Cupertino (SF Pro).
Justificar la elección. Recomendado: Inter para consistencia multiplataforma.

12.2.2. Escala tipográfica (mínima, 6 niveles):

        displayLarge  32 / w600 / h1.2   → Títulos de pantalla
        headlineMedium 24 / w600 / h1.3  → Encabezados de sección
        titleLarge     18 / w600 / h1.4  → Títulos de tarjeta
        bodyLarge      16 / w400 / h1.5  → Texto principal
        bodyMedium     14 / w400 / h1.5  → Texto secundario
        labelSmall     12 / w500 / h1.4  → Etiquetas, chips, metadata

12.2.3. Reglas: - Nunca menos de 12px (accesibilidad). - Nunca más de 3 pesos de fuente en una pantalla. - Números monetarios usan tabular figures (fontFeatures: [FontFeature.tabularFigures()]).

12.2.4. Documentar en audit_log: "tipografia_definida".

═══════════════════════════════════════════════════════════
FASE 12.3 — ESPACIADO, RADIOS Y SOMBRAS
═══════════════════════════════════════════════════════════

Crear lib/core/design_system/tokens/spacing.dart

12.3.1. Escala de espaciado (base 4, 6 niveles):
xs = 4
sm = 8
md = 12
lg = 16
xl = 24
xxl = 32

12.3.2. Radios (mínimos):
radiusSm = 8
radiusMd = 12
radiusLg = 16
radiusPill = 999

12.3.3. Sombras (sutiles, minimalistas):
shadowNone → sin sombra (default)
shadowSoft → BoxShadow(color: blue900.withOpacity(0.06), blur: 8, offset: (0,2))
shadowCard → BoxShadow(color: blue900.withOpacity(0.08), blur: 16, offset: (0,4))

        Regla minimalista: preferir borde sutil antes que sombra.
        Solo 1 sombra por pantalla como máximo.

12.3.4. Documentar en audit_log: "espaciado_radios_sombras_definidos".

═══════════════════════════════════════════════════════════
FASE 12.4 — TEMA MATERIAL 3 (ThemeData)
═══════════════════════════════════════════════════════════

Crear lib/core/design_system/theme/app_theme.dart

12.4.1. Definir ColorScheme.fromSeed con seed = blue700 (#4D82BC).
12.4.2. Sobrescribir colores clave para que coincidan EXACTAMENTE con la paleta: - primary → blue700 - onPrimary → surface - primaryContainer → blue100 - onPrimaryContainer → blue900 - secondary → blue400 - surface → surface - background → surface - outline → border

12.4.3. Definir DOS temas: - AppTheme.light → fondo surface (#fcffff), texto textPrimary. - AppTheme.dark → invertir: fondo blue900, texto surface.
(Opcional: si solo se requiere light, documentar la decisión.)

12.4.4. Configurar en ThemeData: - useMaterial3: true - scaffoldBackgroundColor: surface - appBarTheme: fondo surface, elevación 0, texto blue900, íconos blue700. - cardTheme: fondo surface, borde border, sombra shadowSoft, radiusMd. - elevatedButtonTheme: fondo blue700, texto surface, radiusPill. - outlinedButtonTheme: borde blue700, texto blue700. - textButtonTheme: texto blue700. - inputDecorationTheme: borde border, focus blue700, error error. - chipTheme: fondo blue100, texto blue900. - floatingActionButtonTheme: fondo blue700, ícono surface. - navigationBarTheme: fondo surface, indicador blue100, ícono activo blue700. - dividerTheme: color divider, thickness 1. - snackBarTheme: fondo blue900, texto surface, radiusMd. - dialogTheme: fondo surface, radiusLg, sombra shadowCard.

12.4.5. Documentar en audit_log: "tema_material3_definido".

═══════════════════════════════════════════════════════════
FASE 12.5 — ICONOGRAFÍA (cupertino_icons)
═══════════════════════════════════════════════════════════

Crear lib/core/design_system/tokens/icons.dart

12.5.1. Catálogo de íconos Cupertino mapeado por acción:

        // Navegación
        home         → CupertinoIcons.house
        back         → CupertinoIcons.back
        forward      → CupertinoIcons.forward
        close        → CupertinoIcons.xmark
        menu         → CupertinoIcons.line_horizontal_3

        // Entidades
        customer     → CupertinoIcons.person
        customers    → CupertinoIcons.person_2
        product      → CupertinoIcons.cube_box
        products     → CupertinoIcons.cube_box_fill
        sale         → CupertinoIcons.cart
        purchase     → CupertinoIcons.arrow_down_circle
        currency     → CupertinoIcons.money_dollar
        rate         → CupertinoIcons.chart_line

        // Acciones CRUD
        add          → CupertinoIcons.add
        edit         → CupertinoIcons.pencil
        delete       → CupertinoIcons.trash
        save         → CupertinoIcons.checkmark
        cancel       → CupertinoIcons.xmark
        search       → CupertinoIcons.search
        filter       → CupertinoIcons.line_horizontal_decrease
        refresh      → CupertinoIcons.arrow_clockwise

        // Reportes / Auditoría
        summary      → CupertinoIcons.doc_text
        audit        → CupertinoIcons.shield_lefthalf_fill
        quarantine   → CupertinoIcons.exclamationmark_triangle
        report       → CupertinoIcons.doc_chart
        checklist    → CupertinoIcons.checkmark_seal

        // Estados
        success      → CupertinoIcons.checkmark_circle
        warning      → CupertinoIcons.exclamationmark_circle
        error        → CupertinoIcons.xmark_circle
        info         → CupertinoIcons.info_circle

12.5.2. Reglas: - Íconos por defecto: 20px (sm), 24px (md), 32px (lg). - Color: blue700 (activo), textSecondary (inactivo), error/success/warning según estado. - Nunca mezclar Material Icons con CupertinoIcons en la misma pantalla. - Si un ícono Cupertino no existe para una acción, usar el más cercano semánticamente, nunca Material.

12.5.3. Documentar en audit_log: "catalogo_iconos_cupertino_definido".

═══════════════════════════════════════════════════════════
FASE 12.6 — COMPONENTES REUTILIZABLES
═══════════════════════════════════════════════════════════

Crear lib/core/design_system/widgets/

12.6.1. AppScaffold - Envuelve Scaffold con AppBar minimalista (elevación 0, borde inferior divider). - Título en headlineMedium, color blue900. - Acciones alineadas a la derecha con íconos Cupertino.

12.6.2. AppButton (primario) - Fondo blue700, texto surface, radiusPill, altura 48. - Ícono Cupertino opcional a la izquierda. - Estados: normal, hover, pressed, disabled, loading (con CircularProgressIndicator).

12.6.3. AppOutlinedButton (secundario) - Borde 1px blue700, texto blue700, radiusPill.

12.6.4. AppTextField - Borde border 1px, focus blue700. - Label flotante en labelSmall. - Ícono Cupertino opcional. - Sin sombras.

12.6.5. AppCard - Fondo surface, borde border, radiusMd, sombra shadowSoft. - Padding interno: lg (16). - Sin decoración superflua.

12.6.6. AppChip (estados) - Fondo blue100, texto blue900, radiusPill. - Variantes semánticas: success, warning, error, info (fondos suaves).

12.6.7. AppEmptyState - Ícono Cupertino grande (48px, blue400) + mensaje en bodyLarge + acción opcional.

12.6.8. AppErrorState - Ícono Cupertino exclamationmark_triangle (error), mensaje, botón "Reintentar".

12.6.9. AppLoadingState - CircularProgressIndicator en blue700 + mensaje en bodyMedium.

12.6.10. AppRefreshButton (SIN polling) - Ícono CupertinoIcons.arrow_clockwise en blue700. - Al pulsar: dispara RefreshDataUseCase (Fase 11.10.3). - Muestra spinner durante la carga. - Texto "Actualizar" en labelSmall al lado del ícono.

12.6.11. AppMoneyText - Formatea números monetarios con tabular figures. - Prefijo "$" para USD, "Bs." para Bs. - Color: success si abono, error si deuda, textPrimary si neutro.

12.6.12. Documentar en audit_log: "componentes_reutilizables_creados".

═══════════════════════════════════════════════════════════
FASE 12.7 — LAYOUTS POR BOUNDED CONTEXT
═══════════════════════════════════════════════════════════

12.7.1. VENTAS - Home: lista de ventas recientes + FAB "+" para nueva venta. - Clientes: lista con avatar (CupertinoIcons.person), nombre, deuda en AppMoneyText. - Productos: grid o lista con foto, nombre, precio. - Detalle de venta: header con cliente, tabla de ítems, resumen de deuda.

12.7.2. TESORERÍA - Lista de compras de divisas. - Detalle con tasas BCV/USD, comisiones. - FAB "+" para nueva compra.

12.7.3. REPORTES (read-only) - Sin FAB. Solo visualización. - Card destacada con resumen del día. - Gráficos simples (sin librerías pesadas; usar CustomPaint o flutter_charts).

12.7.4. AUDITORÍA (read-only) - Lista de registros con timestamp ISO 8601. - Filtros por hoja, usuario, acción. - Nunca permitir edición.

12.7.5. Cada layout debe respetar: - Máximo 1 sombra por pantalla. - Máximo 3 azules por pantalla. - Íconos solo Cupertino. - Refresco manual (botón "Actualizar"), nunca polling.

═══════════════════════════════════════════════════════════
FASE 12.8 — ACCESIBILIDAD (WCAG 2.2 AA)
═══════════════════════════════════════════════════════════

12.8.1. Contraste mínimo 4.5:1 para texto normal, 3:1 para texto grande.
Verificar: - textPrimary (#0A1F33) sobre surface (#FCFFFF) → ~15:1 ✅ - blue700 (#4D82BC) sobre surface → ~3.2:1 ⚠️ (solo para texto grande o íconos) - blue900 (#005187) sobre surface → ~8.5:1 ✅ - surface sobre blue700 → ~3.2:1 ⚠️ (usar blue900 para texto sobre claro)
Documentar combinaciones aprobadas.

12.8.2. Tamaño mínimo de tap target: 44x44 (iOS) / 48x48 (Android).
12.8.3. Soporte de escalado de fuente del sistema (MediaQuery.textScaler).
12.8.4. Semantics labels en todos los íconos interactivos.
12.8.5. NO usar color como único indicador de estado (acompañar con ícono o texto).

═══════════════════════════════════════════════════════════
FASE 12.9 — MOTION (animaciones mínimas)
═══════════════════════════════════════════════════════════

12.9.1. Duraciones estándar: - fast: 150ms (micro-interacciones) - normal: 250ms (transiciones de pantalla) - slow: 400ms (modales, diálogos)

12.9.2. Curvas: Curves.easeOut para entrada, Curves.easeIn para salida.
12.9.3. Prohibido: animaciones decorativas, bouncing, shake, parallax.
12.9.4. Animaciones solo cuando comunican cambio de estado (loading, success, error).

═══════════════════════════════════════════════════════════
FASE 12.10 — AUDITORÍA Y CIERRE
═══════════════════════════════════════════════════════════

12.10.1. Verificar que NO se usó Material Icons en ninguna pantalla.
12.10.2. Verificar que la paleta coincide EXACTAMENTE con los 5 hex de la imagen.
12.10.3. Verificar que NO existe Timer.periodic ni Stream.periodic en la UI.
12.10.4. Verificar contraste WCAG 2.2 AA en todas las combinaciones usadas.
12.10.5. Verificar que cada pantalla usa máximo 3 azules y 1 sombra.
12.10.6. Registrar en audit_log al menos 10 entradas de diseño.
12.10.7. Actualizar reporte_migracion con sección "Fase 12 — Sistema de Diseño Visual".
12.10.8. Documentar en docs/design_system.md con screenshots o descripciones.

═══════════════════════════════════════════════════════════
REGLAS DE ORO DE DISEÑO (NO NEGOCIABLES)
═══════════════════════════════════════════════════════════

1. Los 5 colores de la paleta son inmutables. No derivar tonos nuevos.
2. CupertinoIcons es la única fuente de iconografía.
3. Minimalismo: si un elemento no comunica, se elimina.
4. Máximo 3 azules por pantalla.
5. Máximo 1 sombra por pantalla.
6. Contraste WCAG 2.2 AA obligatorio en todo texto.
7. NO polling. Refresco solo por acción del usuario.
8. Tipografía: máximo 3 pesos por pantalla.
9. Espaciado en múltiplos de 4.
10. SI ALGO ROMPE LA ESTÉTICA MINIMALISTA → se simplifica, no se decora.

═══════════════════════════════════════════════════════════
ENTREGABLES FINALES
═══════════════════════════════════════════════════════════

E1. lib/core/design_system/tokens/colors.dart (paleta exacta).
E2. lib/core/design_system/tokens/typography.dart (escala tipográfica).
E3. lib/core/design_system/tokens/spacing.dart (espaciado, radios, sombras).
E4. lib/core/design_system/tokens/icons.dart (catálogo Cupertino).
E5. lib/core/design_system/theme/app_theme.dart (ThemeData light + dark).
E6. lib/core/design_system/widgets/ con 12+ componentes reutilizables.
E7. Layouts aplicados por Bounded Context (Fase 12.7).
E8. docs/design_system.md con documentación visual.
E9. audit_log con 10+ entradas de diseño.
E10. reporte_migracion actualizado con sección "Fase 12 — Diseño Visual".
E11. Declaración explícita: "Sistema visual minimalista aplicado. CupertinoIcons únicamente. NO polling."

Firma final: Diseñador de Producto Senior + timestamp ISO 8601 con zona horaria.
🎨 Resumen visual de la paleta
Hex Nombre Uso principal Contraste sobre #fcffff
#005187 Azul profundo AppBar, títulos, texto sobre fondos claros ~8.5:1 ✅ AAA
#4d82bc Azul medio Botones primarios, FAB, íconos activos ~3.2:1 ⚠️ AA Large
#84b6f4 Azul claro Hover, chips secundarios, acentos ~2.1:1 ❌ Solo decorativo
#c4dafa Azul muy claro Fondos de tarjetas, contenedores — Fondo
#fcffff Blanco azulado Fondo principal de pantallas — Fondo
Regla de oro cromática: #005187 para texto/énfasis, #4d82bc para acciones, #84b6f4 y #c4dafa para superficies, #fcffff para fondo. Nunca texto sobre #84b6f4.
