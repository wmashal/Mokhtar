import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/secure_storage.dart';

class AuthState {
  final String? token;
  final String? role; // 'manager' | 'resident'
  final int? unitId;
  final int? buildingId;

  const AuthState({this.token, this.role, this.unitId, this.buildingId});

  bool get isLoggedIn => token != null;
  bool get isManager => role == 'manager';
}

Map<String, dynamic> _decodeJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return {};
  final payload = parts[1];
  final normalized = base64Url.normalize(payload);
  final decoded = utf8.decode(base64Url.decode(normalized));
  return jsonDecode(decoded) as Map<String, dynamic>;
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return const AuthState();

    // Restore full session from the JWT claims (no network call needed).
    final claims = _decodeJwt(token);
    final exp = claims['exp'] as int?;
    if (exp != null &&
        DateTime.now().millisecondsSinceEpoch > exp * 1000) {
      await ref.read(tokenStorageProvider).clear();
      return const AuthState();
    }

    return AuthState(
      token: token,
      role: claims['role'] as String?,
      unitId: (claims['unit_id'] as num?)?.toInt(),
      buildingId: (claims['building_id'] as num?)?.toInt(),
    );
  }

  Future<void> login(String phone, String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await ref.read(apiClientProvider).post(
        '/auth/login',
        data: {'phone': phone, 'code': code},
      );
      final token = res.data['access_token'] as String;
      await ref.read(tokenStorageProvider).save(token);
      return AuthState(
        token: token,
        role: res.data['role'] as String?,
        unitId: res.data['unit_id'] as int?,
        buildingId: res.data['building_id'] as int?,
      );
    });
  }

  Future<void> logout() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(AuthState());
  }

  String? errorMessage() {
    final err = state.error;
    if (err is DioException) {
      final detail = err.response?.data?['detail'];
      if (detail is String) return detail;
    }
    return null;
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
