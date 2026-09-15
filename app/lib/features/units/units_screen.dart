import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import 'unit_form.dart';
import 'units_provider.dart';

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final units = ref.watch(unitsProvider);

    return Scaffold(
      body: units.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.noData))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(unitsProvider),
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            u.isDebtor ? Colors.red.shade50 : Colors.green.shade50,
                        child: Icon(Icons.person,
                            color: u.isDebtor ? Colors.red : Colors.green),
                      ),
                      title: Text('${u.unitNumber} — ${u.residentName}'),
                      subtitle: Text(u.phone),
                      trailing: Text(
                        '${u.balance} ₪',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: u.isDebtor ? Colors.red : Colors.green.shade800,
                        ),
                      ),
                      onTap: () => _showUnitActions(context, ref, l10n, u),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addUnit),
        onPressed: () => showUnitFormSheet(context, ref),
      ),
    );
  }

  void _showUnitActions(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, Unit u) {
    showModalBottomSheet(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(u.residentName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${u.unitNumber} • ${u.phone}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.key),
              title: Text(l10n.issueCode),
              subtitle: Text(l10n.shareCodeHint),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _showInviteCode(context, ref, l10n, u);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.editUnit),
              onTap: () {
                Navigator.pop(sheetCtx);
                showUnitFormSheet(context, ref, unit: u);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  Text(l10n.deleteUnit, style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDelete(context, ref, l10n, u);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, Unit u) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.deleteUnit),
        content: Text('${u.unitNumber} — ${u.residentName}\n${l10n.deleteUnitConfirm}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(l10n.deleteUnit),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/units/${u.id}');
      ref.invalidate(unitsProvider);
    } on DioException catch (e) {
      if (context.mounted) {
        final msg =
            e.response?.statusCode == 409 ? l10n.unitDeleteBlocked : l10n.error;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _showInviteCode(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, Unit u) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final code = await ref.read(inviteCodeProvider(u.phone).future);
      if (!context.mounted) return;
      Navigator.pop(context); // dismiss loading
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
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
              },
            ),
            TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.error)));
    }
  }
}
