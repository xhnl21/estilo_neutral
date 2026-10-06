import 'fila_hoja.dart';

/// Modelo de entidad ReporteMigracion mapeado desde la hoja "reporte_migracion"
/// Entidad de SOLO LECTURA
class ReporteMigracion {
  /// ID generado por el servidor (rm00000001). Vacío si aún no se confirmó.
  final String id;

  /// Columna A: Control o Métrica auditada
  final String metrica;

  /// Columna B: Valor o Estado obtenido
  final String valorEstado;

  /// Columna C: Norma aplicada
  final String normaAplicada;

  /// Columna D: Observaciones técnicas
  final String observaciones;

  /// Columna E: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const ReporteMigracion({
    this.id = '',
    required this.metrica,
    required this.valorEstado,
    required this.normaAplicada,
    required this.observaciones,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  /// Errores de validación por campo (vacío si es válido).
  Map<String, String> get errores => {
        if (metrica.trim().isEmpty) 'metrica': 'Indicá la métrica o el control.',
        if (valorEstado.trim().isEmpty) 'valorEstado': 'Indicá el valor o estado medido.',
      };

  factory ReporteMigracion.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'rm');
    return ReporteMigracion(
      id: f.id,
      metrica: f.crudo(0),
      valorEstado: f.crudo(1),
      normaAplicada: f.crudo(2),
      observaciones: f.crudo(3),
      organizacionId: f.texto(4).isNotEmpty ? f.texto(4) : organizacionPorDefecto,
    );
  }

  ReporteMigracion copyWith({
    String? id,
    String? metrica,
    String? valorEstado,
    String? normaAplicada,
    String? observaciones,
    String? organizacionId,
  }) {
    return ReporteMigracion(
      id: id ?? this.id,
      metrica: metrica ?? this.metrica,
      valorEstado: valorEstado ?? this.valorEstado,
      normaAplicada: normaAplicada ?? this.normaAplicada,
      observaciones: observaciones ?? this.observaciones,
      organizacionId: organizacionId ?? this.organizacionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'metrica': metrica,
      'valor_estado': valorEstado,
      'norma_aplicada': normaAplicada,
      'observaciones': observaciones,
      'organizacion_id': organizacionId,
    };
  }
}
