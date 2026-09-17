import 'dart:async';

/// Utilidad para controlar y retrasar la ejecución de llamadas repetitivas (Debounce).
///
/// Cancela cualquier ejecución pendiente si se solicita una nueva acción antes
/// de que expire el tiempo estipulado en [duration].
class Debouncer {
  /// Duración de espera antes de disparar la acción programada.
  final Duration duration;

  Timer? _timer;

  /// Crea un debouncer con la duración especificada (300 ms por defecto).
  Debouncer({this.duration = const Duration(milliseconds: 300)});

  /// Programa la ejecución de [action] trascurrido [duration].
  /// Si ya había una ejecución pendiente, se cancela y se reinicia el conteo.
  void run(void Function() action) {
    cancel();
    _timer = Timer(duration, action);
  }

  /// Cancela la ejecución pendiente actual si existe.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Libera los recursos del debouncer.
  void dispose() {
    cancel();
  }

  /// Indica si hay un temporizador activo pendiente de disparo.
  bool get isActive => _timer?.isActive ?? false;
}
