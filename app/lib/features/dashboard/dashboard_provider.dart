import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

class MyDashboard {
  final int unitId;
  final String residentName;
  final String balance;
  final String paidThisMonth;
  final String chargedThisMonth;

  MyDashboard.fromJson(Map<String, dynamic> j)
      : unitId = j['unit_id'],
        residentName = j['resident_name'],
        balance = j['balance'],
        paidThisMonth = j['paid_this_month'],
        chargedThisMonth = j['charged_this_month'];
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
        balance = j['balance'],
        paidThisMonth = j['paid_this_month'],
        chargedThisMonth = j['charged_this_month'];

  bool get isDebtor => double.tryParse(balance) != null && double.parse(balance) < 0;
}

class BuildingDashboard {
  final String totalBalance;
  final String totalPaidThisMonth;
  final String totalChargedThisMonth;
  final String expensesThisMonth;
  final List<UnitSummary> units;

  BuildingDashboard.fromJson(Map<String, dynamic> j)
      : totalBalance = j['total_balance'],
        totalPaidThisMonth = j['total_paid_this_month'],
        totalChargedThisMonth = j['total_charged_this_month'],
        expensesThisMonth = j['expenses_this_month'],
        units = (j['units'] as List).map((e) => UnitSummary.fromJson(e)).toList();
}

final myDashboardProvider = FutureProvider<MyDashboard>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.unitId == null) throw StateError('no unit');
  final res = await ref.read(apiClientProvider).get('/units/${auth!.unitId}/dashboard');
  return MyDashboard.fromJson(res.data);
});

final buildingDashboardProvider = FutureProvider<BuildingDashboard>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.buildingId == null) throw StateError('no building');
  final res =
      await ref.read(apiClientProvider).get('/buildings/${auth!.buildingId}/dashboard');
  return BuildingDashboard.fromJson(res.data);
});
