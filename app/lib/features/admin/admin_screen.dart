import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import 'admin_provider.dart';

/// System admin home: all buildings — add a building, assign its Mokhtar
/// (issues his first login code), or open a building to manage it directly.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final buildings = ref.watch(adminBuildingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminPanel),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: buildings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.noData))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(adminBuildingsProvider),
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final b = list[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.apartment),
                        title: Text(b.name),
                        subtitle: Text(
                            '${b.unitCount} ${l10n.units} • ${b.managerCount} ${l10n.managerRole}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!b.hasManager)
                              IconButton(
                                icon: const Icon(Icons.person_add_outlined),
                                tooltip: l10n.assignManager,
                                onPressed: () =>
                                    _assignManager(context, ref, l10n, b),
                              ),
                            IconButton(
                              icon: const Icon(Icons.login),
                              tooltip: l10n.openBuilding,
                              onPressed: b.hasManager
                                  ? () => ref
                                      .read(activeBuildingProvider.notifier)
                                      .state = b.id
                                  : null, // nothing to see until it has a manager/units
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.addBuilding),
        onPressed: () => _addBuilding(context, ref, l10n),
      ),
    );
  }

  Future<void> _addBuilding(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    final waterCtrl = TextEditingController();
    final elecCtrl = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addBuilding),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: l10n.buildingName,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: l10n.monthlyFee,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waterCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: l10n.waterPrice,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: elecCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: l10n.electricityPrice,
                    border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (save != true || nameCtrl.text.trim().isEmpty || !context.mounted) {
      return;
    }
    try {
      await ref.read(apiClientProvider).post('/buildings', data: {
        'name': nameCtrl.text.trim(),
        if (feeCtrl.text.trim().isNotEmpty) 'monthly_fee': feeCtrl.text.trim(),
        if (waterCtrl.text.trim().isNotEmpty)
          'water_unit_price': waterCtrl.text.trim(),
        if (elecCtrl.text.trim().isNotEmpty)
          'electricity_unit_price': elecCtrl.text.trim(),
      });
      ref.invalidate(adminBuildingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.error)));
      }
    }
  }

  /// Create the Mokhtar's unit + account, then issue his first login code.
  Future<void> _assignManager(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, AdminBuilding b) async {
    final unitCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.assignManager} — ${b.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: unitCtrl,
              decoration: InputDecoration(
                  labelText: l10n.unitNumber,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                  labelText: l10n.residentName,
                  border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: l10n.phoneNumber,
                  border: const OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (save != true || !context.mounted) return;

    try {
      await ref.read(apiClientProvider).post(
        '/buildings/${b.id}/setup-manager',
        data: {
          'unit_number': unitCtrl.text.trim(),
          'resident_name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
        },
      );
      final codeRes = await ref
          .read(apiClientProvider)
          .post('/buildings/${b.id}/bootstrap-code');
      ref.invalidate(adminBuildingsProvider);
      if (!context.mounted) return;
      final code = '${codeRes.data['code']}';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.firstLoginCode),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(code, style: Theme.of(ctx).textTheme.headlineMedium),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: l10n.copy,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: code)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.error)));
      }
    }
  }
}
