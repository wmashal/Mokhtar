import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import '../units/unit_form.dart';
import '../units/units_provider.dart';

class UserAccount {
  final int id;
  final String phone;
  final int unitId;
  final String role;

  UserAccount.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        phone = j['phone'],
        unitId = j['unit_id'],
        role = j['role'];

  bool get isManager => role == 'manager';
}

final _usersProvider = FutureProvider<List<UserAccount>>((ref) async {
  final auth = ref.watch(authProvider).value;
  if (auth?.buildingId == null) return [];
  final res = await ref
      .read(apiClientProvider)
      .get('/buildings/${auth!.buildingId}/users');
  return (res.data as List).map((e) => UserAccount.fromJson(e)).toList();
});

/// Manager-only: every login in the building — issue codes, promote/demote
/// co-managers, deactivate access. Adding a user = adding its unit.
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final users = ref.watch(_usersProvider);
    final units = ref.watch(unitsProvider).value ?? [];
    final me = ref.watch(authProvider).value;

    String unitLabel(int unitId) {
      for (final u in units) {
        if (u.id == unitId) return '${u.unitNumber} — ${u.residentName}';
      }
      return '#$unitId';
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.userManagement)),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_usersProvider);
            ref.invalidate(unitsProvider);
          },
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = list[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: u.isManager
                      ? Colors.teal.shade50
                      : Colors.grey.shade200,
                  child: Icon(
                    u.isManager ? Icons.manage_accounts : Icons.person_outline,
                    color: u.isManager ? Colors.teal : Colors.grey.shade700,
                  ),
                ),
                title: Text(unitLabel(u.unitId)),
                subtitle: Text(u.phone),
                trailing: Chip(
                  label: Text(u.isManager ? l10n.managerRole : l10n.residentRole),
                  visualDensity: VisualDensity.compact,
                ),
                onTap: () => _showUserActions(context, ref, l10n, u, me),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.addUser),
        onPressed: () => showUnitFormSheet(context, ref),
      ),
    );
  }

  void _showUserActions(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, UserAccount u, AuthState? me) {
    final isSelf = me?.unitId == u.unitId;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(u.phone,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle:
                  Text(u.isManager ? l10n.managerRole : l10n.residentRole),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.key),
              title: Text(l10n.issueCode),
              subtitle: Text(l10n.shareCodeHint),
              onTap: () async {
                Navigator.pop(ctx);
                await _showInviteCode(context, ref, l10n, u);
              },
            ),
            if (!isSelf)
              ListTile(
                leading: Icon(u.isManager
                    ? Icons.arrow_downward
                    : Icons.arrow_upward),
                title: Text(u.isManager ? l10n.makeResident : l10n.makeManager),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(apiClientProvider).patch(
                      '/users/${u.id}/role',
                      data: {'role': u.isManager ? 'resident' : 'manager'},
                    );
                    ref.invalidate(_usersProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l10n.error)));
                    }
                  }
                },
              ),
            if (!isSelf)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text(l10n.deactivateUser,
                    style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(apiClientProvider).delete('/users/${u.id}');
                    ref.invalidate(_usersProvider);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l10n.error)));
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInviteCode(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, UserAccount u) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final code = await ref.read(inviteCodeProvider(u.phone).future);
      if (!context.mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (dctx) => AlertDialog(
          title: Text(l10n.inviteCode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: Theme.of(dctx)
                    .textTheme
                    .displayMedium
                    ?.copyWith(letterSpacing: 8, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(l10n.shareCodeHint),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(l10n.copy),
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.error)));
    }
  }
}
