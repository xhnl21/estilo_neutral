import 'package:equatable/equatable.dart';
import '../../../models/cliente.dart';
import '../../../models/metodo_pago.dart';
import '../../../models/producto.dart';
import '../../../models/tasa_registro.dart';

enum NuevaVentaStatus { initial, submitting, success, failure }

/// Severidad del mensaje que la vista muestra como SnackBar.
enum NuevaVentaMessageType { success, warning, error }

/// Un renglón del carrito mientras se arma una factura nueva (no se persiste
/// hasta guardar la venta completa).
class VentaCartLine extends Equatable {
  final String productoId;
  final String nombre;
  final int cantidad;
  final double precioUsd;

  const VentaCartLine({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUsd,
  });

  double get subtotal => cantidad * precioUsd;

  @override
  List<Object?> get props => [productoId, nombre, cantidad, precioUsd];
}

/// Estado inmutable del formulario "Registrar Venta". Los catálogos se
/// resincronizan con [SheetsDataService] mientras el modal está abierto.
class NuevaVentaState extends Equatable {
  final NuevaVentaStatus status;
  final String nextVentaId;
  final List<Cliente> clientes;
  final List<Producto> productos;
  final List<MetodoPago> metodosPago;
  final TasaRegistro? tasaAutomatica;
  final TasaRegistro? tasaManual;

  final String? selectedClienteId;
  final String? selectedProductoId;
  final String? selectedMetodoPagoId;
  final bool usarTasaManual;
  final List<VentaCartLine> carrito;

  /// Deuda y saldo a favor del cliente seleccionado.
  final double deudaCliente;
  final double saldoCliente;

  /// Mensaje transitorio (se limpia en la siguiente emisión).
  final String? message;
  final NuevaVentaMessageType messageType;

  const NuevaVentaState({
    this.status = NuevaVentaStatus.initial,
    this.nextVentaId = '',
    this.clientes = const [],
    this.productos = const [],
    this.metodosPago = const [],
    this.tasaAutomatica,
    this.tasaManual,
    this.selectedClienteId,
    this.selectedProductoId,
    this.selectedMetodoPagoId,
    this.usarTasaManual = false,
    this.carrito = const [],
    this.deudaCliente = 0.0,
    this.saldoCliente = 0.0,
    this.message,
    this.messageType = NuevaVentaMessageType.success,
  });

  bool get isSubmitting => status == NuevaVentaStatus.submitting;

  /// Firmas del contenido de cada catálogo. Cuando cambian, la vista cierra
  /// los menús desplegables abiertos: un menú abierto (DropdownRoute) copia
  /// sus opciones al abrirse y no se actualiza.
  int get clientesVersion =>
      Object.hashAll(clientes.map((c) => Object.hash(c.id, c.nombre)));
  int get productosVersion => Object.hashAll(productos
      .map((p) => Object.hash(p.id, p.nombre, p.precioUsd, p.cantidad)));
  int get metodosPagoVersion =>
      Object.hashAll(metodosPago.map((m) => Object.hash(m.id, m.nombre)));

  Producto? get selectedProducto =>
      productos.where((p) => p.id == selectedProductoId).firstOrNull;

  double get totalCarrito => carrito.fold(0.0, (s, l) => s + l.subtotal);

  TasaRegistro? get tasaSeleccionada =>
      usarTasaManual ? tasaManual : tasaAutomatica;

  double get totalBs => totalCarrito * (tasaSeleccionada?.valor ?? 0.0);

  NuevaVentaState copyWith({
    NuevaVentaStatus? status,
    List<Cliente>? clientes,
    List<Producto>? productos,
    List<MetodoPago>? metodosPago,
    TasaRegistro? tasaAutomatica,
    TasaRegistro? tasaManual,
    String? selectedClienteId,
    bool clearSelectedCliente = false,
    String? selectedProductoId,
    String? selectedMetodoPagoId,
    bool? usarTasaManual,
    List<VentaCartLine>? carrito,
    double? deudaCliente,
    double? saldoCliente,
    String? message,
    NuevaVentaMessageType? messageType,
  }) {
    return NuevaVentaState(
      status: status ?? this.status,
      nextVentaId: nextVentaId,
      clientes: clientes ?? this.clientes,
      productos: productos ?? this.productos,
      metodosPago: metodosPago ?? this.metodosPago,
      tasaAutomatica: tasaAutomatica ?? this.tasaAutomatica,
      tasaManual: tasaManual ?? this.tasaManual,
      selectedClienteId: clearSelectedCliente
          ? null
          : (selectedClienteId ?? this.selectedClienteId),
      selectedProductoId: selectedProductoId ?? this.selectedProductoId,
      selectedMetodoPagoId: selectedMetodoPagoId ?? this.selectedMetodoPagoId,
      usarTasaManual: usarTasaManual ?? this.usarTasaManual,
      carrito: carrito ?? this.carrito,
      deudaCliente: deudaCliente ?? this.deudaCliente,
      saldoCliente: saldoCliente ?? this.saldoCliente,
      message: message,
      messageType: messageType ?? NuevaVentaMessageType.success,
    );
  }

  @override
  List<Object?> get props => [
        status,
        nextVentaId,
        clientes,
        productos,
        metodosPago,
        tasaAutomatica,
        tasaManual,
        selectedClienteId,
        selectedProductoId,
        selectedMetodoPagoId,
        usarTasaManual,
        carrito,
        deudaCliente,
        saldoCliente,
        message,
        messageType,
      ];
}
