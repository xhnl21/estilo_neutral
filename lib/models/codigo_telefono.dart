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

  /// Google Sheets guarda "0414" como el número 414 (y gviz puede devolver
  /// "414.0"): se restaura el 0 inicial. Lo demás queda igual.
  static String normalizarCodigo(String raw) {
    final s = raw.trim().replaceFirst(RegExp(r'\.0+$'), '');
    return RegExp(r'^\d{1,3}$').hasMatch(s) ? s.padLeft(4, '0') : s;
  }

  factory CodigoTelefono.fromRow(List<dynamic> row) {
    return CodigoTelefono(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      codigo: row.length > 1 ? normalizarCodigo(row[1].toString()) : '',
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
