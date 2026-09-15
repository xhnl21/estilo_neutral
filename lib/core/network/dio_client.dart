import 'package:dio/dio.dart';
import '../utils/logger.dart';

/// Cliente HTTP centralizado basado en Dio con interceptor de Logging seguro y sanitizado.
class DioClient {
  final Dio dio;

  DioClient({
    Dio? customDio,
    BaseOptions? baseOptions,
  }) : dio = customDio ??
            Dio(
              baseOptions ??
                  BaseOptions(
                    connectTimeout: const Duration(seconds: 15),
                    receiveTimeout: const Duration(seconds: 20),
                    sendTimeout: const Duration(seconds: 15),
                    headers: {
                      'Content-Type': 'application/json',
                      'Accept': 'application/json',
                    },
                    followRedirects: true,
                    maxRedirects: 5,
                    validateStatus: (status) => status != null && status < 500,
                  ),
            ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          Logger.api('${options.method} ${options.uri}', isRequest: true);
          if (options.data != null) {
            Logger.object('Request Data [${options.method}]', options.data);
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          Logger.api(
            '${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}',
            isRequest: false,
          );
          if (response.data != null && Logger.isLoggingEnabled) {
            Logger.object('Response Data [${response.statusCode}]', response.data);
          }
          return handler.next(response);
        },
        onError: (DioException err, handler) {
          Logger.error(
            'Dio Error [${err.type}]: ${err.message} (${err.requestOptions.uri})',
            err.error,
            err.stackTrace,
          );
          return handler.next(err);
        },
      ),
    );
  }

  /// Petición GET
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Petición POST
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Petición PUT
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Petición DELETE
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
