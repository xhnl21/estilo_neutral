/// Modelo de entidad Código de Teléfono mapeado desde la hoja "codigo de telefonos".
class CodigoTelefono {
  final String id;
  final String codigo;
  final bool status;

  const CodigoTelefono({
    required this.id,
    required this.codigo,
    this.status = true,
  });

  factory CodigoTelefono.fromRow(List<dynamic> row) {
    return CodigoTelefono(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      codigo: row.length > 1 ? row[1].toString().trim() : '',
      status: row.length > 2
          ? (row[2].toString().trim().toLowerCase() == 'true' || row[2] == true)
          : true,
    );
  }

  List<dynamic> toRow() {
    return [id, codigo, status];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'status': status,
    };
  }

  CodigoTelefono copyWith({
    String? id,
    String? codigo,
    bool? status,
  }) {
    return CodigoTelefono(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      status: status ?? this.status,
    );
  }
}
