import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';

class Announcement {
  final int id;
  final String body;
  final DateTime createdAt;

  Announcement.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        body = j['body'],
        createdAt = DateTime.parse(j['created_at']);
}

final announcementsProvider = FutureProvider<List<Announcement>>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.buildingId == null) return [];
  final res = await ref
      .read(apiClientProvider)
      .get('/buildings/${auth!.buildingId}/announcements');
  return (res.data as List).map((e) => Announcement.fromJson(e)).toList();
});
