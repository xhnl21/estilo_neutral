import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/logger.dart';
import '../../../models/producto.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'inventario_state.dart';

/// Cubit para gestión de estado del módulo de Inventario (arquitectura BLoC).
class InventarioCubit extends Cubit<InventarioState> {
  final SheetsDataService dataService;

  InventarioCubit({
    required this.dataService,
    String? initialSearchQuery,
  }) : super(InventarioState(searchQuery: initialSearchQuery ?? '')) {
    _init();
  }

  void _init() {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  void _onDataServiceChanged() {
    _syncFromService();
  }

  void _syncFromService() {
    final currentList = List<Producto>.from(dataService.productos);
    final filtered = _filter(currentList, state.searchQuery);
    emit(state.copyWith(
      status: dataService.isLoading ? InventarioStatus.loading : InventarioStatus.success,
      productos: currentList,
      filteredProductos: filtered,
      errorMessage: dataService.errorMessage,
    ));
  }

  List<Producto> _filter(List<Producto> list, String query) {
    if (query.trim().isEmpty) return list;
    final q = query.toLowerCase().trim();
    return list.where((p) {
      return p.nombre.toLowerCase().contains(q) ||
          p.marca.toLowerCase().contains(q) ||
          p.modelo.toLowerCase().contains(q) ||
          p.talla.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q);
    }).toList();
  }

  void search(String query) {
    final filtered = _filter(state.productos, query);
    emit(state.copyWith(
      searchQuery: query,
      filteredProductos: filtered,
    ));
  }

  Future<void> refresh() async {
    Logger.info('InventarioCubit: Refrescando inventario desde Google Sheets...');
    emit(state.copyWith(status: InventarioStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  Future<void> addProducto(Producto producto) async {
    emit(state.copyWith(status: InventarioStatus.loading));
    final success = await dataService.addProducto(producto);
    emit(state.copyWith(
      status: InventarioStatus.success,
      actionSuccessMessage: success
          ? 'Producto "${producto.nombre}" registrado y sincronizado en Google Sheets.'
          : 'Producto "${producto.nombre}" guardado localmente.',
    ));
  }

  void updateProducto(Producto producto) {
    dataService.updateProducto(producto);
    emit(state.copyWith(
      status: InventarioStatus.success,
      actionSuccessMessage: 'Producto "${producto.nombre}" actualizado con éxito.',
    ));
  }

  void deleteProducto(String id) {
    dataService.deleteProducto(id);
    emit(state.copyWith(
      status: InventarioStatus.success,
      actionSuccessMessage: 'Producto desincorporado con éxito.',
    ));
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
