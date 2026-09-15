import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/config/environment_config.dart';

void main() {
  tearDown(() {
    EnvironmentConfig.setOverrideShowTechnicalInfo(null);
  });

  group('EnvironmentConfig Tests', () {
    test('formatSubtitle hides technical sheet name when showTechnicalInfo is false', () {
      EnvironmentConfig.setOverrideShowTechnicalInfo(false);

      expect(EnvironmentConfig.showTechnicalInfo, isFalse);

      final subtitle = EnvironmentConfig.formatSubtitle(
        sheetName: 'compras_divisas',
        userFriendlyText: '1 operaciones',
      );

      expect(subtitle, equals('1 operaciones'));
      expect(subtitle.contains('compras_divisas'), isFalse);
      expect(subtitle.contains('Hoja'), isFalse);
    });

    test('formatSubtitle shows technical sheet name when showTechnicalInfo is true', () {
      EnvironmentConfig.setOverrideShowTechnicalInfo(true);

      expect(EnvironmentConfig.showTechnicalInfo, isTrue);

      final subtitle = EnvironmentConfig.formatSubtitle(
        sheetName: 'compras_divisas',
        userFriendlyText: '1 operaciones',
      );

      expect(subtitle, equals('Hoja compras_divisas • 1 operaciones'));
      expect(subtitle.contains('compras_divisas'), isTrue);
      expect(subtitle.contains('Hoja'), isTrue);
    });

    test('EnvironmentConfig defaults and environment detection work properly', () {
      EnvironmentConfig.setOverrideShowTechnicalInfo(null);
      // In default test runner without dart-define, environment is 'prod'
      // and showTechnicalInfo is false unless defined or in dev/test/qa
      const isDevOrTest = EnvironmentConfig.environment == 'dev' ||
          EnvironmentConfig.environment == 'test' ||
          EnvironmentConfig.environment == 'qa';

      expect(EnvironmentConfig.showTechnicalInfo, equals(isDevOrTest));
    });
  });
}
