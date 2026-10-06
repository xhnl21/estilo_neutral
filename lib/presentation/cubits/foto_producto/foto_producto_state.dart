import 'package:equatable/equatable.dart';

enum FotoProductoStatus { listo, subiendo, verificando, descargando }

/// Estado inmutable del selector de foto de un producto.
class FotoProductoState extends Equatable {
  final FotoProductoStatus status;

  /// Foto elegida (fila de "galeria"), o `null` si no hay.
  final String? fotoId;

  /// URL pública de [fotoId] según los datos actuales.
  final String? fotoUrl;

  /// Mensaje a mostrar una vez (transitorio).
  final String? mensaje;
  final bool mensajeEsError;

  const FotoProductoState({
    this.status = FotoProductoStatus.listo,
    this.fotoId,
    this.fotoUrl,
    this.mensaje,
    this.mensajeEsError = false,
  });

  bool get procesando => status != FotoProductoStatus.listo;
  bool get tieneFoto => fotoUrl != null && fotoUrl!.isNotEmpty;

  FotoProductoState copyWith({
    FotoProductoStatus? status,
    String? fotoId,
    bool quitarFoto = false,
    String? fotoUrl,
    String? mensaje,
    bool mensajeEsError = false,
  }) {
    return FotoProductoState(
      status: status ?? this.status,
      fotoId: quitarFoto ? null : (fotoId ?? this.fotoId),
      fotoUrl: quitarFoto ? null : (fotoUrl ?? this.fotoUrl),
      mensaje: mensaje,
      mensajeEsError: mensajeEsError,
    );
  }

  @override
  List<Object?> get props => [status, fotoId, fotoUrl, mensaje, mensajeEsError];
}
