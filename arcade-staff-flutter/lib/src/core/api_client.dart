import 'package:dio/dio.dart';
import 'config.dart';

class ApiClient {
  final Dio _dio;
  String? _token;
  Future<void> Function(String token)? _onSessionToken;
  Future<void> Function()? _onUnauthorized;
  bool _isHandlingUnauthorized = false;

  static const _sessionTokenHeader = 'x-staff-session-token';

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
        onResponse: (response, handler) async {
          final rotatedToken = response.headers.value(_sessionTokenHeader);
          if (rotatedToken != null &&
              rotatedToken.isNotEmpty &&
              rotatedToken != _token) {
            _token = rotatedToken;
            final onSessionToken = _onSessionToken;
            if (onSessionToken != null) {
              await onSessionToken(rotatedToken);
            }
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          if (status == 401 && !_isHandlingUnauthorized) {
            _isHandlingUnauthorized = true;
            try {
              final onUnauthorized = _onUnauthorized;
              if (onUnauthorized != null) {
                await onUnauthorized();
              }
            } finally {
              _isHandlingUnauthorized = false;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  void setToken(String? token) => _token = token;

  String? getToken() => _token;

  void setSessionHandlers({
    Future<void> Function(String token)? onSessionToken,
    Future<void> Function()? onUnauthorized,
  }) {
    _onSessionToken = onSessionToken;
    _onUnauthorized = onUnauthorized;
  }

  Future<Map<String, dynamic>> postJson(
      String path, Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getJson(String path,
      {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> patchJson(
      String path, Map<String, dynamic> body) async {
    final res = await _dio.patch(path, data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
