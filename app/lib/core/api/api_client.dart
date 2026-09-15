import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';

/// Points at the Mokhtar backend. Override with --dart-define for the Pi:
/// flutter run --dart-define=API_URL=http://192.168.1.50:8000
const kApiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000',
);

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await ref.read(tokenStorageProvider).read();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      debugPrint('API → ${options.method} ${options.path}');
      handler.next(options);
    },
    onResponse: (response, handler) {
      debugPrint('API ← ${response.statusCode} ${response.requestOptions.path}');
      handler.next(response);
    },
    onError: (e, handler) {
      debugPrint('API ✗ ${e.requestOptions.method} ${e.requestOptions.path} '
          '→ ${e.response?.statusCode}: ${e.response?.data ?? e.message}');
      handler.next(e);
    },
  ));

  return dio;
});
