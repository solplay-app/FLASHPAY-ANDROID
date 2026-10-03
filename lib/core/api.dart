import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// URL de l'API Render : flutter run --dart-define=API_URL=https://xxx.onrender.com
const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

const _storage = FlutterSecureStorage();
const tokenKey = 'auth_token';

/// Intercepteur : injecte le jeton, et déclenche la déconnexion sur 401.
class AppInterceptor extends Interceptor {
  AppInterceptor(this.onUnauthorized);
  final void Function() onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: tokenKey);
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final isAuthCall = err.requestOptions.path.startsWith('/auth/');
    if (err.response?.statusCode == 401 && !isAuthCall) onUnauthorized();
    handler.next(err);
  }
}

Dio buildDio(void Function() onUnauthorized) {
  final dio = Dio(BaseOptions(
    baseUrl: apiUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    contentType: 'application/json',
  ));
  dio.interceptors.add(AppInterceptor(onUnauthorized));
  return dio;
}

Future<String?> readToken() => _storage.read(key: tokenKey);
Future<void> saveToken(String t) => _storage.write(key: tokenKey, value: t);
Future<void> clearToken() => _storage.delete(key: tokenKey);

/// Erreur lisible pour l'utilisateur, avec le code métier renvoyé par l'API (KYC_REQUIRED, LIMIT_DAILY…).
class ApiError implements Exception {
  ApiError(this.message, {this.code, this.status, this.data});
  final String message;
  final String? code;
  final int? status;
  final Map<String, dynamic>? data;
  @override
  String toString() => message;

  factory ApiError.from(Object e) {
    if (e is ApiError) return e;
    if (e is DioException) {
      if (e.response?.statusCode == 429) return ApiError('Trop de tentatives, réessayez dans quelques minutes.', status: 429);
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        return ApiError(body['error']?.toString() ?? 'Erreur serveur',
            code: body['code']?.toString(), status: e.response?.statusCode, data: body);
      }
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return ApiError('Connexion impossible. Vérifiez votre réseau.');
      }
    }
    return ApiError('Une erreur est survenue.');
  }
}
