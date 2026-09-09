import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'finance_provider.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key, required this.myOnly});

  final bool myOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final txs = ref.watch(myOnly ? myStatementProvider : buildingStatementProvider);
    final dateFmt = DateFormat.yMMMd(Localizations.localeOf(context).languageCode);

    return txs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.error)),
      data: (list) => list.isEmpty
          ? Center(child: Text(l10n.noData))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(
                  myOnly ? myStatementProvider : buildingStatementProvider),
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final tx = list[i];
                  final (icon, color) = switch (tx.type) {
                    'payment' => (Icons.arrow_downward, Colors.green),
                    'charge' => (Icons.arrow_upward, Colors.orange),
                    _ => (Icons.remove_circle_outline, Colors.red),
                  };
                  final typeLabel = switch (tx.type) {
                    'payment' => l10n.payment,
                    'charge' => l10n.charge,
                    _ => l10n.expense,
                  };
                  return ListTile(
                    leading: Icon(icon, color: color),
                    title: Text(tx.note.isNotEmpty ? tx.note : typeLabel),
                    subtitle: Text(
                      '${tx.category} • ${dateFmt.format(tx.createdAt)}',
                    ),
                    trailing: Text(
                      '${tx.amount} ₪',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
