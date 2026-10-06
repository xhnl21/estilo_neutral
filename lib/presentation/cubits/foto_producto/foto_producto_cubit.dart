import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:gal/gal.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/logger.dart';
import '../../../shared/google_sheets/sheets_data_service.dart';
import 'foto_producto_state.dart';

/// Cubit del selector de foto de un producto: comprime y sube la foto a la
/// galería ([SheetsDataService.subirFotoGaleria]), espera a que la URL
/// responda, la asigna y la descarga al teléfono.
///
/// Si se pasa [productoId] (producto ya existente), la foto subida se le
/// asigna ([SheetsDataService.actualizarFotoProducto]) aunque el usuario
/// cierre la pantalla mientras sube: la asignación no depende de que el
/// widget siga montado. Sin [productoId] (formulario), la foto solo queda
/// elegida en el estado y se guarda con el producto.
class FotoProductoCubit extends Cubit<FotoProductoState> {
  final SheetsDataService dataService;
  final String? productoId;
  final Dio _dio;

  FotoProductoCubit({
    required this.dataService,
    String? fotoIdInicial,
    this.productoId,
    Dio? dio,
  })  : _dio = dio ?? DioClient().dio,
        super(FotoProductoState(fotoId: fotoIdInicial, fotoUrl: dataService.fotoUrlPorId(fotoIdInicial))) {
    dataService.addListener(_onDataServiceChanged);
  }

  void _onDataServiceChanged() {
    if (isClosed) return;
    final url = dataService.fotoUrlPorId(state.fotoId);
    if (url != state.fotoUrl) emit(state.copyWith(fotoUrl: url));
  }

  void _emitir(FotoProductoState nuevo) {
    if (!isClosed) emit(nuevo);
  }

  /// Comprime (a JPEG; image_picker no reduce los PNG), sube y asigna.
  Future<void> subir({required Uint8List bytes, required String fileName, required String mimeType}) async {
    if (state.procesando) return;
    _emitir(state.copyWith(status: FotoProductoStatus.subiendo));

    var datos = bytes;
    var nombre = fileName;
    var tipo = mimeType;
    try {
      final comprimido = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1600,
        minHeight: 1600,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      if (comprimido.length < bytes.length) {
        datos = comprimido;
        tipo = 'image/jpeg';
        final sinExtension = nombre.contains('.') ? nombre.substring(0, nombre.lastIndexOf('.')) : nombre;
        nombre = '$sinExtension.jpg';
      }
    } catch (_) {
      // Formato no soportado: se sube el original.
    }

    final nuevoFotoId = await dataService.subirFotoGaleria(bytes: datos, fileName: nombre, mimeType: tipo);
    if (nuevoFotoId == null) {
      _emitir(state.copyWith(
        status: FotoProductoStatus.listo,
        mensaje: 'No se pudo subir la foto. Probá de nuevo.',
        mensajeEsError: true,
      ));
      return;
    }

    // Se asigna antes de cualquier chequeo de isClosed (ver doc de la clase).
    final errorAsignando = await _asignar(nuevoFotoId);

    // El CDN de Drive tarda unos segundos en servir un archivo nuevo: se
    // espera a que responda para no mostrar el ícono de error de entrada.
    _emitir(state.copyWith(status: FotoProductoStatus.verificando));
    final url = dataService.fotoUrlPorId(nuevoFotoId);
    if (!isClosed) await _esperarUrlDisponible(url);
    _emitir(state.copyWith(
      status: FotoProductoStatus.listo,
      fotoId: nuevoFotoId,
      fotoUrl: url,
      mensaje: errorAsignando ?? 'Foto subida correctamente.',
      mensajeEsError: errorAsignando != null,
    ));
  }

  Future<void> quitar() async {
    if (state.procesando) return;
    final errorAsignando = await _asignar(null);
    if (errorAsignando != null) {
      _emitir(state.copyWith(mensaje: errorAsignando, mensajeEsError: true));
      return;
    }
    _emitir(state.copyWith(quitarFoto: true));
  }

  /// Devuelve el mensaje de error si la asignación falló.
  Future<String?> _asignar(String? fotoId) async {
    final id = productoId;
    if (id == null) return null;
    try {
      await dataService.actualizarFotoProducto(id, fotoId);
      return null;
    } catch (e) {
      Logger.error('FotoProductoCubit: no se pudo asignar la foto $fotoId', e);
      return 'La foto se subió a la galería, pero no se pudo asignar al producto.';
    }
  }

  Future<void> _esperarUrlDisponible(String? url) async {
    if (url == null || url.isEmpty) return;
    for (var intento = 0; intento < 5 && !isClosed; intento++) {
      try {
        final response = await _dio.get(url, options: Options(receiveTimeout: const Duration(seconds: 5)));
        if (response.statusCode == 200) return;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> descargar() async {
    final url = state.fotoUrl;
    if (state.procesando || url == null || url.isEmpty) return;
    _emitir(state.copyWith(status: FotoProductoStatus.descargando));
    try {
      final response = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
      if (response.statusCode != 200 || response.data == null) {
        _emitir(state.copyWith(
            status: FotoProductoStatus.listo, mensaje: 'No se pudo descargar la foto.', mensajeEsError: true));
        return;
      }
      await Gal.putImageBytes(Uint8List.fromList(response.data!));
      _emitir(state.copyWith(status: FotoProductoStatus.listo, mensaje: 'Foto guardada en tu galería.'));
    } catch (_) {
      _emitir(state.copyWith(
          status: FotoProductoStatus.listo, mensaje: 'No se pudo descargar la foto.', mensajeEsError: true));
    }
  }

  /// Mensaje ya mostrado: se limpia para poder repetir el mismo.
  void mensajeMostrado() {
    if (state.mensaje != null) _emitir(state.copyWith());
  }

  @override
  Future<void> close() {
    dataService.removeListener(_onDataServiceChanged);
    return super.close();
  }
}
