import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
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
        onPressed: () => _showAddUnit(context, ref, l10n),
      ),
    );
  }

  void _showUnitActions(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, Unit u) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
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
                Navigator.pop(context);
                await _showInviteCode(context, ref, l10n, u);
              },
            ),
          ],
        ),
      ),
    );
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
        builder: (_) => AlertDialog(
          title: Text(l10n.inviteCode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: Theme.of(context)
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
              onPressed: () => Navigator.pop(context),
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

  void _showAddUnit(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final numberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final feeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addUnit, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: numberCtrl,
              decoration: InputDecoration(
                  labelText: l10n.unitNumber, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: l10n.residentName, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: l10n.phoneNumber, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${l10n.monthlyFee} (${l10n.optional})',
                border: const OutlineInputBorder(),
                suffixText: '₪',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final auth = ref.read(authProvider).value;
                try {
                  await ref.read(apiClientProvider).post(
                    '/buildings/${auth!.buildingId}/units',
                    data: {
                      'unit_number': numberCtrl.text.trim(),
                      'resident_name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      if (feeCtrl.text.trim().isNotEmpty)
                        'monthly_fee': feeCtrl.text.trim(),
                    },
                  );
                  ref.invalidate(unitsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text(l10n.error)));
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
