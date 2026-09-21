import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

/// Server may return numeric fields as JSON numbers (raw-dict endpoints) or
/// strings (pydantic endpoints) — normalize both to String.
String _s(dynamic v) => '$v';

class MyDashboard {
  final int unitId;
  final String residentName;
  final String balance;
  final String paidThisMonth;
  final String chargedThisMonth;

  MyDashboard.fromJson(Map<String, dynamic> j)
      : unitId = j['unit_id'],
        residentName = j['resident_name'],
        balance = _s(j['balance']),
        paidThisMonth = _s(j['paid_this_month']),
        chargedThisMonth = _s(j['charged_this_month']);
}

class UnitSummary {
  final int unitId;
  final String unitNumber;
  final String residentName;
  final String balance;
  final String paidThisMonth;
  final String chargedThisMonth;

  UnitSummary.fromJson(Map<String, dynamic> j)
      : unitId = j['unit_id'],
        unitNumber = j['unit_number'],
        residentName = j['resident_name'],
        balance = _s(j['balance']),
        paidThisMonth = _s(j['paid_this_month']),
        chargedThisMonth = _s(j['charged_this_month']);

  bool get isDebtor => double.tryParse(balance) != null && double.parse(balance) < 0;
}

class BuildingDashboard {
  final String totalBalance;
  final String totalPaidThisMonth;
  final String totalChargedThisMonth;
  final String expensesThisMonth;
  final List<UnitSummary> units;

  BuildingDashboard.fromJson(Map<String, dynamic> j)
      : totalBalance = _s(j['total_balance']),
        totalPaidThisMonth = _s(j['total_paid_this_month']),
        totalChargedThisMonth = _s(j['total_charged_this_month']),
        expensesThisMonth = _s(j['expenses_this_month']),
        units = (j['units'] as List).map((e) => UnitSummary.fromJson(e)).toList();
}

final myDashboardProvider = FutureProvider<MyDashboard>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.unitId == null) throw StateError('no unit');
  try {
    final res = await ref.read(apiClientProvider).get('/units/${auth!.unitId}/dashboard');
    return MyDashboard.fromJson(res.data);
  } catch (e, st) {
    debugPrint('myDashboardProvider failed: $e\n$st');
    rethrow;
  }
});

final buildingDashboardProvider = FutureProvider<BuildingDashboard>((ref) async {
  final bid = ref.watch(currentBuildingIdProvider);
  if (bid == null) throw StateError('no building');
  try {
    final res =
        await ref.read(apiClientProvider).get('/buildings/$bid/dashboard');
    return BuildingDashboard.fromJson(res.data);
  } catch (e, st) {
    debugPrint('buildingDashboardProvider failed: $e\n$st');
    rethrow;
  }
});
