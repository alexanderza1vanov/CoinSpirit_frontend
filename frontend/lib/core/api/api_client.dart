import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({String baseUrl = 'http://localhost:8080'})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $_accessToken';
      }
      handler.next(options);
    }));
  }

  final Dio dio;
  String? _accessToken;

  String? get accessToken => _accessToken;

  void setAccessToken(String token) => _accessToken = token;

  void clearAccessToken() => _accessToken = null;
}
