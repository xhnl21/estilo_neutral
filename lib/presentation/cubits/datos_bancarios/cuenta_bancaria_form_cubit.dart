import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../models/cuenta_bancaria.dart';
import '../../../models/documento_identidad.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';

/// Campos validables del formulario de un dato bancario.
enum CampoCuenta { banco, titular, documento, numeroCuenta, modalidad, telefono }

/// Estado del formulario de alta/edición de un dato bancario.
class CuentaBancariaFormState extends Equatable {
  final TipoCuentaBancaria tipo;
  final String? bancoId;
  final String tipoDocumento;
  final ModalidadCuenta? modalidad;
  final String codigoTelefono;
  final bool activa;

  /// Bancos activos (más el de la cuenta, aunque esté inactivo).
  final List<Banco> bancos;
  final List<String> tiposDocumento;
  final List<String> codigosTelefono;

  final Map<CampoCuenta, String> errores;
  final bool guardando;
  final bool guardada;

  /// Error del servidor (transitorio).
  final String? errorMessage;

  const CuentaBancariaFormState({
    this.tipo = TipoCuentaBancaria.transferencia,
    this.bancoId,
    this.tipoDocumento = 'J',
    this.modalidad,
    this.codigoTelefono = '0414',
    this.activa = true,
    this.bancos = const [],
    this.tiposDocumento = const [],
    this.codigosTelefono = const [],
    this.errores = const {},
    this.guardando = false,
    this.guardada = false,
    this.errorMessage,
  });

  Banco? get banco => bancos.where((b) => b.id == bancoId).firstOrNull;

  CuentaBancariaFormState copyWith({
    TipoCuentaBancaria? tipo,
    String? bancoId,
    String? tipoDocumento,
    ModalidadCuenta? modalidad,
    String? codigoTelefono,
    bool? activa,
    List<Banco>? bancos,
    List<String>? tiposDocumento,
    List<String>? codigosTelefono,
    Map<CampoCuenta, String>? errores,
    bool? guardando,
    bool? guardada,
    String? errorMessage,
  }) =>
      CuentaBancariaFormState(
        tipo: tipo ?? this.tipo,
        bancoId: bancoId ?? this.bancoId,
        tipoDocumento: tipoDocumento ?? this.tipoDocumento,
        modalidad: modalidad ?? this.modalidad,
        codigoTelefono: codigoTelefono ?? this.codigoTelefono,
        activa: activa ?? this.activa,
        bancos: bancos ?? this.bancos,
        tiposDocumento: tiposDocumento ?? this.tiposDocumento,
        codigosTelefono: codigosTelefono ?? this.codigosTelefono,
        errores: errores ?? this.errores,
        guardando: guardando ?? this.guardando,
        guardada: guardada ?? this.guardada,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props => [
        tipo, bancoId, tipoDocumento, modalidad, codigoTelefono, activa, bancos, tiposDocumento,
        codigosTelefono, errores, guardando, guardada, errorMessage,
      ];
}

/// Alta y edición de un dato bancario (transferencia o pago móvil). Los
/// textos (titular, documento, cuenta, número de teléfono) llegan de los
/// controladores de la vista al guardar; las elecciones viven acá.
class CuentaBancariaFormCubit extends Cubit<CuentaBancariaFormState> {
  final SheetsDataService dataService;

  /// `null` = dato bancario nuevo.
  final CuentaBancaria? cuenta;

  CuentaBancariaFormCubit({required this.dataService, this.cuenta})
      : super(cuenta == null
            ? const CuentaBancariaFormState()
            : CuentaBancariaFormState(
                tipo: cuenta.tipo,
                bancoId: cuenta.bancoId,
                tipoDocumento: cuenta.tipoDocumento,
                modalidad: cuenta.modalidad,
                codigoTelefono: cuenta.telefono.length == 11 ? cuenta.telefono.substring(0, 4) : '0414',
                activa: cuenta.activa,
              )) {
    dataService.addListener(_onDataServiceChanged);
    _syncFromService();
  }

  bool get esEdicion => cuenta != null;

  void _onDataServiceChanged() {
    if (!isClosed) _syncFromService();
  }

  void _syncFromService() {
    final bancos = dataService.bancos.where((b) => b.activo || b.id == cuenta?.bancoId).toList()
      ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    final tipos = List.of(dataService.tiposDocumentoActivos);
    if (!tipos.contains(state.tipoDocumento)) tipos.add(state.tipoDocumento);
    final codigos = List.of(dataService.codigosTelefonoActivos);
    if (!codigos.contains(state.codigoTelefono)) codigos.add(state.codigoTelefono);
    emit(state.copyWith(bancos: bancos, tiposDocumento: tipos, codigosTelefono: codigos));
  }

