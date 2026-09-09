import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

class Transaction {
  final int id;
  final int? unitId;
  final String type;
  final String amount;
  final String category;
  final String note;
  final DateTime createdAt;

  Transaction.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        unitId = j['unit_id'],
        type = j['type'],
        amount = j['amount'],
        category = j['category'] ?? '',
        note = j['note'] ?? '',
        createdAt = DateTime.parse(j['created_at']);
}

final buildingStatementProvider =
    FutureProvider<List<Transaction>>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.buildingId == null) return [];
  final res = await ref
      .read(apiClientProvider)
      .get('/buildings/${auth!.buildingId}/transactions');
  return (res.data as List).map((e) => Transaction.fromJson(e)).toList();
});

final myStatementProvider = FutureProvider<List<Transaction>>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.unitId == null) return [];
  final res =
      await ref.read(apiClientProvider).get('/units/${auth!.unitId}/statement');
  return (res.data as List).map((e) => Transaction.fromJson(e)).toList();
});
