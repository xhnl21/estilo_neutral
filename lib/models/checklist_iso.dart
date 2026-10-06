import 'fila_hoja.dart';

/// Modelo de entidad ChecklistISO mapeado desde la hoja "checklist_iso"
/// Entidad de SOLO LECTURA (Verificación formal de 20 controles de auditoría)
class ChecklistISO {
  /// ID generado por el servidor (ck00000001). Vacío si aún no se confirmó.
  final String id;

  /// Columna A: Número secuencial del control (1..20)
  final int nro;

  /// Columna B: Descripción del control de auditoría
  final String control;

  /// Columna C: Norma de referencia (ISO 27001, ISO 8000, ISO 8601, etc.)
  final String norma;

  /// Columna D: Estado de cumplimiento ('☑' / '☐' / 'N/A')
  final String estado;

  /// Columna E: Evidencia comprobable o referencia de celda
  final String evidencia;

  /// Columna F: Timestamp ISO 8601 de verificación
  final DateTime timestamp;

  /// Columna G: Identificador de la organización a la que pertenece el registro
  final String organizacionId;

  const ChecklistISO({
    this.id = '',
    required this.nro,
    required this.control,
    required this.norma,
    required this.estado,
    required this.evidencia,
    required this.timestamp,
    this.organizacionId = '67774411-6aa1-4aa3-a4b2-d3fc6913b768',
  });

  /// Errores de validación por campo (vacío si es válido).
  Map<String, String> get errores => {
        if (control.trim().isEmpty) 'control': 'Describí el control.',
        if (norma.trim().isEmpty) 'norma': 'Indicá la norma o estándar.',
      };

  factory ChecklistISO.fromRow(List<dynamic> row) {
    final f = FilaHoja.leer(row, 'ck');
    return ChecklistISO(
      id: f.id,
      nro: int.tryParse(f.texto(0)) ?? 0,
      control: f.crudo(1),
      norma: f.crudo(2),
      estado: f.texto(3).isEmpty ? '☐' : f.texto(3),
      evidencia: f.crudo(4),
      timestamp: DateTime.tryParse(f.texto(5)) ?? DateTime.now(),
      organizacionId: f.texto(6).isNotEmpty ? f.texto(6) : organizacionPorDefecto,
    );
  }

  ChecklistISO copyWith({
    String? id,
    int? nro,
    String? control,
    String? norma,
    String? estado,
    String? evidencia,
    DateTime? timestamp,
    String? organizacionId,
  }) {
    return ChecklistISO(
      id: id ?? this.id,
      nro: nro ?? this.nro,
      control: control ?? this.control,
      norma: norma ?? this.norma,
      estado: estado ?? this.estado,
      evidencia: evidencia ?? this.evidencia,
      timestamp: timestamp ?? this.timestamp,
      organizacionId: organizacionId ?? this.organizacionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'nro': nro,
      'control': control,
      'norma': norma,
      'estado': estado,
      'evidencia': evidencia,
      'timestamp': timestamp.toIso8601String(),
      'organizacion_id': organizacionId,
    };
  }
}
