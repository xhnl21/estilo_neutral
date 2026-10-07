import 'dart:async';

import 'package:estilo_neutral/core/design_system/tokens/typography.dart';
import 'package:google_fonts/google_fonts.dart';

/// Configuración común de todos los tests: sin google_fonts (ni descarga por
/// red ni carga asíncrona de Inter). Los dos hacían fallar al azar los tests
/// de widgets cuando su error llegaba en medio de otro test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  AppTypography.usarFuenteDelSistema = true;
  await testMain();
}
