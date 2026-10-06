import 'package:equatable/equatable.dart';
import '../../../models/metodo_pago.dart';
import '../../../models/tasa_registro.dart';
import '../../../models/venta.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';

enum AbonoStatus { editando, procesando, terminado }

/// Estado inmutable del diálogo "Abono a Venta".
class AbonoState extends Equatable {
  final AbonoStatus status;

  /// La venta tal como está ahora en [SheetsDataService]; `null` si se anuló
  /// mientras el diálogo estaba abierto.
  final Venta? venta;
  final List<MetodoPago> metodosPago;
  final String? selectedMetodoPagoId;
  final TasaRegistro? tasaAutomatica;
  final TasaRegistro? tasaManual;
  final bool usarTasaManual;

  /// Error de validación del monto, o de la operación.
  final String? errorMonto;
  final String? errorMessage;

  /// Resultado del guardado (con [AbonoStatus.terminado]).
  final ResultadoAbono? resultado;

  /// Si el monto supera la deuda, lo que sobra (USD). La vista pide
  /// confirmación antes de guardarlo como saldo a favor. Transitorio, como
  /// [errorMessage].
  final double? excedentePorConfirmar;

  const AbonoState({
    this.status = AbonoStatus.editando,
    this.venta,
    this.metodosPago = const [],
    this.selectedMetodoPagoId,
    this.tasaAutomatica,
    this.tasaManual,
    this.usarTasaManual = false,
    this.errorMonto,
    this.errorMessage,
    this.resultado,
    this.excedentePorConfirmar,
  });

  bool get isProcessing => status == AbonoStatus.procesando;

  /// Firma de los métodos de pago: si cambia con el menú abierto, la vista
  /// lo cierra (un menú abierto no actualiza sus opciones).
  int get metodosPagoVersion =>
      Object.hashAll(metodosPago.map((m) => Object.hash(m.id, m.nombre)));

  AbonoState copyWith({
    AbonoStatus? status,
    String? selectedMetodoPagoId,
    bool? usarTasaManual,
    String? errorMonto,
    bool clearErrorMonto = false,
    String? errorMessage,
    ResultadoAbono? resultado,
    double? excedentePorConfirmar,
  }) {
    return AbonoState(
      status: status ?? this.status,
      venta: venta,
      metodosPago: metodosPago,
      selectedMetodoPagoId: selectedMetodoPagoId ?? this.selectedMetodoPagoId,
      tasaAutomatica: tasaAutomatica,
      tasaManual: tasaManual,
      usarTasaManual: usarTasaManual ?? this.usarTasaManual,
      errorMonto: clearErrorMonto ? null : (errorMonto ?? this.errorMonto),
      errorMessage: errorMessage,
      resultado: resultado ?? this.resultado,
      excedentePorConfirmar: excedentePorConfirmar,
    );
  }

  @override
  List<Object?> get props => [
        status,
        venta?.id,
        venta?.abonoUsd,
        venta?.deudaUsd,
        metodosPagoVersion,
        selectedMetodoPagoId,
        tasaAutomatica?.valor,
        tasaManual?.valor,
        usarTasaManual,
        errorMonto,
        errorMessage,
        resultado,
        excedentePorConfirmar,
      ];
}
