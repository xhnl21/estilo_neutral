import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/resumen_diario.dart';
import '../../../../shared/google_sheets/sheets_data_service.dart';
import 'reporting_state.dart';

class ReportingCubit extends Cubit<ReportingState> {
  final SheetsDataService _dataService;

  ReportingCubit({required SheetsDataService dataService})
      : _dataService = dataService,
        super(const ReportingState()) {
    _dataService.addListener(_onDataChanged);
    _syncFromService();
  }

  void _onDataChanged() {
    if (!isClosed) {
      _syncFromService();
    }
  }

  void _syncFromService() {
    emit(state.copyWith(
      status: ReportingStatus.success,
      resumenesDiarios: List.unmodifiable(_dataService.resumenesDiarios),
      isLoading: _dataService.isLoading,
    ));
  }

  Future<void> refresh() async {
    emit(state.copyWith(isLoading: true));
    try {
      await _dataService.fetchAllSheets();
      if (!isClosed) {
        _syncFromService();
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Error al actualizar cierres diarios: $e',
        ));
      }
    }
  }

  /// Arma un cierre a partir de lo escrito en el formulario. Devuelve el
  /// error de validación (sin fecha "hoy" por defecto ni tasas inventadas),
  /// o el cierre listo para guardar.
  static ({ResumenDiario? resumen, String? error}) construirCierre({
    required String fecha,
    required String nroVentas,
    required String totalBs,
    required String totalUsd,
    required String tasaBcv,
    required String tasaUsd,
    required String usdComprados,
    required String usdVendidos,
  }) {
    final fechaTxt = fecha.trim();
    final fechaParseada = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fechaTxt)
        ? DateTime.tryParse(fechaTxt)
        : null;
    if (fechaParseada == null) {
      return (resumen: null, error: 'Fecha inválida: usá el formato AAAA-MM-DD (ej: 2026-10-06).');
    }

    double? numero(String texto) {
      final t = texto.trim().replaceAll(',', '.');
      return t.isEmpty ? 0.0 : double.tryParse(t);
    }

    final campos = {
      'Total en Bolívares': numero(totalBs),
      'Total USD': numero(totalUsd),
      'Tasa BCV': numero(tasaBcv),
      'Tasa USD': numero(tasaUsd),
      'USD Comprados': numero(usdComprados),
      'USD Vendidos': numero(usdVendidos),
    };
    for (final campo in campos.entries) {
      if (campo.value == null) return (resumen: null, error: '${campo.key}: monto inválido.');
      if (campo.value! < 0) return (resumen: null, error: '${campo.key}: no puede ser negativo.');
    }
    final ventasTxt = nroVentas.trim();
    final ventas = ventasTxt.isEmpty ? 0 : int.tryParse(ventasTxt);
    if (ventas == null || ventas < 0) {
      return (resumen: null, error: 'Nro. Ventas: debe ser un número entero (ej: 3).');
    }

    return (
      resumen: ResumenDiario(
        fecha: fechaParseada,
        nroVentas: ventas,
        totalBs: campos['Total en Bolívares']!,
        totalUsd: campos['Total USD']!,
        tasaBcv: campos['Tasa BCV']!,
        tasaUsd: campos['Tasa USD']!,
        usdComprados: campos['USD Comprados']!,
        usdVendidos: campos['USD Vendidos']!,
      ),
      error: null,
    );
  }

  /// Tasa BCV vigente, para precargar el formulario de un cierre nuevo.
  double? get tasaBcvVigente => _dataService.tasaVigenteEnMonedaBase?.valor;

  Future<void> addResumen(ResumenDiario resumen) => _ejecutar(
        () => _dataService.addResumenDiario(resumen),
        exito: 'Cierre diario registrado y guardado en Google Sheets.',
      );

  Future<void> updateResumen(ResumenDiario resumen) => _ejecutar(
        () => _dataService.updateResumenDiario(resumen),
        exito: 'Cierre diario actualizado en Google Sheets.',
      );

  Future<void> deleteResumen(String id) => _ejecutar(
        () => _dataService.deleteResumenDiario(id),
        exito: 'Cierre diario eliminado.',
      );

  Future<void> _ejecutar(Future<void> Function() operacion, {required String exito}) async {
    try {
      await operacion();
      if (isClosed) return;
      emit(state.copyWith(actionSuccessMessage: exito));
    } catch (e) {
      if (isClosed) return;
      final mensaje = switch (e) {
        StateError(:final message) => message,
        ArgumentError(:final message) => message.toString(),
        _ => e.toString(),
      };
      emit(state.copyWith(errorMessage: mensaje));
    }
  }

  @override
  Future<void> close() {
    _dataService.removeListener(_onDataChanged);
    return super.close();
  }
}
