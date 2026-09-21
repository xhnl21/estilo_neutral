import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/design_system/theme/app_theme.dart';
import 'package:estilo_neutral/core/design_system/tokens/icons.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_button.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_card.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_chip.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_empty_state.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_error_state.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_loading_state.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_money_text.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_outlined_button.dart';
import 'package:estilo_neutral/core/design_system/widgets/app_scaffold.dart';
import 'package:estilo_neutral/features/sales/application/dtos/sale_dto.dart';
import 'package:estilo_neutral/features/sales/presentation/widgets/sale_list_item.dart';

void main() {
  group('Accessibility & Semantics Tests (WCAG 2.1 AA / TalkBack & VoiceOver)',
      () {
    testWidgets(
        'AppButton has button semantics, label, and excludes decorative icon',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppButton(
              label: 'Guardar Venta',
              icon: AppIcons.save,
              semanticHint: 'Registra la venta en Google Sheets',
              onPressed: () {},
            ),
          ),
        ),
      );

      // Verify presence in semantics tree
      expect(find.bySemanticsLabel('Guardar Venta'), findsOneWidget);

      // Verify semantics node properties
      expect(
        tester.getSemantics(find.byType(ElevatedButton)),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          label: 'Guardar Venta',
          hint: 'Registra la venta en Google Sheets',
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('AppButton in loading state reflects loading semantics',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppButton(
              label: 'Sincronizar',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Cargando Sincronizar'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(ElevatedButton)),
        matchesSemantics(
          isButton: true,
          isEnabled: false,
          hasEnabledState: true,
          label: 'Cargando Sincronizar',
        ),
      );

      handle.dispose();
    });

    testWidgets(
        'AppOutlinedButton provides button semantics and accessible hint',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppOutlinedButton(
              label: 'Cancelar',
              icon: CupertinoIcons.clear,
              semanticHint: 'Cierra el formulario sin guardar cambios',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Cancelar'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(OutlinedButton)),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          label: 'Cancelar',
          hint: 'Cierra el formulario sin guardar cambios',
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets(
        'AppCard with onTap provides button semantics and supports mergeSemantics',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppCard(
              onTap: () {},
              mergeSemantics: true,
              semanticLabel: 'Ficha de Cliente Juan Pérez',
              semanticHint: 'Toca dos veces para ver el historial',
              child: const Text('Juan Pérez'),
            ),
          ),
        ),
      );

      expect(
          find.bySemanticsLabel('Ficha de Cliente Juan Pérez'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('AppChip has container semantics and excludes decorative icon',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppChip(
              label: 'Pagada',
              variant: AppChipVariant.success,
              icon: AppIcons.success,
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Estado: Pagada'), findsOneWidget);

      handle.dispose();
    });

    testWidgets(
        'AppEmptyState marks title as heading and excludes decorative icon',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'No hay productos',
              subtitle: 'Agrega un nuevo producto para comenzar',
              icon: CupertinoIcons.tag,
            ),
          ),
        ),
      );

      final titleData =
          tester.getSemantics(find.text('No hay productos')).getSemanticsData();
      expect(titleData.flagsCollection.isHeader, isTrue);

      handle.dispose();
    });

    testWidgets(
        'AppErrorState has liveRegion and heading semantics for screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppErrorState(
              message: 'Fallo al conectar con Google Sheets',
            ),
          ),
        ),
      );

      final errorTitleData =
          tester.getSemantics(find.text('Ocurrió un error')).getSemanticsData();
      expect(errorTitleData.flagsCollection.isHeader, isTrue);
      expect(errorTitleData.flagsCollection.isLiveRegion, isTrue);

      handle.dispose();
    });

    testWidgets(
        'AppLoadingState has liveRegion and descriptive message semantics',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingState(
              message: 'Cargando inventario...',
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Cargando inventario...'), findsOneWidget);

      handle.dispose();
    });

    testWidgets(
        'AppMoneyText speaks natural currency and nature for screen readers',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppMoneyText(
                  amount: 45.50,
                  currency: MoneyCurrency.usd,
                  nature: MoneyNature.neutral,
                ),
                AppMoneyText(
                  amount: 150.00,
                  currency: MoneyCurrency.usd,
                  nature: MoneyNature.debt,
                ),
                AppMoneyText(
                  amount: 2500.00,
                  currency: MoneyCurrency.bs,
                  nature: MoneyNature.credit,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('45.50 dólares'), findsOneWidget);
      expect(find.bySemanticsLabel('150.00 dólares, en deuda'), findsOneWidget);
      expect(
          find.bySemanticsLabel('2500.00 bolívares, a favor'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('AppScaffold marks AppBar title with headingLevel 1',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: AppScaffold(
            title: 'Inventario General',
            body: SizedBox.shrink(),
          ),
        ),
      );

      final headingData = tester
          .getSemantics(find.text('Inventario General'))
          .getSemanticsData();
      expect(headingData.flagsCollection.isHeader, isTrue);

      handle.dispose();
    });

    testWidgets(
        'SaleListItem has unified cohesive semantics with status and amounts',
        (tester) async {
      final handle = tester.ensureSemantics();

      const sale = SaleDto(
        id: 'v00000001',
        date: '2026-09-15',
        customerId: 'c00000001',
        firstItemId: 'p00000001',
        totalQuantity: 2,
        bcvRate: 40.0,
        usdRate: 40.0,
        paymentMethod: 'Efectivo USD',
        mobilePaymentFeeBs: 0.0,
        montoBs: 4800.00,
        montoUsd: 120.00,
        abonoUsd: 120.00,
        deudaUsd: 0.0,
        totalPagarUsd: 120.00,
        validacion: 'OK',
        estado: 'Pagada',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SaleListItem(
              sale: sale,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(
            'Venta #v00000001, estado: Pagada, cliente: c00000001, total: 120.00 dólares'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('Interactive AppButton meets labeledTapTargetGuideline',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: AppButton(
                label: 'Confirmar Operación',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      handle.dispose();
    });
  });
}
