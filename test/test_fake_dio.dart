import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// Adapter falso de dio para tests que no deben tocar la red real.
///
/// Dentro de un `testWidgets()`, Flutter intercepta el `HttpClient` real
/// (ver [TestWidgetsFlutterBinding]) y una llamada de red real puede volverse
/// lenta o errática en vez de fallar rápido — eso puede hacer que
/// `pumpAndSettle()` nunca se estabilice. Este adapter evita el problema de
/// raíz: nunca sale a la red, responde de inmediato.
///
/// Por defecto responde 400 sin cuerpo (como si el servidor rechazara todo),
/// forzando a `SheetsDataService` a quedarse con los datos semilla locales —
/// exactamente lo que la mayoría de los tests de widgets necesitan. Pasá
/// [onRequest] si un test puntual necesita inspeccionar o responder distinto
/// a una request específica (ver `sheets_data_service_test.dart`).
class FakeHttpClientAdapter implements HttpClientAdapter {
  final void Function(RequestOptions options)? onRequest;
  final int statusCode;
  final String responseBody;

  FakeHttpClientAdapter({
    this.onRequest,
    this.statusCode = 400,
    this.responseBody = '',
  });

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest?.call(options);
    return ResponseBody.fromBytes(
      utf8.encode(responseBody),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

/// Un [Dio] listo para inyectar en `SheetsDataService`/`ServiceLocator` en
/// tests de widgets, sin dependencia de la red real.
Dio buildFakeDio({void Function(RequestOptions options)? onRequest}) {
  return Dio()..httpClientAdapter = FakeHttpClientAdapter(onRequest: onRequest);
}
