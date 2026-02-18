import 'package:dio/dio.dart';
import 'config.dart';

class ApiClient {
  final Dio _dio;
  String? _token;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBase,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          handler.next(options);
        },
      ),
    );
  }

  void setToken(String? token) => _token = token;

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body) async {
    final res = await _dio.patch(path, data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
