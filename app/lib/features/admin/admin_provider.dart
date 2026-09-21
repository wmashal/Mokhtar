import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

/// One row in the system admin's buildings list.
class AdminBuilding {
  final int id;
  final String name;
  final int unitCount;
  final int managerCount;

  AdminBuilding.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        unitCount = j['unit_count'],
        managerCount = j['manager_count'];

  bool get hasManager => managerCount > 0;
}

final adminBuildingsProvider = FutureProvider<List<AdminBuilding>>((ref) async {
  final res = await ref.read(apiClientProvider).get('/buildings');
  return (res.data as List).map((e) => AdminBuilding.fromJson(e)).toList();
});
