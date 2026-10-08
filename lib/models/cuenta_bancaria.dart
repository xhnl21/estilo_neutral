import 'package:equatable/equatable.dart';

import 'fila_hoja.dart';

/// Banco del catálogo común (hoja `bancos`), con su código SUDEBAN: los 4
/// primeros dígitos de cualquier cuenta de ese banco.
///
/// | A id | B codigo | C nombre | D status |
class Banco extends Equatable {
  /// Formato `bn00000001` (lo genera el servidor).
  final String id;
  final String codigo;
  final String nombre;
  final bool activo;

  const Banco(
      {required this.id,
      required this.codigo,
      required this.nombre,
      this.activo = true});

  factory Banco.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'bn');
    final codigo = f.texto(0).replaceFirst(RegExp("^'"), '');
    return Banco(
      id: f.id,
      // Sheets pudo convertir "0102" en 102: se reponen los ceros.
      codigo: RegExp(r'^\d{1,4}$').hasMatch(codigo)
          ? codigo.padLeft(4, '0')
          : codigo,
      nombre: f.texto(1),
      activo: estadoActivo(f.texto(2)),
    );
  }

  /// "0134 · Banesco".
  String get etiqueta => '$codigo · $nombre';

  @override
  List<Object?> get props => [id, codigo, nombre, activo];
}

/// Cómo se paga a la cuenta.
enum TipoCuentaBancaria {
  transferencia('transferencia', 'Transferencia'),
  pagoMovil('pago_movil', 'Pago móvil');

  /// Valor en la hoja.
  final String valor;
  final String etiqueta;

  const TipoCuentaBancaria(this.valor, this.etiqueta);

  static TipoCuentaBancaria? desde(String valor) {
    for (final t in values) {
      if (t.valor == valor.trim().toLowerCase()) return t;
    }
    return null;
  }
}

/// Tipo de cuenta para transferencias.
enum ModalidadCuenta {
  corriente('corriente', 'Corriente'),
  ahorro('ahorro', 'Ahorro');

  final String valor;
  final String etiqueta;

  const ModalidadCuenta(this.valor, this.etiqueta);

  static ModalidadCuenta? desde(String valor) {
    for (final m in values) {
      if (m.valor == valor.trim().toLowerCase()) return m;
    }
    return null;
  }
}

/// Dato bancario de una organización (hoja `cuentas_bancarias`): una cuenta
/// para transferencias o un pago móvil.
///
/// | A id | B organizacion_id | C tipo | D banco_id | E titular |
/// | F tipo_documento | G documento | H numero_cuenta | I tipo_cuenta |
/// | J telefono | K status | L actualizado_en |
class CuentaBancaria extends Equatable {
  /// Formato `cb00000001` (lo genera el servidor); vacío hasta que confirma.
  final String id;
  final String organizacionId;
  final TipoCuentaBancaria tipo;
  final String bancoId;
  final String titular;
  final String tipoDocumento;

  /// Normalizado, sin guiones ni puntos: `12345678`, `123456789` (RIF).
  final String documento;

  /// 20 dígitos (solo transferencia).
  final String numeroCuenta;
  final ModalidadCuenta? modalidad;

  /// Celular local de 11 dígitos, `04121234567` (solo pago móvil).
  final String telefono;
  final bool activa;
  final String actualizadoEn;

  const CuentaBancaria({
    required this.id,
    required this.organizacionId,
    required this.tipo,
    required this.bancoId,
    required this.titular,
    required this.tipoDocumento,
    required this.documento,
    this.numeroCuenta = '',
    this.modalidad,
    this.telefono = '',
    this.activa = true,
    this.actualizadoEn = '',
  });

  /// Una fila con un tipo ilegible no se puede mostrar bien: devuelve `null`.
  static CuentaBancaria? fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'cb');
    String texto(int i) => f.texto(i).replaceFirst(RegExp("^'"), '');
    final tipo = TipoCuentaBancaria.desde(texto(1));
    if (f.id.isEmpty || tipo == null) return null;
    var telefono = texto(8).replaceAll(RegExp(r'\D'), '');
    // Sheets pudo quitarle el 0 inicial al guardarlo como número.
    if (telefono.length == 10 && telefono.startsWith('4')) {
      telefono = '0$telefono';
    }
    return CuentaBancaria(
      id: f.id,
      organizacionId: texto(0),
      tipo: tipo,
      bancoId: texto(2),
      titular: texto(3),
      tipoDocumento: texto(4).toUpperCase(),
      documento: texto(5),
      numeroCuenta: texto(6).replaceAll(RegExp(r'\D'), ''),
      modalidad: ModalidadCuenta.desde(texto(7)),
      telefono: telefono,
      activa: estadoActivo(texto(9)),
      actualizadoEn: texto(10),
    );
  }

  /// `0134-0001-23-4567890123` (banco-oficina-control-cuenta).
  String get numeroCuentaLegible => numeroCuenta.length == 20
      ? '${numeroCuenta.substring(0, 4)}-${numeroCuenta.substring(4, 8)}-'
          '${numeroCuenta.substring(8, 10)}-${numeroCuenta.substring(10)}'
      : numeroCuenta;

  /// `0412-1234567`.
  String get telefonoLegible => telefono.length == 11
      ? '${telefono.substring(0, 4)}-${telefono.substring(4)}'
      : telefono;

  /// Texto para pasarle a un cliente (copiar y pegar en un chat).
  String textoParaCompartir({Banco? banco, required String documentoLegible}) {
    final nombreBanco =
        banco == null ? 'Banco' : '${banco.nombre} (${banco.codigo})';
    final etiquetaDoc =
        tipoDocumento == 'J' || tipoDocumento == 'G' ? 'RIF' : 'Cédula';
    return switch (tipo) {
      TipoCuentaBancaria.transferencia => [
          nombreBanco,
          'Cuenta ${modalidad?.etiqueta.toLowerCase() ?? ''}: $numeroCuentaLegible'
              .replaceAll('  ', ' '),
          'Titular: $titular',
          '$etiquetaDoc: $documentoLegible',
        ].join('\n'),
      TipoCuentaBancaria.pagoMovil => [
          'Pago móvil',
          'Banco: $nombreBanco',
          'Teléfono: $telefonoLegible',
          '$etiquetaDoc: $documentoLegible',
          'Titular: $titular',
        ].join('\n'),
    };
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'organizacion_id': organizacionId,
        'tipo': tipo.valor,
        'banco_id': bancoId,
        'titular': titular,
        'tipo_documento': tipoDocumento,
        'documento': documento,
        'numero_cuenta':
            tipo == TipoCuentaBancaria.transferencia ? numeroCuenta : '',
        'tipo_cuenta': tipo == TipoCuentaBancaria.transferencia
            ? (modalidad?.valor ?? '')
            : '',
        'telefono': tipo == TipoCuentaBancaria.pagoMovil ? telefono : '',
        'status': activa,
      };

  CuentaBancaria copyWith({String? id, bool? activa, String? actualizadoEn}) =>
      CuentaBancaria(
        id: id ?? this.id,
        organizacionId: organizacionId,
        tipo: tipo,
        bancoId: bancoId,
        titular: titular,
        tipoDocumento: tipoDocumento,
        documento: documento,
        numeroCuenta: numeroCuenta,
        modalidad: modalidad,
        telefono: telefono,
        activa: activa ?? this.activa,
        actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      );

  @override
  List<Object?> get props => [
        id,
        organizacionId,
        tipo,
        bancoId,
        titular,
        tipoDocumento,
        documento,
        numeroCuenta,
        modalidad,
        telefono,
        activa,
        actualizadoEn,
      ];
}