  Map<CampoCuenta, String> _sin(CampoCuenta campo) => Map.of(state.errores)..remove(campo);

  void elegirTipo(TipoCuentaBancaria tipo) => emit(state.copyWith(tipo: tipo, errores: const {}));
  void elegirBanco(String id) => emit(state.copyWith(bancoId: id, errores: _sin(CampoCuenta.banco)..remove(CampoCuenta.numeroCuenta)));
  void elegirTipoDocumento(String tipo) => emit(state.copyWith(tipoDocumento: tipo, errores: _sin(CampoCuenta.documento)));
  void elegirModalidad(ModalidadCuenta m) => emit(state.copyWith(modalidad: m, errores: _sin(CampoCuenta.modalidad)));
  void elegirCodigoTelefono(String codigo) => emit(state.copyWith(codigoTelefono: codigo, errores: _sin(CampoCuenta.telefono)));
  void cambiarActiva(bool activa) => emit(state.copyWith(activa: activa));

  /// Limpia el error de un campo cuando se lo vuelve a editar.
  void campoEditado(CampoCuenta campo) {
    if (state.errores.containsKey(campo)) emit(state.copyWith(errores: _sin(campo)));
  }

  Future<void> guardar({
    required String titular,
    required String documento,
    String numeroCuenta = '',
    String numeroTelefono = '',
  }) async {
    if (state.guardando) return;
    final transferencia = state.tipo == TipoCuentaBancaria.transferencia;
    // "J-07013380-5" → "070133805": la letra va en el selector de tipo.
    final doc = DocumentoIdentidad.normalizar(documento).replaceFirst(RegExp(r'^[A-Z](?=\d)'), '');
    final cuentaDigitos = numeroCuenta.replaceAll(RegExp(r'\D'), '');
    final telDigitos = numeroTelefono.replaceAll(RegExp(r'\D'), '');
    final banco = state.banco;

    final errores = <CampoCuenta, String>{
      if (banco == null) CampoCuenta.banco: 'Elegí el banco.',
      if (titular.trim().isEmpty)
        CampoCuenta.titular: 'Escribí el nombre del titular.'
      else if (titular.trim().length > 80)
        CampoCuenta.titular: 'Hasta 80 caracteres.',
      if (DocumentoIdentidad.validar(state.tipoDocumento, doc) case final e?) CampoCuenta.documento: e,
      if (transferencia) ...{
        if (cuentaDigitos.length != 20)
          CampoCuenta.numeroCuenta: 'La cuenta tiene 20 dígitos (tiene ${cuentaDigitos.length}).'
        else if (banco != null && !cuentaDigitos.startsWith(banco.codigo))
          CampoCuenta.numeroCuenta: 'Las cuentas de ${banco.nombre} empiezan con ${banco.codigo}.',
        if (state.modalidad == null) CampoCuenta.modalidad: 'Elegí corriente o ahorro.',
      } else if (telDigitos.length != 7)
        CampoCuenta.telefono: 'El número tiene 7 dígitos.',
    };
    if (errores.isNotEmpty) {
      emit(state.copyWith(errores: errores));
      return;
    }

    final datos = CuentaBancaria(
      id: cuenta?.id ?? '',
      organizacionId: cuenta?.organizacionId ?? '',
      tipo: state.tipo,
      bancoId: banco!.id,
      titular: titular.trim(),
      tipoDocumento: state.tipoDocumento,
      documento: doc,
      numeroCuenta: transferencia ? cuentaDigitos : '',
      modalidad: transferencia ? state.modalidad : null,
      telefono: transferencia ? '' : '${state.codigoTelefono}$telDigitos',
      activa: state.activa,
      actualizadoEn: cuenta?.actualizadoEn ?? '',
    );
    emit(state.copyWith(guardando: true, errores: const {}));
    try {
      if (esEdicion) {
        await dataService.updateCuentaBancaria(datos);
      } else {
        await dataService.addCuentaBancaria(datos);
      }
      if (!isClosed) emit(state.copyWith(guardando: false, guardada: true));
    } catch (e, st) {
      Logger.error('CuentaBancariaFormCubit: no se pudo guardar', e, st);
      if (isClosed) return;
      emit(state.copyWith(
        guardando: false,
        errorMessage: switch (e) {
          StateError(:final message) => message,
          ArgumentError(:final message) => '$message',
          _ => 'No se pudo guardar: $e',
        },
      ));
    }
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
