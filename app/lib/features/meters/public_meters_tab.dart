import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../../core/ui/photo.dart';
import '../auth/auth_provider.dart';
import 'meters_provider.dart';

/// Everyone sees public meters with readings + proof photos (transparency).
/// Manager can add meters and readings.
class PublicMetersTab extends ConsumerWidget {
  const PublicMetersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final meters = ref.watch(publicMetersProvider);
    final isManager = ref.watch(authProvider).value?.isManager == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: meters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.noData))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(publicMetersProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    return Card(
                      child: ExpansionTile(
                        leading: const Icon(Icons.bolt, color: Colors.amber),
                        title: Text(m.name),
                        subtitle: Text(
                            '${l10n.meterPrice}: ${m.unitPrice} ₪/${l10n.unitShort}'),
                        children: [
                          if (m.readings.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(l10n.noData),
                            )
                          else
                            ...m.readings.map(
                              (r) => ListTile(
                                dense: true,
                                title: Text(r.month),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${r.previousValue} → ${r.currentValue} (${r.consumption})'),
                                    if (r.photoPath != null ||
                                        r.billPhotoPath != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            if (r.photoPath != null) ...[
                                              PhotoThumb(
                                                  name: r.photoPath!, size: 44),
                                              const SizedBox(width: 8),
                                            ],
                                            if (r.billPhotoPath != null)
                                              PhotoThumb(
                                                  name: r.billPhotoPath!,
                                                  size: 44),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  '${r.cost} ₪',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          if (isManager)
                            TextButton.icon(
                              icon: const Icon(Icons.add),
                              label: Text(l10n.addReading),
                              onPressed: () =>
                                  _addReading(context, ref, l10n, m),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.small(
              heroTag: 'addPublicMeter',
              onPressed: () => _addMeter(context, ref, l10n),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _addMeter(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final nameCtrl = TextEditingController(text: l10n.defaultPublicMeterName);
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addPublicMeter),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: l10n.meterName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    '${l10n.meterPrice} (₪/kWh) — ${l10n.optional}',
                hintText: '0.65',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final auth = ref.read(authProvider).value;
              try {
                await ref.read(apiClientProvider).post(
                  '/buildings/${auth!.buildingId}/public-meters',
                  data: {
                    'name': nameCtrl.text.trim(),
                    'meter_type': 'electricity',
                    // empty → server uses the building's electricity price
                    if (priceCtrl.text.trim().isNotEmpty)
                      'unit_price': priceCtrl.text.trim(),
                  },
                );
                ref.invalidate(publicMetersProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
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
    );
  }

  void _addReading(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, PublicMeter m) {
    final ctrl = TextEditingController();
    final previous =
        m.readings.isEmpty ? null : m.readings.first.currentValue;
    String? meterPhoto;
    String? billPhoto;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('${l10n.addReading} — ${m.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (previous != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.previousReading),
                      Text(previous,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.currentReading),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachButton(ctx, ref, l10n.meterPhoto, meterPhoto,
                      (p) => setState(() => meterPhoto = p)),
                  _attachButton(ctx, ref, l10n.billPhoto, billPhoto,
                      (p) => setState(() => billPhoto = p)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final now = DateTime.now();
                try {
                  await ref.read(apiClientProvider).post(
                    '/public-meters/${m.id}/readings',
                    data: {
                      'month':
                          '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
                      'current_value': ctrl.text.trim(),
                      'photo_path': ?meterPhoto,
                      'bill_photo_path': ?billPhoto,
                    },
                  );
                  ref.invalidate(publicMetersProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (_) {
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

  Widget _attachButton(BuildContext context, WidgetRef ref, String label,
      String? path, ValueChanged<String> onPicked) {
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final uploaded = await pickAndUploadPhoto(context, ref);
            if (uploaded != null) onPicked(uploaded);
          },
          child: path == null
              ? Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      color: Colors.grey),
                )
              : PhotoThumb(name: path, size: 64),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
