import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../../core/ui/photo.dart';
import '../auth/auth_provider.dart';
import '../units/units_provider.dart';
import 'meters_provider.dart';

/// Reading rounds. Everyone can view issued rounds (transparency);
/// the manager can open a round, enter readings (with meter + bill photos),
/// and issue invoices.
class RoundsTab extends ConsumerWidget {
  const RoundsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final rounds = ref.watch(meterRoundsProvider);
    final isManager = ref.watch(authProvider).value?.isManager == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    final canEdit = r.isOpen && isManager;
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
                        trailing: (r.isOpen && !isManager)
                            ? null
                            : const Icon(Icons.chevron_left),
                        onTap: canEdit
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReadingRoundScreen(
                                        roundId: r.id, month: r.month),
                                  ),
                                )
                            : r.isOpen
                                ? null
                                : () => _showRoundDetails(context, ref, l10n, r),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.small(
              heroTag: 'addRound',
              onPressed: () => _openRound(context, ref, l10n),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Read-only detail of an issued round: every unit's reading + proof photos.
  void _showRoundDetails(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, MeterRound r) {
    final units = ref.read(unitsProvider).value ?? [];
    String unitLabel(int unitId) {
      for (final u in units) {
        if (u.id == unitId) return '${u.unitNumber} — ${u.residentName}';
      }
      return '#$unitId';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(r.month, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...r.readings.map((rd) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unitLabel(rd.unitId),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            '${rd.previousValue} → ${rd.currentValue} • ${l10n.consumption}: ${rd.consumption} • ${l10n.cost}: ${rd.cost} ₪'),
                        if (rd.photoPath != null || rd.billPhotoPath != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                if (rd.photoPath != null) ...[
                                  PhotoThumb(name: rd.photoPath!),
                                  const SizedBox(width: 8),
                                ],
                                if (rd.billPhotoPath != null)
                                  PhotoThumb(name: rd.billPhotoPath!),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _openRound(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
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
  const ReadingRoundScreen(
      {super.key, required this.roundId, required this.month});

  final int roundId;
  final String month;

  @override
  ConsumerState<ReadingRoundScreen> createState() => _ReadingRoundScreenState();
}

class _ReadingRoundScreenState extends ConsumerState<ReadingRoundScreen> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, String> _meterPhotos = {};
  final Map<int, String> _billPhotos = {};
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
    final rounds = ref.watch(meterRoundsProvider);

    // This round's readings, straight from the server — so corrections and
    // previously saved readings show up in any session.
    MeterRound? round;
    for (final r in rounds.value ?? const <MeterRound>[]) {
      if (r.id == widget.roundId) {
        round = r;
        break;
      }
    }
    final readingsByUnit = {
      for (final rd in round?.readings ?? const <Reading>[]) rd.unitId: rd
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.month),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.deleteRound,
            onPressed: () => _deleteRound(l10n),
          ),
        ],
      ),
      body: units.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, i) {
            final u = list[i];
            final reading = readingsByUnit[u.id];
            if (reading != null) return _savedTile(l10n, u, reading);

            final ctrl =
                _controllers.putIfAbsent(u.id, () => TextEditingController());
            return ListTile(
              leading: const Icon(Icons.water_drop_outlined),
              title: Text('${u.unitNumber} — ${u.residentName}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: l10n.currentReading,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _photoButton(
                          u.id, l10n.meterPhoto, _meterPhotos[u.id], true),
                      const SizedBox(width: 8),
                      _photoButton(
                          u.id, l10n.billPhoto, _billPhotos[u.id], false),
                    ],
                  ),
                ],
              ),
              trailing: IconButton(
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
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(l10n.issueInvoices),
            onPressed: _issuing ? null : _issue,
          ),
        ),
      ),
    );
  }

  /// A unit whose reading is already saved — with correct/delete actions.
  Widget _savedTile(AppLocalizations l10n, Unit u, Reading rd) {
    return ListTile(
      leading: const Icon(Icons.check_circle, color: Colors.green),
      title: Text('${u.unitNumber} — ${u.residentName}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${rd.previousValue} → ${rd.currentValue} • ${l10n.consumption}: ${rd.consumption} • ${l10n.cost}: ${rd.cost} ₪'),
          if (rd.photoPath != null || rd.billPhotoPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  if (rd.photoPath != null) ...[
                    PhotoThumb(name: rd.photoPath!, size: 40),
                    const SizedBox(width: 8),
                  ],
                  if (rd.billPhotoPath != null)
                    PhotoThumb(name: rd.billPhotoPath!, size: 40),
                ],
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
            onPressed: () => _editReading(l10n, rd),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.delete,
            onPressed: () => _deleteReading(l10n, rd),
          ),
        ],
      ),
    );
  }

  Future<void> _editReading(AppLocalizations l10n, Reading rd) async {
    final ctrl = TextEditingController(text: rd.currentValue);
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editReading),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.currentReading,
            border: const OutlineInputBorder(),
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
    final value = ctrl.text.trim();
    ctrl.dispose();
    if (save != true || value.isEmpty || !mounted) return;
    try {
      await ref.read(apiClientProvider).patch(
        '/readings/${rd.id}',
        data: {'current_value': value},
      );
      ref.invalidate(meterRoundsProvider);
      ref.invalidate(myReadingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  Future<void> _deleteReading(AppLocalizations l10n, Reading rd) async {
    if (!await _confirm(l10n.deleteReadingConfirm)) return;
    try {
      await ref.read(apiClientProvider).delete('/readings/${rd.id}');
      ref.invalidate(meterRoundsProvider);
      ref.invalidate(myReadingsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  Future<void> _deleteRound(AppLocalizations l10n) async {
    if (!await _confirm(l10n.deleteRoundConfirm)) return;
    try {
      await ref
          .read(apiClientProvider)
          .delete('/meter-rounds/${widget.roundId}');
      ref.invalidate(meterRoundsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  Future<bool> _confirm(String message) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Widget _photoButton(int unitId, String tooltip, String? path, bool isMeter) {
    return InkWell(
      onTap: () async {
        final uploaded = await pickAndUploadPhoto(context, ref);
        if (uploaded != null) {
          setState(() => isMeter
              ? _meterPhotos[unitId] = uploaded
              : _billPhotos[unitId] = uploaded);
        }
      },
      child: path == null
          ? Tooltip(
              message: tooltip,
              child: Icon(
                isMeter ? Icons.photo_camera_outlined : Icons.receipt_outlined,
                color: Colors.grey,
              ),
            )
          : PhotoThumb(name: path, size: 40),
    );
  }

  Future<void> _saveReading(int unitId, String value) async {
    if (value.isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(
        '/meter-rounds/${widget.roundId}/readings',
        data: {
          'unit_id': unitId,
          'current_value': value,
          if (_meterPhotos[unitId] != null) 'photo_path': _meterPhotos[unitId],
          if (_billPhotos[unitId] != null)
            'bill_photo_path': _billPhotos[unitId],
        },
      );
      _meterPhotos.remove(unitId);
      _billPhotos.remove(unitId);
      ref.invalidate(meterRoundsProvider);
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
      ref.invalidate(myReadingsProvider);
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
