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
