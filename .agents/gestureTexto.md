# Prompt: Implementación Global de Descarte de Teclado (Unfocus On Tap) en Flutter

Actúa como un desarrollador Flutter Senior y arquitecto de software móvil. Necesito implementar una solución global y centralizada para ocultar/descartar el teclado virtual al tocar cualquier área vacía o no interactiva de la pantalla, resolviendo el problema en iOS y Android donde el usuario queda "atrapado" con el teclado abierto.

### Objetivo

Aplicar el descarte de teclado a nivel de toda la aplicación de forma consistente, sin tener que modificar manualmente cada `Scaffold` o vista individual.

---

### Requerimientos Técnicos

1. **Widget Reutilizable (`DismissKeyboard`):**
   - Crear un widget `DismissKeyboard` (StatelessWidget) que envuelva a su propiedad `child`.
   - Utilizar un `GestureDetector` configurado con:
     - `behavior: HitTestBehavior.translucent` (para que los toques fluyan normalmente hacia los botones, campos de texto y scrolls inferiores sin bloquearlos ni interceptarlos indebidamente).
     - `onTap: () => FocusManager.instance.primaryFocus?.unfocus()` (para rescindir el foco globalmente sin depender de la jerarquía de un `BuildContext` específico).
   - Documentar constructores y propiedades para cumplir con las reglas de linter (`public_member_api_docs`).

   **Ejemplo de implementación:**

   ```dart
   import 'package:flutter/material.dart';

   /// Widget wrapper que descarta el teclado virtual al tocar áreas no interactivas.
   class DismissKeyboard extends StatelessWidget {
     /// El widget hijo envuelto por este detector.
     final Widget child;

     /// Crea una instancia de [DismissKeyboard] envolviendo a [child].
     const DismissKeyboard({super.key, required this.child});

     @override
     Widget build(BuildContext context) {
       return GestureDetector(
         behavior: HitTestBehavior.translucent,
         onTap: () {
           FocusManager.instance.primaryFocus?.unfocus();
         },
         child: child,
       );
     }
   }
   ```
