import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import 'dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final myDash = ref.watch(myDashboardProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myDashboardProvider);
        ref.invalidate(buildingDashboardProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- My balance card ----
          myDash.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
                  error: (e, _) => Card(
                        child: ListTile(
                          title: Text(l10n.error),
                          subtitle: Text('$e'),
                        ),
                      ),
            data: (d) {
              final balance = double.tryParse(d.balance) ?? 0;
              final isDebt = balance < 0;
              return Card(
                color: isDebt ? Colors.red.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.myBalance,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        '${d.balance} ₪',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: isDebt ? Colors.red : Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _miniStat(context,
                                label: l10n.paidThisMonth,
                                value: '${d.paidThisMonth} ₪'),
                          ),
                          Expanded(
                            child: _miniStat(context,
                                label: l10n.chargedThisMonth,
                                value: '${d.chargedThisMonth} ₪'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ---- Building totals (visible to every resident — transparency) ----
          ...[
            const SizedBox(height: 16),
            Text(l10n.buildingStatement,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ref.watch(buildingDashboardProvider).when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
            error: (e, _) => Card(
              child: ListTile(
                title: Text(l10n.error),
                subtitle: Text('$e'),
              ),
            ),
                  data: (b) => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _totalCard(
                              context,
                              label: l10n.totalCollected,
                              value: '${b.totalPaidThisMonth} ₪',
                              color: Colors.green,
                              onTap: () => _showUnitDetails(
                                  context, ref, l10n, b, showPaid: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _totalCard(
                              context,
                              label: l10n.totalCharged,
                              value: '${b.totalChargedThisMonth} ₪',
                              color: Colors.orange,
                              onTap: () => _showUnitDetails(
                                  context, ref, l10n, b, showPaid: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _totalCard(
                              context,
                              label: l10n.expensesThisMonth,
                              value: '${b.expensesThisMonth} ₪',
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _totalCard(
                              context,
                              label: l10n.buildingBalance,
                              value: '${b.totalBalance} ₪',
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, {required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Widget _totalCard(BuildContext context,
      {required String label,
      required String value,
      required Color color,
      VoidCallback? onTap}) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: color, fontWeight: FontWeight.bold)),
              if (onTap != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(Icons.chevron_left, size: 18, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnitDetails(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, BuildingDashboard b,
      {required bool showPaid}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.unitDetails,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: b.units.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final u = b.units[i];
                  final value = showPaid ? u.paidThisMonth : u.chargedThisMonth;
                  final bal = double.tryParse(u.balance) ?? 0;
                  return ListTile(
                    title: Text('${u.unitNumber} — ${u.residentName}'),
                    subtitle: Text('${l10n.balance}: ${u.balance} ₪'),
                    trailing: Text(
                      '$value ₪',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: bal < 0 ? Colors.red : Colors.green.shade800,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
