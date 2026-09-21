import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import 'meetings_provider.dart';

class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final meetings = ref.watch(meetingsProvider);
    final isManager = ref.watch(authProvider).value?.isManager == true;
    final dateFmt = DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .add_Hm();

    return Scaffold(
      body: meetings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.error)),
        data: (list) => list.isEmpty
            ? Center(child: Text(l10n.noData))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(meetingsProvider),
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[i];
                    final isPast = m.startsAt.isBefore(DateTime.now());
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.groups_outlined,
                                    color: isPast ? Colors.grey : Colors.teal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(m.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ),
                                if (isManager) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20),
                                    tooltip: l10n.edit,
                                    onPressed: () => _showMeetingForm(
                                        context, ref, l10n,
                                        existing: m),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    tooltip: l10n.delete,
                                    onPressed: () =>
                                        _cancelMeeting(context, ref, l10n, m),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                                '${dateFmt.format(m.startsAt)} • ${m.location}'),
                            if (m.agenda.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(m.agenda,
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                            ],
                            if (!isPast) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.check, size: 18),
                                    label: Text(l10n.attending),
                                    onPressed: () => _rsvp(
                                        context, ref, m.id, 'attending'),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.close, size: 18),
                                    label: Text(l10n.notAttending),
                                    onPressed: () => _rsvp(context, ref,
                                        m.id, 'not_attending'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(l10n.newMeeting),
              onPressed: () => _showMeetingForm(context, ref, l10n),
            )
          : null,
    );
  }

  Future<void> _cancelMeeting(BuildContext context, WidgetRef ref,
      AppLocalizations l10n, Meeting m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.deleteMeetingConfirm),
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
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(apiClientProvider).delete('/meetings/${m.id}');
      ref.invalidate(meetingsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.error)));
      }
    }
  }

  Future<void> _rsvp(BuildContext context, WidgetRef ref, int meetingId,
      String status) async {
    try {
      await ref.read(apiClientProvider).post(
        '/meetings/$meetingId/rsvp',
        data: {'status': status},
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.saved)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    }
  }

  /// Create a meeting, or edit it when [existing] is given.
  void _showMeetingForm(
      BuildContext context, WidgetRef ref, AppLocalizations l10n,
      {Meeting? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final locationCtrl =
        TextEditingController(text: existing?.location ?? '');
    final agendaCtrl = TextEditingController(text: existing?.agenda ?? '');
    DateTime when =
        existing?.startsAt ?? DateTime.now().add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? l10n.newMeeting : l10n.editMeeting,
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                    labelText: l10n.meetingTitle,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(
                    labelText: l10n.meetingLocation,
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: agendaCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: l10n.note, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(DateFormat.yMMMd(
                        Localizations.localeOf(ctx).languageCode)
                    .add_Hm()
                    .format(when)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: when,
                    firstDate: existing == null
                        ? DateTime.now()
                        : DateTime(2020), // editing a past meeting is allowed
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d == null) return;
                  if (!ctx.mounted) return;
                  final t = await showTimePicker(
                      context: ctx, initialTime: TimeOfDay.fromDateTime(when));
                  if (t == null) return;
                  setSheetState(() {
                    when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                  });
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  try {
                    if (existing == null) {
                      final bid = ref.read(currentBuildingIdProvider);
                      await ref.read(apiClientProvider).post(
                        '/buildings/$bid/meetings',
                        data: {
                          'title': titleCtrl.text.trim(),
                          'starts_at': when.toIso8601String(),
                          'location': locationCtrl.text.trim(),
                          'agenda': agendaCtrl.text.trim(),
                        },
                      );
                    } else {
                      await ref.read(apiClientProvider).patch(
                        '/meetings/${existing.id}',
                        data: {
                          'title': titleCtrl.text.trim(),
                          'starts_at': when.toIso8601String(),
                          'location': locationCtrl.text.trim(),
                          'agenda': agendaCtrl.text.trim(),
                        },
                      );
                    }
                    ref.invalidate(meetingsProvider);
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
      ),
    );
  }
}
