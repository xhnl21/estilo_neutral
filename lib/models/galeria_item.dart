/// Modelo de entidad GaleriaItem mapeado desde la hoja "galeria".
/// Catálogo de fotos subidas a Google Drive — la única hoja que guarda la
/// URL real de una imagen. Cualquier otra hoja que necesite una foto (hoy
/// solo `inventario`) guarda una clave foránea (`foto_id`) hacia acá, nunca
/// la URL directa: así, si el producto que usa una foto ya fue vendido
/// alguna vez, la foto en esta galería nunca se borra ni se pisa — solo se
/// agregan filas nuevas cuando alguien sube una foto distinta.
class GaleriaItem {
  /// Columna A: ID único (formato g00000001)
  final String id;

  /// Columna B: URL directa de la imagen en Google Drive
  /// (https://lh3.googleusercontent.com/d/{fileId})
  final String url;

  /// Columna C: ID del archivo en Google Drive (para referencia/soporte)
  final String driveFileId;

  /// Columna D: Nombre original del archivo subido
  final String nombreArchivo;

  /// Columna E: Fecha y hora de la subida
  final DateTime fechaSubida;

  const GaleriaItem({
    required this.id,
    required this.url,
    required this.driveFileId,
    required this.nombreArchivo,
    required this.fechaSubida,
  });

  factory GaleriaItem.fromRow(List<dynamic> row) {
    return GaleriaItem(
      id: row.isNotEmpty ? row[0].toString().trim() : '',
      url: row.length > 1 ? row[1].toString().trim() : '',
      driveFileId: row.length > 2 ? row[2].toString().trim() : '',
      nombreArchivo: row.length > 3 ? row[3].toString().trim() : '',
      fechaSubida: row.length > 4 ? DateTime.tryParse(row[4].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'drive_file_id': driveFileId,
      'nombre_archivo': nombreArchivo,
      'fecha_subida': fechaSubida.toIso8601String(),
    };
  }
}
