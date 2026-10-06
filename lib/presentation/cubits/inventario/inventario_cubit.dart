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

  void toggleExpanded(String productoId) {
    if (state.expandedProductoId == productoId) {
      emit(state.copyWith(clearExpandedId: true));
    } else {
      emit(state.copyWith(expandedProductoId: productoId));
    }
  }

  Future<void> refresh() async {
    Logger.info('InventarioCubit: Refrescando inventario desde Google Sheets...');
    emit(state.copyWith(status: InventarioStatus.loading));
    await dataService.fetchAllSheets();
    _syncFromService();
  }

  /// Arma el producto desde el formulario. Devuelve el error de validación
  /// (antes: nombre vacío se ignoraba en silencio y montos mal escritos se
  /// guardaban como 0), o el producto listo para guardar.
  static ({Producto? producto, String? error}) construirProducto({
    required String id,
    required String nombre,
    required String marca,
    required String modelo,
    required String talla,
    required String cantidad,
    required String precio,
    String? fotoId,
  }) {
    if (nombre.trim().isEmpty) return (producto: null, error: 'El nombre es obligatorio.');
    final cant = int.tryParse(cantidad.trim());
    if (cant == null || cant < 0) return (producto: null, error: 'Cantidad: debe ser un entero mayor o igual a 0.');
    final precioUsd = double.tryParse(precio.trim().replaceAll(',', '.'));
    if (precioUsd == null || precioUsd <= 0) return (producto: null, error: 'Precio: debe ser un monto mayor a 0 (ej: 25.50).');
    return (
      producto: Producto(
        id: id,
        cantidad: cant,
        nombre: nombre.trim(),
        marca: marca.trim(),
        modelo: modelo.trim(),
        talla: talla.trim(),
        precioUsd: precioUsd,
        fotoId: fotoId,
      ),
      error: null,
    );
  }

  Future<void> addProducto(Producto producto) => _ejecutar(
        () => dataService.addProducto(producto),
        exito: 'Producto "${producto.nombre}" registrado y guardado en Google Sheets.',
      );

  Future<void> updateProducto(Producto producto) => _ejecutar(
        () => dataService.updateProducto(producto),
        exito: 'Producto "${producto.nombre}" actualizado.',
      );

  Future<void> actualizarFotoProducto(String id, String? fotoId) => _ejecutar(
        () => dataService.actualizarFotoProducto(id, fotoId),
        exito: 'Foto del producto actualizada.',
      );

  Future<void> adjustStock(String id, int delta) => _ejecutar(
        () => dataService.adjustStock(id, delta),
        exito: null,
      );

  Future<void> deleteProducto(String id) => _ejecutar(
        () => dataService.deleteProducto(id),
        exito: 'Producto desincorporado con éxito.',
      );

  /// Espera la operación (que revierte si Sheets falla) y emite el éxito o
  /// el error real. Sin [exito] no se muestra mensaje (p. ej. ±1 de stock).
  Future<void> _ejecutar(Future<void> Function() operacion, {required String? exito}) async {
    try {
      await operacion();
      if (isClosed || exito == null) return;
      emit(state.copyWith(status: InventarioStatus.success, actionSuccessMessage: exito));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => message.toString(),
        _ => e.toString(),
      }));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
