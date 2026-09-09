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

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return const AuthState();
    // TODO: decode JWT to restore role/unit/building without a network call
    return AuthState(token: token);
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
