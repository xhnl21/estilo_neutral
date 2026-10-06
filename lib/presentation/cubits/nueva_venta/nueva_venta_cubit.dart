import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../app/di/injection.dart';
import '../../../core/utils/logger.dart';
import '../../../features/credits/credits.dart';
import '../../../models/producto.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'nueva_venta_state.dart';

/// Cubit del formulario "Registrar Venta". Se suscribe a [SheetsDataService]
/// para que clientes, productos, métodos de pago y tasas creados en otros
/// módulos aparezcan en el formulario abierto sin refrescar.
class NuevaVentaCubit extends Cubit<NuevaVentaState> {
  final SheetsDataService dataService;
  final SheetsCreditsDataSource creditsDataSource;

  NuevaVentaCubit({
    required this.dataService,
    SheetsCreditsDataSource? creditsDataSource,
    String? initialClienteId,
  })  : creditsDataSource =
            creditsDataSource ?? ServiceLocator().creditsDataSource,
        super(NuevaVentaState(selectedClienteId: initialClienteId)) {
    _init();
  }

  void _init() {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService(isInitial: true);
  }

  void _onDataServiceChanged() {
    _syncFromService();
  }

  void _syncFromService({bool isInitial = false}) {
    final clientes = List.of(dataService.clientes);
    final productosUnicos = <String, Producto>{};
    for (final p in dataService.productos) {
      productosUnicos.putIfAbsent(p.id, () => p);
    }
    final productos = productosUnicos.values.toList();
    final metodos = List.of(dataService.metodosPagoActivos);

    // Mantener la selección mientras siga existiendo. Un cliente que
    // desaparece (p. ej. el servidor le reasignó el ID) deja la selección
    // vacía en vez de cambiarla en silencio a otro cliente.
    String? clienteId = state.selectedClienteId;
    if (!clientes.any((c) => c.id == clienteId)) {
      clienteId = isInitial ? clientes.firstOrNull?.id : null;
    }
    String? productoId = state.selectedProductoId;
    if (!productos.any((p) => p.id == productoId)) {
      productoId = productos.firstOrNull?.id;
    }
    String? metodoId = state.selectedMetodoPagoId;
    if (!metodos.any((m) => m.id == metodoId)) {
      metodoId = metodos.firstOrNull?.id;
    }

    final (deuda, saldo) = _resumenCliente(clienteId);
    emit(NuevaVentaState(
      status: state.status,
      nextVentaId: dataService.nextVentaId,
      clientes: clientes,
      productos: productos,
      metodosPago: metodos,
      tasaAutomatica: dataService.tasaVigenteEnMonedaBase,
      tasaManual: dataService
          .tasaManualOrganizacion(dataService.currentOrganizacionId ?? ''),
      selectedClienteId: clienteId,
      selectedProductoId: productoId,
      selectedMetodoPagoId: metodoId,
      usarTasaManual: state.usarTasaManual,
      carrito: state.carrito,
      deudaCliente: deuda,
      saldoCliente: saldo,
    ));
  }

  (double, double) _resumenCliente(String? clienteId) {
    if (clienteId == null) return (0.0, 0.0);
    final deuda = dataService.ventas
        .where((v) => v.clienteId == clienteId)
        .fold<double>(0.0, (s, v) => s + (v.deudaUsd > 0 ? v.deudaUsd : 0.0));
    final saldo = creditsDataSource.credits
        .where((c) => c.clienteId == clienteId && c.isAvailable)
        .fold<double>(0.0, (s, c) => s + c.saldoUsd);
    return (deuda, saldo);
  }

  void selectCliente(String clienteId) {
    final (deuda, saldo) = _resumenCliente(clienteId);
    emit(state.copyWith(
      selectedClienteId: clienteId,
      deudaCliente: deuda,
      saldoCliente: saldo,
    ));
  }

  void selectProducto(String productoId) {
    emit(state.copyWith(selectedProductoId: productoId));
  }

  void selectMetodoPago(String metodoPagoId) {
    emit(state.copyWith(selectedMetodoPagoId: metodoPagoId));
  }

  void setUsarTasaManual(bool value) {
    emit(state.copyWith(usarTasaManual: value));
  }

  /// Agrega el producto seleccionado al carrito. Devuelve `true` si se agregó.
  bool addToCart(String cantidadTexto) {
    final producto = state.selectedProducto;
    final cantidad = int.tryParse(cantidadTexto.trim()) ?? 0;
    if (producto == null || cantidad < 1) return false;
    if (cantidad > producto.cantidad) {
      emit(state.copyWith(
        messageType: NuevaVentaMessageType.error,
        message:
            'Solo hay ${producto.cantidad} en stock de ${producto.nombre}.',
      ));
      return false;
    }
    emit(state.copyWith(carrito: [
      ...state.carrito,
      VentaCartLine(
        productoId: producto.id,
        nombre: producto.nombre,
        cantidad: cantidad,
        precioUsd: producto.precioUsd,
      ),
    ]));
    return true;
  }

  /// Limpia el mensaje ya mostrado, para que el mismo mensaje pueda
  /// volver a emitirse (un estado igual al anterior no se emite).
  void messageShown() {
    if (state.message != null) emit(state.copyWith());
  }

  void removeFromCart(int index) {
    emit(state.copyWith(carrito: List.of(state.carrito)..removeAt(index)));
  }

  Future<void> submit(String abonoTexto) async {
    if (state.isSubmitting) return;
    final clienteId = state.selectedClienteId;
    if (clienteId == null) {
      emit(state.copyWith(
        messageType: NuevaVentaMessageType.error,
        message: 'Seleccioná un cliente.',
      ));
      return;
    }
    if (state.carrito.isEmpty) {
      emit(state.copyWith(
        messageType: NuevaVentaMessageType.error,
        message: 'Agregá al menos un producto al carrito.',
      ));
      return;
    }

    final abono =
        double.tryParse(abonoTexto.replaceAll(',', '.')) ?? state.totalCarrito;
    emit(state.copyWith(status: NuevaVentaStatus.submitting));
    try {
      await dataService.addVenta(
        clienteId: clienteId,
        items: state.carrito
            .map((l) => (
                  productoId: l.productoId,
                  cantidad: l.cantidad,
                  precioUsd: l.precioUsd,
                ))
            .toList(),
        metodoPagoId: state.selectedMetodoPagoId ?? '',
        abonoUsd: abono,
        usarTasaManual: state.usarTasaManual,
      );
      if (isClosed) return;
      emit(state.copyWith(
        status: NuevaVentaStatus.success,
        messageType: NuevaVentaMessageType.success,
        message: 'Venta registrada con éxito.',
      ));
    } catch (e, stackTrace) {
      // El lote es atómico: si falló no quedó nada guardado y el formulario
      // sigue abierto para reintentar.
      Logger.error('NuevaVentaCubit: Error al registrar venta', e, stackTrace);
      if (isClosed) return;
      emit(state.copyWith(
        status: NuevaVentaStatus.failure,
        messageType: NuevaVentaMessageType.error,
        message: e is StateError ? e.message : 'Error al registrar venta: $e',
      ));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
