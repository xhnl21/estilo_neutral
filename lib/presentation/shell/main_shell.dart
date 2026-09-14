import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/design_system/tokens/colors.dart';
import '../../core/design_system/tokens/icons.dart';
import '../../features/audit/presentation/pages/audit_page.dart';
import '../../features/reporting/presentation/pages/reporting_page.dart';
import '../../features/sales/presentation/controllers/sales_controller.dart';
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/treasury/presentation/pages/treasury_page.dart';

/// Shell principal con navegación por Bounded Contexts.
/// Iconografía exclusivamente con CupertinoIcons, paleta azul y Cero Polling.
class MainShell extends StatefulWidget {
  final SalesController salesController;

  const MainShell({super.key, required this.salesController});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      SalesPage(controller: widget.salesController),
      const TreasuryPage(),
      const ReportingPage(),
      const AuditPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppPalette.divider, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(AppIcons.sale),
              selectedIcon: Icon(CupertinoIcons.cart_fill),
              label: 'Ventas',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.currency),
              selectedIcon: Icon(CupertinoIcons.money_dollar_circle_fill),
              label: 'Tesorería',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.report),
              selectedIcon: Icon(CupertinoIcons.doc_chart_fill),
              label: 'Reportes',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.audit),
              selectedIcon: Icon(CupertinoIcons.shield_fill),
              label: 'Auditoría',
            ),
          ],
        ),
      ),
    );
  }
}
