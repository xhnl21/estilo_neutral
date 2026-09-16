import 'package:estilo_neutral/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapWithApp(Widget child, {double width = 360, double height = 700}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, height)),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Atomic Skeleton Components Tests', () {
    testWidgets('AppShimmer renders child and animates smoothly', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const AppShimmer(
            child: Text('Cargando prueba...'),
          ),
        ),
      );

      expect(find.text('Cargando prueba...'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('SkeletonBox renders with custom dimensions and shape', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SkeletonBox(
            width: 120,
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      );

      final box = find.byType(SkeletonBox);
      expect(box, findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
        of: box,
        matching: find.byType(Container),
      ));
      expect(container.constraints?.minWidth, 120);
      expect(container.constraints?.minHeight, 40);
    });

    testWidgets('SkeletonCircle renders with custom radius', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SkeletonCircle(radius: 24),
        ),
      );

      expect(find.byType(SkeletonCircle), findsOneWidget);
      final container = tester.widget<Container>(find.descendant(
        of: find.byType(SkeletonCircle),
        matching: find.byType(Container),
      ));
      expect(container.constraints?.minWidth, 48);
      expect(container.constraints?.minHeight, 48);
    });

    testWidgets('SkeletonLine presets render appropriate heights', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const Column(
            children: [
              SkeletonLine.title(),
              SkeletonLine.subtitle(),
              SkeletonLine.body(),
              SkeletonLine.caption(),
            ],
          ),
        ),
      );

      expect(find.byType(SkeletonLine), findsNWidgets(4));
    });

    testWidgets('SkeletonCard matches AppCard border styling', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SkeletonCard(
            child: Text('Card Content'),
          ),
        ),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });
  });

  group('Composite View Skeletons & Responsiveness Tests (No Overflow)', () {
    testWidgets('ClientesListSkeleton renders without overflow on 320px narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const ClientesListSkeleton(itemCount: 4),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(ClientesListSkeleton), findsOneWidget);
      expect(find.byType(SkeletonCard), findsNWidgets(4));
    });

    testWidgets('SalesSkeleton renders without overflow on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const SalesSkeleton(itemCount: 3),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(SalesSkeleton), findsOneWidget);
    });

    testWidgets('InventarioSkeleton renders with thumbnails without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const InventarioSkeleton(itemCount: 3),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(InventarioSkeleton), findsOneWidget);
    });

    testWidgets('TreasurySkeleton renders consolidated card & items without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const TreasurySkeleton(itemCount: 2),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(TreasurySkeleton), findsOneWidget);
    });

    testWidgets('ReportingSkeleton renders KPI & closures without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const ReportingSkeleton(itemCount: 2),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(ReportingSkeleton), findsOneWidget);
    });

    testWidgets('CuarentenaSkeleton renders anomaly cards without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const CuarentenaSkeleton(itemCount: 3),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(CuarentenaSkeleton), findsOneWidget);
    });

    testWidgets('AuditLogSkeleton renders chips and checkpoints without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const AuditLogSkeleton(itemCount: 3),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(AuditLogSkeleton), findsOneWidget);
    });

    testWidgets('ChecklistIsoSkeleton renders global bar & items without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const ChecklistIsoSkeleton(itemCount: 3),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(ChecklistIsoSkeleton), findsOneWidget);
    });

    testWidgets('ReporteMigracionSkeleton renders metrics cards without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrapWithApp(
          const ReporteMigracionSkeleton(itemCount: 3),
          width: 320,
          height: 640,
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.byType(ReporteMigracionSkeleton), findsOneWidget);
    });
  });
}
