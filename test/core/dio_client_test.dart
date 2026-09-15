import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:estilo_neutral/core/network/dio_client.dart';

void main() {
  test('DioClient initializes with configured timeouts and headers', () {
    final client = DioClient();

    expect(client.dio.options.connectTimeout, equals(const Duration(seconds: 15)));
    expect(client.dio.options.receiveTimeout, equals(const Duration(seconds: 20)));
    expect(client.dio.options.headers['Content-Type'], equals('application/json'));
    expect(client.dio.options.headers['Accept'], equals('application/json'));
    expect(client.dio.interceptors.isNotEmpty, isTrue);
  });

  test('DioClient handles custom Dio instance and custom interceptors', () {
    final customDio = Dio(BaseOptions(baseUrl: 'https://api.test.com'));
    final client = DioClient(customDio: customDio);

    expect(client.dio.options.baseUrl, equals('https://api.test.com'));
  });
}
