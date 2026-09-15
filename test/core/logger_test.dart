import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/utils/logger.dart';

void main() {
  group('Logger Sanitization Tests', () {
    test('Sanitiza correos electrónicos correctamente', () {
      const input = 'El usuario juan.perez@empresa.com inició sesión con admin@test.org';
      final sanitized = Logger.sanitize(input);

      expect(sanitized, contains('ju***@empresa.com'));
      expect(sanitized, contains('ad***@test.org'));
      expect(sanitized.contains('juan.perez@empresa.com'), isFalse);
    });

    test('Sanitiza tokens JWT completos', () {
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      const input = 'Authorization: Bearer $jwt recibido';
      final sanitized = Logger.sanitize(input);

      expect(sanitized, contains('Bearer eyJ***.***.***'));
      expect(sanitized.contains(jwt), isFalse);
    });

    test('Sanitiza campos sensibles en formato JSON o clave: valor', () {
      const input = '{"username": "carlos", "password": "SuperSecret123!", "pin": 1234, "token": "abcde"}';
      final sanitized = Logger.sanitize(input);

      expect(sanitized, contains('"username": "carlos"'));
      expect(sanitized, contains('"password": "***"'));
      expect(sanitized, contains('"pin": "***"'));
      expect(sanitized, contains('"token": "***"'));
      expect(sanitized.contains('SuperSecret123!'), isFalse);
      expect(sanitized.contains('1234'), isFalse);
    });
  });

  group('Logger Environment & Configuration Tests', () {
    tearDown(() {
      Logger.initialize(enableLogs: null, showStackTrace: null);
    });

    test('Respeta inicialización explícita para habilitar/deshabilitar', () {
      Logger.initialize(enableLogs: false);
      expect(Logger.isLoggingEnabled, isFalse);

      Logger.initialize(enableLogs: true);
      expect(Logger.isLoggingEnabled, isTrue);
    });

    test('Métodos estáticos se ejecutan sin arrojar excepciones', () {
      Logger.initialize(enableLogs: true, showStackTrace: true);

      expect(() => Logger.debug('Mensaje debug con secret="1234"'), returnsNormally);
      expect(() => Logger.info('Mensaje info con email test@demo.com'), returnsNormally);
      expect(() => Logger.warning('Mensaje advertencia'), returnsNormally);
      expect(() => Logger.error('Fallo en cálculo', Exception('Error fatal'), StackTrace.current), returnsNormally);
      expect(() => Logger.success('Operación exitosa'), returnsNormally);
      expect(() => Logger.api('GET /api/v1/clientes', isRequest: true), returnsNormally);
      expect(() => Logger.api('200 OK', isRequest: false), returnsNormally);
      expect(() => Logger.object('Payload', {'clave': 'valor', 'password': '123'}), returnsNormally);
    });
  });
}
