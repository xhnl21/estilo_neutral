import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/models/telefono_ve.dart';

void main() {
  group('TelefonoVe.parse', () {
    const casos = {
      '+584124054635': '0412-4054635',
      '584124054635': '0412-4054635',
      '04124054635': '0412-4054635',
      // Sheets convirtió "04124054635" en número y se perdió el 0.
      '4124054635': '0412-4054635',
      '0412-405.46 35': '0412-4054635',
    };
    casos.forEach((raw, esperado) {
      test('"$raw" → $esperado', () {
        expect(TelefonoVe.parse(raw)?.legible, esperado);
      });
    });

    test('rechaza lo que no es un teléfono venezolano de 11 dígitos', () {
      expect(TelefonoVe.parse(''), isNull);
      expect(TelefonoVe.parse('12345'), isNull);
      expect(TelefonoVe.parse('+1 555 123 4567'), isNull);
    });
  });

  test('e164 es el formato que se guarda (texto con "+" en Sheets)', () {
    const tel = TelefonoVe(codigo: '0412', numero: '4054635');
    expect(tel.e164, '+584124054635');
    expect(TelefonoVe.parse(tel.e164)?.local, '04124054635');
  });
}
