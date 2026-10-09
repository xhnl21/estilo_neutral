import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const _prodSpreadsheetId = '1V8xBnRVtZUyz4liGW59BU6mkgCjjreEOEWzySjcZLvI';
const _prodDeploymentId =
    'AKfycby6Jg1oaFa2yJAlEuDThxZhmDvI-LPu80KDedz-qMFn9h1rbvJoTANwG3ufbOYBjDq7ZA';

void main() {
  group('Aislamiento de entornos (QA y Dev no deben apuntar a producción)', () {
    for (final envFileName in ['.env.test', '.env.dev']) {
      test('$envFileName no apunta a la hoja ni al Apps Script de producción', () {
        final file = File(envFileName);
        if (!file.existsSync()) {
          return;
        }

        final content = file.readAsStringSync();

        expect(
          content.contains(_prodSpreadsheetId),
          isFalse,
          reason: '$envFileName contiene el SPREADSHEET_ID de PRODUCCIÓN. '
              'QA y Dev deben usar exclusivamente la hoja de test.',
        );

        expect(
          content.contains(_prodDeploymentId),
          isFalse,
          reason: '$envFileName contiene la APPS_SCRIPT_URL de PRODUCCIÓN. '
              'QA y Dev deben usar exclusivamente la URL de test.',
        );
      });
    }
  });
}
