import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/config/environment_config.dart';
import '../../core/design_system/design_system.dart';
import '../../features/reporting/reporting.dart';
import '../../features/sales/sales.dart';
import '../../features/treasury/treasury.dart';
import '../../shared/shared.dart';
import '../pages/pages.dart';

import 'package:go_router/go_router.dart';

/// Shell principal con navegación para las 9 vistas correspondientes a cada hoja
/// de la base de datos Google Sheets "Estilo Neutral".
class MainShell extends StatefulWidget {
  final SalesController salesController;
  final SheetsDataService dataService;
  final StatefulNavigationShell? navigationShell;

  const MainShell({
    super.key,
    required this.salesController,
    required this.dataService,
    this.navigationShell,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _localIndex = 2; // Inicia en Ventas por defecto si no hay navigationShell
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int get _currentIndex => widget.navigationShell?.currentIndex ?? _localIndex;

  late final List<Widget> _pages;

  final List<({String title, String sheet, IconData icon, String category})> _vistasInfo = [
    (title: 'Clientes', sheet: 'clientes', icon: CupertinoIcons.person_2, category: 'Operaciones'),
    (title: 'Inventario', sheet: 'inventario', icon: CupertinoIcons.tag, category: 'Operaciones'),
    (title: 'Ventas', sheet: 'ventas', icon: CupertinoIcons.cart, category: 'Operaciones'),
    (title: 'Compras Divisas', sheet: 'compras_divisas', icon: CupertinoIcons.money_dollar_circle, category: 'Operaciones'),
    (title: 'Resumen Diario', sheet: 'resumen_diario', icon: CupertinoIcons.doc_chart, category: 'Cierre y Finanzas'),
    (title: 'Cuarentena', sheet: 'cuarentena', icon: CupertinoIcons.shield_slash, category: 'Gobierno y Calidad ISO'),
    (title: 'Audit Log', sheet: 'audit_log', icon: CupertinoIcons.shield, category: 'Gobierno y Calidad ISO'),
    (title: 'Reporte Migración', sheet: 'reporte_migracion', icon: CupertinoIcons.doc_text, category: 'Gobierno y Calidad ISO'),
    (title: 'Checklist ISO', sheet: 'checklist_iso', icon: CupertinoIcons.checkmark_seal, category: 'Gobierno y Calidad ISO'),
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      ClientesPage(dataService: widget.dataService),
      InventarioPage(dataService: widget.dataService),
      SalesPage(controller: widget.salesController, dataService: widget.dataService),
      TreasuryPage(dataService: widget.dataService),
      ReportingPage(dataService: widget.dataService),
      CuarentenaPage(dataService: widget.dataService),
      AuditLogPage(dataService: widget.dataService),
      ReporteMigracionPage(dataService: widget.dataService),
      ChecklistIsoPage(dataService: widget.dataService),
    ];
  }

  void _navigateToIndex(int index) {
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(
        index,
        initialLocation: index == widget.navigationShell!.currentIndex,
      );
    } else {
      setState(() => _localIndex = index);
    }
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentInfo = _vistasInfo[_currentIndex];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppPalette.surface,
      drawer: _buildNavigationDrawer(context),
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(
          bottom: BorderSide(color: AppPalette.divider, width: 1),
        ),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.bars, color: AppPalette.blue900),
          tooltip: 'Menú de 9 Vistas',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Semantics(
                  header: true,
                  headingLevel: 1,
                  child: Text(
                    currentInfo.title,
                    style: AppTypography.titleLarge.copyWith(fontSize: 16),
                  ),
                ),
                if (EnvironmentConfig.showTechnicalInfo) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppPalette.blue100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentInfo.sheet,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppPalette.blue900,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (EnvironmentConfig.showTechnicalInfo)
              Text(
                'Base de Datos Google Sheets: ${SheetsConfig.defaultSpreadsheetId.length > 16 ? '${SheetsConfig.defaultSpreadsheetId.substring(0, 16)}...' : SheetsConfig.defaultSpreadsheetId}',
                style: AppTypography.labelSmall.copyWith(fontSize: 10, color: AppPalette.textSecondary),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.square_grid_2x2, color: AppPalette.blue700, size: 20),
            tooltip: 'Selector de Hojas',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.navigationShell ??
          IndexedStack(
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
          selectedIndex: _currentIndex <= 3 ? _currentIndex : 4,
          onDestinationSelected: (index) {
            if (index == 4) {
              _scaffoldKey.currentState?.openDrawer();
            } else {
              _navigateToIndex(index);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(CupertinoIcons.person_2),
              selectedIcon: Icon(CupertinoIcons.person_2_fill),
              label: 'Clientes',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.tag),
              selectedIcon: Icon(CupertinoIcons.tag_fill),
              label: 'Inventario',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.cart),
              selectedIcon: Icon(CupertinoIcons.cart_fill),
              label: 'Ventas',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.money_dollar_circle),
              selectedIcon: Icon(CupertinoIcons.money_dollar_circle_fill),
              label: 'Tesorería',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.square_grid_2x2),
              selectedIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
              label: 'Más Vistas (9)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppPalette.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del Drawer
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: AppPalette.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.table_badge_more, color: AppPalette.blue700, size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Estilo Neutral',
                          style: AppTypography.headlineMedium.copyWith(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    EnvironmentConfig.showTechnicalInfo
                        ? '9 Vistas sincronizadas con Google Sheets'
                        : 'Módulos del Sistema',
                    style: AppTypography.bodyMedium.copyWith(fontSize: 12),
                  ),
                  if (EnvironmentConfig.showTechnicalInfo) ...[
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${SheetsConfig.defaultSpreadsheetId}',
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Lista categorizada de las 9 vistas
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _buildCategoryHeader('OPERACIONES COMERCIALES'),
                  _buildDrawerItem(0, _vistasInfo[0]),
                  _buildDrawerItem(1, _vistasInfo[1]),
                  _buildDrawerItem(2, _vistasInfo[2]),
                  _buildDrawerItem(3, _vistasInfo[3]),

                  const Divider(height: 24, thickness: 1, color: AppPalette.divider),
                  _buildCategoryHeader('CIERRE & FINANZAS'),
                  _buildDrawerItem(4, _vistasInfo[4]),

                  const Divider(height: 24, thickness: 1, color: AppPalette.divider),
                  _buildCategoryHeader('GOBIERNO & CALIDAD ISO'),
                  _buildDrawerItem(5, _vistasInfo[5]),
                  _buildDrawerItem(6, _vistasInfo[6]),
                  _buildDrawerItem(7, _vistasInfo[7]),
                  _buildDrawerItem(8, _vistasInfo[8]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Semantics(
      header: true,
      headingLevel: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
        child: Text(
          title,
          style: AppTypography.labelSmall.copyWith(
            letterSpacing: 0.8,
            fontSize: 11,
            color: AppPalette.blue900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(int index, ({String title, String sheet, IconData icon, String category}) info) {
    final isSelected = _currentIndex == index;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${info.title}, categoría ${info.category}',
      hint: 'Navegar a la vista de ${info.title}',
      child: ListTile(
        dense: true,
        selected: isSelected,
        selectedTileColor: AppPalette.blue100.withValues(alpha: 0.5),
        leading: ExcludeSemantics(
          child: Icon(
            info.icon,
            color: isSelected ? AppPalette.blue900 : AppPalette.blue700,
            size: 20,
          ),
        ),
        title: Text(
          info.title,
          style: TextStyle(
            color: isSelected ? AppPalette.blue900 : AppPalette.textPrimary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        subtitle: EnvironmentConfig.showTechnicalInfo
            ? Text(
                'Hoja: ${info.sheet}',
                style: const TextStyle(fontSize: 11, color: AppPalette.textSecondary),
              )
            : null,
        trailing: isSelected
            ? const ExcludeSemantics(
                child: Icon(CupertinoIcons.checkmark_alt, size: 16, color: AppPalette.blue900),
              )
            : null,
        onTap: () => _navigateToIndex(index),
      ),
    );
  }
}
