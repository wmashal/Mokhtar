import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

class Meeting {
  final int id;
  final String title;
  final DateTime startsAt;
  final String location;
  final String agenda;

  Meeting.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        title = j['title'],
        startsAt = DateTime.parse(j['starts_at']),
        location = j['location'] ?? '',
        agenda = j['agenda'] ?? '';
}

final meetingsProvider = FutureProvider<List<Meeting>>((ref) async {
  final bid = ref.watch(currentBuildingIdProvider);
  if (bid == null) return [];
  final res = await ref.read(apiClientProvider).get('/buildings/$bid/meetings');
  return (res.data as List).map((e) => Meeting.fromJson(e)).toList();
});
