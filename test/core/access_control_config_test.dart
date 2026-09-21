import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/config/access_control_config.dart';

void main() {
  tearDown(() {
    AccessControlConfig.setOverrideAllowedEmails(null);
  });

  group('AccessControlConfig', () {
    test('allows an email present in the allowlist', () {
      AccessControlConfig.setOverrideAllowedEmails(['user@gmail.com']);

      expect(AccessControlConfig.isEmailAllowed('user@gmail.com'), isTrue);
    });

    test('rejects an email absent from the allowlist', () {
      AccessControlConfig.setOverrideAllowedEmails(['user@gmail.com']);

      expect(AccessControlConfig.isEmailAllowed('intruso@gmail.com'), isFalse);
    });

    test('comparison is case-insensitive and trims whitespace', () {
      AccessControlConfig.setOverrideAllowedEmails(['User@Gmail.com']);

      expect(AccessControlConfig.isEmailAllowed('  user@gmail.com  '), isTrue);
      expect(AccessControlConfig.isEmailAllowed('USER@GMAIL.COM'), isTrue);
    });

    test('rejects null or empty email', () {
      AccessControlConfig.setOverrideAllowedEmails(['user@gmail.com']);

      expect(AccessControlConfig.isEmailAllowed(null), isFalse);
      expect(AccessControlConfig.isEmailAllowed(''), isFalse);
      expect(AccessControlConfig.isEmailAllowed('   '), isFalse);
    });

    test('default allowlist includes the configured team emails', () {
      expect(
        AccessControlConfig.isEmailAllowed('neidapulgar1989@gmail.com'),
        isTrue,
      );
      expect(AccessControlConfig.isEmailAllowed('xhnl21@gmail.com'), isTrue);
      expect(AccessControlConfig.isEmailAllowed('random@gmail.com'), isFalse);
    });
  });
}
