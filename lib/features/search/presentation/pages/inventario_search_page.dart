import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import '../../application/usecases/search_engine.dart';
import '../../domain/entities/inventario_item.dart';
import '../../infrastructure/repositories/cloud_inventario_search_repository.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../widgets/search_highlighted_text.dart';

/// Página del buscador reactivo de inventario que consulta los productos
/// obtenidos desde la nube (Google Sheets), tolerando errores tipográficos
/// (Fuzzy Levenshtein), coincidencias esparcidas y scoring ponderado.
class InventarioSearchPage extends StatelessWidget {
  /// Servicio de datos de Google Sheets para consultar los productos en la nube.
  final SheetsDataService? dataService;

  /// Cubit opcional inyectado externamente (útil para pruebas o custom flows).
  final SearchCubit<InventarioItem>? cubit;

  /// Callback opcional al seleccionar un producto del inventario.
  final ValueChanged<InventarioItem>? onItemSelected;

  /// Crea la pantalla del buscador de inventario.
  const InventarioSearchPage({
    super.key,
    this.dataService,
    this.cubit,
    this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _InventarioSearchView(
          dataService: dataService,
          onItemSelected: onItemSelected,
        ),
      );
    }

    return BlocProvider(
      create: (context) {
        final repo = CloudInventarioSearchRepository(dataService: dataService);
        return SearchCubit<InventarioItem>(
          searchEngine: SearchEngine<InventarioItem>(),
          repository: repo,
        );
      },
      child: _InventarioSearchView(
        dataService: dataService,
        onItemSelected: onItemSelected,
      ),
    );
  }
}

class _InventarioSearchView extends StatefulWidget {
  final SheetsDataService? dataService;
  final ValueChanged<InventarioItem>? onItemSelected;

  const _InventarioSearchView({
    this.dataService,
    this.onItemSelected,
  });

  @override
  State<_InventarioSearchView> createState() => _InventarioSearchViewState();
}

class _InventarioSearchViewState extends State<_InventarioSearchView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataService;

    return AppScaffold(
      title: 'Buscador de Inventario',
      actions: [
        if (ds != null)
          AppRefreshButton(
            onRefresh: () async {
              final searchCubit = context.read<SearchCubit<InventarioItem>>();
              await ds.fetchAllSheets();
              if (mounted) {
                searchCubit.clear();
              }
            },
            isLoading: ds.isLoading,
          ),
      ],
      body: DismissKeyboard(
        child: Padding(
          padding: AppSpacing.pLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchInput(context),
              const SizedBox(height: AppSpacing.md),
              _buildHeaderStatus(context),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _buildResultsList(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput(BuildContext context) {
    return AppTextField(
      label: 'Buscar en inventario',
      hint: 'Prenda, marca, modelo, talla o ID (ej: Nike, M, p00000001)...',
      controller: _controller,
      prefixIcon: AppIcons.search,
      suffix: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          if (value.text.isEmpty) return const SizedBox.shrink();
          return IconButton(
            icon: const Icon(AppIcons.close, size: 18, color: AppPalette.textSecondary),
            onPressed: () {
              _controller.clear();
              context.read<SearchCubit<InventarioItem>>().clear();
            },
            tooltip: 'Limpiar búsqueda',
          );
        },
      ),
      onChanged: (text) {
        context.read<SearchCubit<InventarioItem>>().onQueryChanged(text);
      },
    );
  }

  Widget _buildHeaderStatus(BuildContext context) {
    return BlocBuilder<SearchCubit<InventarioItem>, SearchState<InventarioItem>>(
      builder: (context, state) {
        final query = state.query;
        final count = state.items.length;

        if (state is SearchLoading) {
          return const Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppPalette.primary),
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Buscando en la nube...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }

        if (query.isEmpty) {
          return Text(
            '$count productos registrados en inventario',
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                '$count ${count == 1 ? 'producto coincidente' : 'productos coincidentes'} para "$query"',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.primary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (state is SearchLoaded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppPalette.blue100,
                  borderRadius: AppSpacing.roundedPill,
                ),
                child: const Text(
                  'Fuzzy & Scoring Activo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppPalette.blue900,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildResultsList(BuildContext context) {
    return BlocBuilder<SearchCubit<InventarioItem>, SearchState<InventarioItem>>(
      builder: (context, state) {
        if (state is SearchEmpty) {
          return const AppEmptyState(
            icon: AppIcons.search,
            title: 'Sin Resultados en Inventario',
            subtitle: 'No se encontraron prendas o artículos para la búsqueda.\nPrueba con otra marca, modelo, talla o ID.',
          );
        }

        final items = state.items;

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final producto = items[index];
            final result = producto.searchResult;
            final score = result?.score ?? 0;

            return AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              onTap: () {
                if (widget.onItemSelected != null) {
                  widget.onItemSelected!(producto);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 1),
                      content: Text('${producto.name} - ${producto.marca} (${producto.id})'),
                    ),
                  );
                }
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge con ID del producto
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppPalette.blue100,
                      borderRadius: AppSpacing.roundedSm,
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Text(
                      producto.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppPalette.blue900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Detalles del producto con texto resaltado
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SearchHighlightedText(
                          text: producto.name,
                          highlightSpans: result?.highlightSpans ?? const [],
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              '${producto.marca} · ${producto.modelo}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppPalette.border.withValues(alpha: 0.5),
                                borderRadius: AppSpacing.roundedSm,
                              ),
                              child: Text(
                                'Talla ${producto.talla}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppPalette.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'Stock: ${producto.cantidad}',
                              style: TextStyle(
                                fontSize: 11,
                                color: producto.cantidad > 0
                                    ? AppPalette.textSecondary
                                    : AppPalette.error,
                                fontWeight: producto.cantidad > 0
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Precio y Badge de Scoring
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${producto.precioUsd.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppPalette.success,
                        ),
                      ),
                      if (score > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: score >= 100
                                ? AppPalette.success.withValues(alpha: 0.12)
                                : AppPalette.blue700.withValues(alpha: 0.12),
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: Text(
                            '$score pts',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: score >= 100
                                  ? AppPalette.success
                                  : AppPalette.blue700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
