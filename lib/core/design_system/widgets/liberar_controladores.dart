import 'package:flutter/widgets.dart';

/// Libera [controladores] cuando este widget se desmonta.
///
/// Para modales que crean sus `TextEditingController` en la función que los
/// abre: liberarlos al completarse el `Future` del modal falla, porque la
/// animación de cierre todavía los usa. Envolviendo el contenido del modal,
/// se liberan recién cuando el modal termina de cerrarse.
class LiberarControladores extends StatefulWidget {
  final List<ChangeNotifier> controladores;
  final Widget child;

  const LiberarControladores({super.key, required this.controladores, required this.child});

  @override
  State<LiberarControladores> createState() => _LiberarControladoresState();
}

class _LiberarControladoresState extends State<LiberarControladores> {
  @override
  void dispose() {
    for (final c in widget.controladores) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
