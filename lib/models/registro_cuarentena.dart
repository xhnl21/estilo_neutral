import 'dart:convert';
import 'fila_hoja.dart';

/// Modelo de entidad RegistroCuarentena mapeado desde la hoja "cuarentena"
/// Entidad de SOLO LECTURA (Preservación forense COBIT 2019 DSS05 / NIST SP 800-53)
class RegistroCuarentena {
  /// ID generado por el servidor (cq00000001). Vacío si aún no se confirmó.
  final String id;

  /// Columna A: ID original previo a la normalización
  final String idRegistroOriginal;

  /// Columna B: Hoja donde residía originalmente la fila
  final String hojaOrigen;

  /// Columna C: Fecha y hora de detección
  final DateTime fechaDeteccion;

  /// Columna D: Motivo de la puesta en cuarentena
  final String motivoCuarentena;

  /// Columna E: Payload JSON original íntegro
  final String datosOriginalesJson;

  /// Columna F: Estado de resolución (CONSOLIDADO, CORREGIDO)
  final String estado;

  /// Columna G: Explicación de la resolución
  final String resolucion;

  /// Columna H: Hash SHA-256 inmutable de la evidencia
  final String hashEvidencia;

  /// Columna I: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const RegistroCuarentena({
    this.id = '',
    required this.idRegistroOriginal,
    required this.hojaOrigen,
    required this.fechaDeteccion,
    required this.motivoCuarentena,
    required this.datosOriginalesJson,
    required this.estado,
    required this.resolucion,
    required this.hashEvidencia,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  static const estadosValidos = ['PENDIENTE', 'CORREGIDO', 'CONSOLIDADO'];

  /// Errores de validación por campo (vacío si es válido). Los usan el
  /// formulario (mensaje en cada campo) y el servicio (rechaza lo inválido).
  Map<String, String> get errores {
    bool jsonValido() {
      try {
        jsonDecode(datosOriginalesJson);
        return true;
      } catch (_) {
        return false;
      }
    }

    return {
      if (idRegistroOriginal.trim().isEmpty) 'idRegistroOriginal': 'Indicá el ID del registro afectado.',
      if (hojaOrigen.trim().isEmpty) 'hojaOrigen': 'Indicá la hoja de origen.',
      if (motivoCuarentena.trim().isEmpty) 'motivoCuarentena': 'Indicá el motivo de la cuarentena.',
      if (datosOriginalesJson.trim().isEmpty)
        'datosOriginalesJson': 'Pegá los datos originales (JSON).'
      else if (!jsonValido())
        'datosOriginalesJson': 'Los datos originales no son un JSON válido.',
      if (!estadosValidos.contains(estado.trim().toUpperCase()))
        'estado': 'Usá PENDIENTE, CORREGIDO o CONSOLIDADO.',
    };
  }

  factory RegistroCuarentena.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'cq');
    return RegistroCuarentena(
      id: f.id,
      idRegistroOriginal: f.texto(0),
      hojaOrigen: f.texto(1),
      fechaDeteccion: DateTime.tryParse(f.texto(2)) ?? DateTime.now(),
      motivoCuarentena: f.crudo(3),
      datosOriginalesJson: f.crudo(4),
      estado: f.texto(5),
      resolucion: f.crudo(6),
      hashEvidencia: f.texto(7),
      organizacionId: f.texto(8).isNotEmpty ? f.texto(8) : organizacionPorDefecto,
    );
  }

  RegistroCuarentena copyWith({
    String? id,
    String? idRegistroOriginal,
    String? hojaOrigen,
    DateTime? fechaDeteccion,
    String? motivoCuarentena,
    String? datosOriginalesJson,
    String? estado,
    String? resolucion,
    String? hashEvidencia,
    String? organizacionId,
  }) {
    return RegistroCuarentena(
      id: id ?? this.id,
      idRegistroOriginal: idRegistroOriginal ?? this.idRegistroOriginal,
      hojaOrigen: hojaOrigen ?? this.hojaOrigen,
      fechaDeteccion: fechaDeteccion ?? this.fechaDeteccion,
      motivoCuarentena: motivoCuarentena ?? this.motivoCuarentena,
      datosOriginalesJson: datosOriginalesJson ?? this.datosOriginalesJson,
      estado: estado ?? this.estado,
      resolucion: resolucion ?? this.resolucion,
      hashEvidencia: hashEvidencia ?? this.hashEvidencia,
      organizacionId: organizacionId ?? this.organizacionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'id_registro_original': idRegistroOriginal,
      'hoja_origen': hojaOrigen,
      'fecha_deteccion': fechaDeteccion.toIso8601String(),
      'motivo_cuarentena': motivoCuarentena,
      'datos_originales_json': datosOriginalesJson,
      'estado': estado,
      'resolucion': resolucion,
      'hash_evidencia': hashEvidencia,
      'organizacion_id': organizacionId,
    };
  }
}
