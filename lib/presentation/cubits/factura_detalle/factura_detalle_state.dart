import 'package:equatable/equatable.dart';
import '../../../models/abono.dart';
import '../../../models/cliente.dart';
import '../../../models/venta.dart';
import '../../../models/venta_item.dart';

enum FacturaDetalleStatus { initial, loading, success, failure }

/// Estado inmutable para la vista de Detalle de Factura (BLoC/Cubit).
class FacturaDetalleState extends Equatable {
  final FacturaDetalleStatus status;
  final String ventaId;
  final Venta? venta;
  final Cliente? cliente;
  final List<VentaItem> items;
  final List<Abono> abonos;
  final String? errorMessage;

  const FacturaDetalleState({
    this.status = FacturaDetalleStatus.initial,
    required this.ventaId,
    this.venta,
    this.cliente,
    this.items = const [],
    this.abonos = const [],
    this.errorMessage,
  });

  FacturaDetalleState copyWith({
    FacturaDetalleStatus? status,
    String? ventaId,
    Venta? venta,
    bool clearVenta = false,
    Cliente? cliente,
    bool clearCliente = false,
    List<VentaItem>? items,
    List<Abono>? abonos,
    String? errorMessage,
  }) {
    return FacturaDetalleState(
      status: status ?? this.status,
      ventaId: ventaId ?? this.ventaId,
      venta: clearVenta ? null : (venta ?? this.venta),
      cliente: clearCliente ? null : (cliente ?? this.cliente),
      items: items ?? this.items,
      abonos: abonos ?? this.abonos,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        ventaId,
        venta,
        cliente,
        items,
        abonos,
        errorMessage,
      ];
}
