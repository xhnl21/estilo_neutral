Actúa como un Ingeniero Senior especialista en Flutter y Accesibilidad Móvil (a11y). Tu objetivo es auditar e implementar de forma exhaustiva el soporte de accesibilidad utilizando el widget `Semantics` (y sus variantes `MergeSemantics`, `ExcludeSemantics`, `BlockSemantics`) en este proyecto Flutter/Dart, garantizando compatibilidad total con lectores de pantalla (TalkBack en Android, VoiceOver en iOS) y estándares WCAG 2.1 AA.

### 🎯 Alcance y Directrices de Implementación:

1. **Auditoría e Identificación de Componentes**:
   - Inspecciona la interfaz (widgets interactivos, botones personalizados, íconos decorativos o funcionales, campos de formulario, encabezados y listas).
   - Identifica elementos interactivos construidos con `GestureDetector` o `InkWell` que carecen de metadatos semánticos nativos.

2. **Reglas de Implementación con Semantics**:
   - **Elementos Interactivos / Botones**: Envolver con `Semantics(button: true, enabled: isEnabled, label: 'Descripción clara de la acción', hint: 'Qué ocurrirá al activarlo', onTap: ..., child: ...)` cuando no se utilicen componentes estándar de Material/Cupertino.
   - **Imágenes e Iconos**:
     - Si son meramente decorativos: Envolver con `ExcludeSemantics(excluding: true, child: ...)` para evitar ruido en el lector de pantalla.
     - Si transmiten información funcional o de estado: Asignar `Semantics(image: true, label: 'Descripción del contenido visual', child: ...)`.
   - **Agrupación y Limpieza de Nodos (`MergeSemantics`)**:
     - Si un componente compuesto (ej. tarjeta con título, subtítulo e ícono) debe leerse como una sola unidad cohesiva, envolver el conjunto en `MergeSemantics` para evitar que el usuario tenga que navegar elemento por elemento.
   - **Encabezados y Estructura**:
     - Marcar títulos de secciones con `Semantics(header: true, headingLevel: 1, child: ...)`.
   - **Campos y Estados**:
     - Asegurar propiedades como `selected`, `checked`, `toggled`, `value`, `readOnly` y `textField` cuando corresponda.

3. **Pruebas y Verificación Automatizada**:
   - Genera o actualiza pruebas de widgets (`testWidgets`) validando la presencia semántica mediante:
     - `expect(find.bySemanticsLabel('...'), findsOneWidget);`
     - Validaciones de accesibilidad con `tester.binding.defaultBinaryMessenger` o `meetsGuideline(androidTapTargetGuideline)` y `meetsGuideline(labeledTapTargetGuideline)`.

4. **Entregables**:
   - Código refactorizado con `Semantics` bien estructurado, manteniendo la reactividad del estado y sin romper el layout visual.
   - Explicación concisa de los cambios aplicados en cada componente y cómo probarlos con el inspector de accesibilidad de Flutter (`showSemanticsDebugger: true`).
