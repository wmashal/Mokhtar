import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import '../units/units_provider.dart';
import 'meters_provider.dart';

class MetersScreen extends ConsumerWidget {
  const MetersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rounds = ref.watch(meterRoundsProvider);

    return Scaffold(
      body: rounds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.noData))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(meterRoundsProvider),
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(
                          r.isOpen ? Icons.edit_outlined : Icons.check_circle,
                          color: r.isOpen ? Colors.orange : Colors.green,
                        ),
                        title: Text(r.month),
                        subtitle: Text(
                            '${r.readings.length} ${l10n.units} • ${r.isOpen ? l10n.open : l10n.issued}'),
                        trailing: r.isOpen
                            ? const Icon(Icons.chevron_left)
                            : null,
                        onTap: r.isOpen
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ReadingRoundScreen(roundId: r.id, month: r.month),
                                  ),
                                )
                            : null,
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newReadingRound),
        onPressed: () => _openRound(context, ref, l10n),
      ),
    );
  }

  Future<void> _openRound(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final now = DateTime.now();
    final month =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    try {
      final auth = ref.read(authProvider).value;
      await ref.read(apiClientProvider).post(
        '/buildings/${auth!.buildingId}/meter-rounds',
        data: {'month': month},
      );
      ref.invalidate(meterRoundsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.error)));
      }
    }
  }
}

class ReadingRoundScreen extends ConsumerStatefulWidget {
  const ReadingRoundScreen({super.key, required this.roundId, required this.month});

  final int roundId;
  final String month;

  @override
  ConsumerState<ReadingRoundScreen> createState() => _ReadingRoundScreenState();
}

class _ReadingRoundScreenState extends ConsumerState<ReadingRoundScreen> {
  final Map<int, TextEditingController> _controllers = {};
  final Set<int> _saved = {};
  bool _issuing = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final units = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.month)),
      body: units.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final u = list[i];
            final ctrl = _controllers.putIfAbsent(
                u.id, () => TextEditingController());
            final saved = _saved.contains(u.id);
            return ListTile(
              leading: Icon(
                saved ? Icons.check_circle : Icons.water_drop_outlined,
                color: saved ? Colors.green : null,
              ),
              title: Text('${u.unitNumber} — ${u.residentName}'),
              subtitle: saved
                  ? Text(l10n.saved)
                  : TextField(
                      controller: ctrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: l10n.currentReading,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
              trailing: saved
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.save_outlined),
                      onPressed: () => _saveReading(u.id, ctrl.text.trim()),
                    ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: _issuing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(l10n.issueInvoices),
            onPressed: _issuing ? null : _issue,
          ),
        ),
      ),
    );
  }

  Future<void> _saveReading(int unitId, String value) async {
    if (value.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(
        '/meter-rounds/${widget.roundId}/readings',
        data: {'unit_id': unitId, 'current_value': value},
      );
      setState(() => _saved.add(unitId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  Future<void> _issue() async {
    setState(() => _issuing = true);
    try {
      await ref
          .read(apiClientProvider)
          .post('/meter-rounds/${widget.roundId}/issue');
      ref.invalidate(meterRoundsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    } finally {
      if (mounted) setState(() => _issuing = false);
    }
  }
}
