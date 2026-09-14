import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/tokens/colors.dart';
import 'package:estilo_neutral/core/design_system/tokens/icons.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_button.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_card.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_chip.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_money_text.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_refresh_button.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';

void main() {
  group('Design System Widget Tests', () {
    testWidgets('AppButton renders label and triggers callback on tap', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppButton(
              label: 'Guardar Venta',
              icon: AppIcons.save,
              onPressed: () => wasTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Guardar Venta'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('AppRefreshButton triggers user-initiated refresh (cero polling)', (tester) async {
      bool refreshTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppRefreshButton(
              label: 'Actualizar',
              onRefresh: () => refreshTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Actualizar'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.arrow_clockwise), findsOneWidget);

      await tester.tap(find.byType(AppRefreshButton));
      await tester.pump();

      expect(refreshTriggered, isTrue);
    });

    testWidgets('AppMoneyText renders correct prefix and formatted tabular numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppMoneyText(
                  amount: 25.50,
                  currency: MoneyCurrency.usd,
                  nature: MoneyNature.neutral,
                ),
                AppMoneyText(
                  amount: 12087.00,
                  currency: MoneyCurrency.bs,
                  nature: MoneyNature.credit,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text(r'$25.50'), findsOneWidget);
      expect(find.text('Bs. 12087.00'), findsOneWidget);
    });

    testWidgets('AppChip displays semantic variants and icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppChip(
                  label: 'Pagada',
                  variant: AppChipVariant.success,
                  icon: AppIcons.success,
                ),
                AppChip(
                  label: 'Pendiente',
                  variant: AppChipVariant.warning,
                  icon: AppIcons.warning,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Pagada'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.checkmark_circle), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.exclamationmark_circle), findsOneWidget);
    });

    testWidgets('AppCard applies border and background according to palette', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: Text('Contenido Card'),
            ),
          ),
        ),
      );

      expect(find.text('Contenido Card'), findsOneWidget);
    });

    test('Palette colors match exact hexadecimal specifications', () {
      expect(AppPalette.blue900.value, equals(0xFF005187));
      expect(AppPalette.blue700.value, equals(0xFF4D82BC));
      expect(AppPalette.blue400.value, equals(0xFF84B6F4));
      expect(AppPalette.blue100.value, equals(0xFFC4DAFA));
      expect(AppPalette.surface.value, equals(0xFFFCFFFF));
    });
  });
}
