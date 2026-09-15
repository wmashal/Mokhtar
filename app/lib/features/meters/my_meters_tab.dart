import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/ui/photo.dart';
import 'meters_provider.dart';

/// Resident view: my water meter history (prev / current / diff / cost per month).
class MyMetersTab extends ConsumerWidget {
  const MyMetersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final readings = ref.watch(myReadingsProvider);

    return readings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.error)),
      data: (list) => list.isEmpty
          ? Center(child: Text(l10n.noData))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(myReadingsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.month,
                              style: Theme.of(context).textTheme.titleMedium),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _cell(context, l10n.previousReading, r.previousValue),
                              _cell(context, l10n.currentReading, r.currentValue),
                              _cell(context, l10n.consumption, r.consumption),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.cost,
                                  style: Theme.of(context).textTheme.titleSmall),
                              Text(
                                '${r.cost} ₪',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                              ),
                            ],
                          ),
                          if (r.photoPath != null || r.billPhotoPath != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(
                                children: [
                                  if (r.photoPath != null) ...[
                                    PhotoThumb(name: r.photoPath!, size: 64),
                                    const SizedBox(width: 8),
                                  ],
                                  if (r.billPhotoPath != null)
                                    PhotoThumb(name: r.billPhotoPath!, size: 64),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _cell(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
