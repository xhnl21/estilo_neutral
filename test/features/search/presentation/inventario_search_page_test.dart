import 'package:estilo_neutral/core/design_system/widgets/app_empty_state.dart';
import 'package:estilo_neutral/features/search/application/usecases/search_engine.dart';
import 'package:estilo_neutral/features/search/domain/entities/inventario_item.dart';
import 'package:estilo_neutral/features/search/infrastructure/repositories/cloud_inventario_search_repository.dart';
import 'package:estilo_neutral/features/search/infrastructure/utils/debouncer.dart';
import 'package:estilo_neutral/features/search/presentation/cubit/search_cubit.dart';
import 'package:estilo_neutral/features/search/presentation/pages/inventario_search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventarioSearchPage', () {
    late CloudInventarioSearchRepository repository;
    late SearchEngine<InventarioItem> searchEngine;
    late SearchCubit<InventarioItem> cubit;

    setUp(() {
      repository = CloudInventarioSearchRepository();
      searchEngine = SearchEngine<InventarioItem>();
      cubit = SearchCubit<InventarioItem>(
        searchEngine: searchEngine,
        repository: repository,
        debouncer: Debouncer(duration: const Duration(milliseconds: 10)),
      );
    });

    tearDown(() {
      cubit.close();
    });

    Widget createWidgetUnderTest() {
      return MaterialApp(
        home: InventarioSearchPage(cubit: cubit),
      );
    }

    testWidgets('renders search bar and initial inventory items', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Buscador de Inventario'), findsOneWidget);
      expect(find.text('Buscar en inventario'), findsOneWidget);
      expect(find.text('p00000001'), findsOneWidget);
      expect(find.text('p00000003'), findsOneWidget);
    });

    testWidgets('filters items when typing in search input (fuzzy matching)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'jian'); // typo for jean
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('p00000002'), findsOneWidget);
      expect(find.text('p00000001'), findsNothing);
    });

    testWidgets('displays AppEmptyState when no product matches', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'producto_no_existente_999');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Sin Resultados en Inventario'), findsOneWidget);
    });

    testWidgets('tapping clear button resets search', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'nike');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('p00000003'), findsOneWidget);

      final clearButtonFinder = find.byTooltip('Limpiar búsqueda');
      expect(clearButtonFinder, findsOneWidget);

      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('p00000001'), findsOneWidget);
    });
  });
}
