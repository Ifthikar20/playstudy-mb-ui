import 'package:dio/dio.dart';

import 'token_store.dart';

/// Thin Dio wrapper that talks to the PlayStudy Django API.
///
/// - Base URL is `<apiBaseUrl>/api/v1/`.
/// - Attaches `Authorization: Bearer <access>` to every request (unless the
///   request opts out via `extra: {'noAuth': true}`).
/// - On a 401, transparently refreshes the access token once and retries the
///   original request; if refresh fails, clears tokens so the app logs out.
class ApiClient {
  final Dio dio;
  final TokenStore tokens;

  ApiClient({required String baseUrl, required this.tokens})
      : dio = Dio(
          BaseOptions(
            baseUrl: '$baseUrl/api/v1/',
            connectTimeout: const Duration(seconds: 15),
            // Long enough to cover LLM-bound paths (PDF extraction + chunked
            // generation) when running against the dev backend in eager mode.
            receiveTimeout: const Duration(minutes: 3),
            sendTimeout: const Duration(minutes: 3),
            contentType: 'application/json',
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['noAuth'] != true) {
            final access = await tokens.accessToken();
            if (access != null) {
              options.headers['Authorization'] = 'Bearer $access';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final req = error.requestOptions;
          final is401 = error.response?.statusCode == 401;
          final canRetry =
              req.extra['retried'] != true && req.extra['noAuth'] != true;
          if (is401 && canRetry) {
            final refreshed = await _refresh();
            if (refreshed) {
              req.extra['retried'] = true;
              final access = await tokens.accessToken();
              req.headers['Authorization'] = 'Bearer $access';
              try {
                final response = await dio.fetch(req);
                return handler.resolve(response);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
            await tokens.clear();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _refresh() async {
    final refresh = await tokens.refreshToken();
    if (refresh == null) return false;
    try {
      final response = await dio.post(
        'auth/refresh/',
        data: {'refreshToken': refresh},
        options: Options(extra: {'noAuth': true}),
      );
      await tokens.setAccessToken(response.data['accessToken'] as String);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Pulls a human-readable message out of the API's error envelope:
/// `{"error": {"code": "...", "message": "..."}}`.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message != null) return message.toString();
    }
    return error.message ?? 'Network error. Please try again.';
  }
  return error.toString();
}
