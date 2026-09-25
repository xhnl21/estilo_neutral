import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapta un `Stream` (el `stream` de un `Cubit`/`Bloc`) a un `Listenable`,
/// que es lo que `GoRouter.refreshListenable` requiere. No es parte del
/// paquete `go_router` — es el patrón recomendado en su propia documentación
/// para integrar BLoC/Cubit con las redirecciones de rutas, copiado acá en
/// vez de reimplementarlo cada vez.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
