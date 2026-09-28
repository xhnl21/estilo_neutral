/// Modelo de entidad Tipo de Documento mapeado desde la hoja "tipo de documento".
class TipoDocumento {
  final String id;
  final String tipo;
  final String descripcion;
  final bool status;

  const TipoDocumento({
    required this.id,
    required this.tipo,
    required this.descripcion,
    this.status = true,
  });

  factory TipoDocumento.fromRow(List<dynamic> row) {
    return TipoDocumento(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      tipo: row.length > 1 ? row[1].toString().trim().toUpperCase() : '',
      descripcion: row.length > 2 ? row[2].toString().trim() : '',
      status: row.length > 3
          ? (row[3].toString().trim().toLowerCase() == 'true' || row[3] == true)
          : true,
    );
  }

  List<dynamic> toRow() {
    return [id, tipo, descripcion, status];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'descripcion': descripcion,
      'status': status,
    };
  }

  TipoDocumento copyWith({
    String? id,
    String? tipo,
    String? descripcion,
    bool? status,
  }) {
    return TipoDocumento(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      status: status ?? this.status,
    );
  }
}
