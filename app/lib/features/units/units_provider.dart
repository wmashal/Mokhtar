import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

class Unit {
  final int id;
  final String unitNumber;
  final String residentName;
  final String phone;
  final String? monthlyFee;
  final String balance;

  Unit.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        unitNumber = j['unit_number'],
        residentName = j['resident_name'],
        phone = j['phone'],
        monthlyFee = j['monthly_fee'],
        balance = j['balance'];

  bool get isDebtor => (double.tryParse(balance) ?? 0) < 0;
}

final unitsProvider = FutureProvider<List<Unit>>((ref) async {
  final bid = ref.watch(currentBuildingIdProvider);
  if (bid == null) return [];
  final res = await ref.read(apiClientProvider).get('/buildings/$bid/units');
  return (res.data as List).map((e) => Unit.fromJson(e)).toList();
});

/// Issue an invite code for a unit's phone; returns the code string.
final inviteCodeProvider =
    FutureProvider.autoDispose.family<String, String>((ref, phone) async {
  final res = await ref.read(apiClientProvider).post('/auth/invite', data: {'phone': phone});
  return res.data['code'] as String;
});
