import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/documento_identidad.dart';

void main() {
  group('RIF (J/G)', () {
    // RIF públicos reales: Banco de Venezuela y Banesco.
    test('acepta RIF con dígito verificador correcto', () {
      expect(DocumentoIdentidad.validar('J', '000029610'), isNull);
      expect(DocumentoIdentidad.validar('J', '070133805'), isNull);
    });

    test('rechaza dígito verificador incorrecto', () {
      expect(DocumentoIdentidad.validar('J', '070133806'), contains('verificador'));
    });

    test('exige 8 dígitos + verificador', () {
      expect(DocumentoIdentidad.validar('J', '07013380'), contains('8 dígitos'));
    });

    test('normaliza guiones y puntos y formatea con guiones', () {
      final n = DocumentoIdentidad.normalizar('07.013.380-5');
      expect(n, '070133805');
      expect(DocumentoIdentidad.formatear('J', n), 'J-07013380-5');
    });
  });

  test('cédula V/E: 5 a 10 dígitos', () {
    expect(DocumentoIdentidad.validar('V', '12345678'), isNull);
    expect(DocumentoIdentidad.validar('V', '1234'), isNotNull);
    expect(DocumentoIdentidad.validar('E', '12A45678'), isNotNull);
    expect(DocumentoIdentidad.formatear('V', '12345678'), 'V-12345678');
  });

  test('otros tipos (p. ej. pasaporte) aceptan alfanumérico', () {
    expect(DocumentoIdentidad.validar('P', 'AB123456'), isNull);
    expect(DocumentoIdentidad.validar('P', 'AB'), isNotNull);
  });
}
