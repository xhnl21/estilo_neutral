import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Configuración común de todos los tests: google_fonts no descarga fuentes
/// por red (si la descarga fallaba, los tests de widgets fallaban al azar).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
