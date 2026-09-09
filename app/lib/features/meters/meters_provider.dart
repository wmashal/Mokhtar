import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

class MeterRound {
  final int id;
  final String month;
  final String status;
  final List<Reading> readings;

  MeterRound.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        month = j['month'],
        status = j['status'],
        readings =
            (j['readings'] as List?)?.map((e) => Reading.fromJson(e)).toList() ??
                [];

  bool get isOpen => status == 'open';
}

class Reading {
  final int id;
  final int unitId;
  final String previousValue;
  final String currentValue;
  final String consumption;
  final String cost;

  Reading.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        unitId = j['unit_id'],
        previousValue = j['previous_value'],
        currentValue = j['current_value'],
        consumption = j['consumption'],
        cost = j['cost'];
}

final meterRoundsProvider = FutureProvider<List<MeterRound>>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.buildingId == null) return [];
  final res = await ref
      .read(apiClientProvider)
      .get('/buildings/${auth!.buildingId}/meter-rounds');
  return (res.data as List).map((e) => MeterRound.fromJson(e)).toList();
});
