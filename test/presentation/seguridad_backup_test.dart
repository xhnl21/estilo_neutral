import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/presentation/cubits/seguridad/seguridad_cubit.dart';
import 'package:estilo_neutral/presentation/pages/seguridad_page.dart';
import 'package:estilo_neutral/shared/auth/biometric_auth_service.dart';
import '../test_servidor.dart';

class _FakeBiometricAuthService extends BiometricAuthService {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasFaceId() async => false;
}

void main() {
  group('SeguridadCubit - Respaldos manuales', () {
    test('realizarRespaldoManual exitoso emite estado de carga y mensaje de éxito', () async {
      final (ds, servidor) = await servicioConServidor();
      servidor.respuesta = '{"status":"success","id":"bk123","nombre":"Estilo Neutral · Respaldo 2026-10-09"}';

      final cubit = SeguridadCubit(
        dataService: ds,
        biometricAuthService: _FakeBiometricAuthService(),
      );

      expect(cubit.state.haciendoRespaldo, isFalse);

      final futureRespaldo = cubit.realizarRespaldoManual();
      expect(cubit.state.haciendoRespaldo, isTrue);

      await futureRespaldo;
      expect(cubit.state.haciendoRespaldo, isFalse);
      expect(cubit.state.mensajeRespaldo, contains('Estilo Neutral · Respaldo 2026-10-09'));
      expect(cubit.state.errorRespaldo, isNull);

      await cubit.close();
    });

    test('realizarRespaldoManual con rechazo del servidor emite errorRespaldo', () async {
      final (ds, servidor) = await servicioConServidor();
      servidor.rechazar('Error de permisos en Google Drive');

      final cubit = SeguridadCubit(
        dataService: ds,
        biometricAuthService: _FakeBiometricAuthService(),
      );

      await cubit.realizarRespaldoManual();
      expect(cubit.state.haciendoRespaldo, isFalse);
      expect(cubit.state.mensajeRespaldo, isNull);
      expect(cubit.state.errorRespaldo, contains('Error de permisos en Google Drive'));

      await cubit.close();
    });
  });

  group('SeguridadPage - Widget Test', () {
    testWidgets('renderiza tarjeta de respaldo manual y botón de acción', (tester) async {
      final (ds, _) = await servicioConServidor();

      await tester.pumpWidget(
        MaterialApp(
          home: SeguridadPage(
            dataService: ds,
            biometricAuthService: _FakeBiometricAuthService(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Copias de seguridad (ISO/IEC 27001 §8.13)'), findsOneWidget);
      expect(find.text('Respaldo manual en Drive'), findsOneWidget);
      expect(find.text('Crear respaldo ahora'), findsOneWidget);
    });
  });
}
