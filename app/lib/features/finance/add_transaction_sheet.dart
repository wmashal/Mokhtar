import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import 'finance_provider.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, required this.buildingId});

  final int buildingId;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'payment';
  int? _unitId;
  List<dynamic> _units = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    final res = await ref
        .read(apiClientProvider)
        .get('/buildings/${widget.buildingId}/units');
    setState(() => _units = res.data as List);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).post(
        '/buildings/${widget.buildingId}/transactions',
        data: {
          'unit_id': _type == 'expense' ? null : _unitId,
          'type': _type,
          'amount': _amountCtrl.text.trim(),
          'category': '',
          'note': _noteCtrl.text.trim(),
        },
      );
      ref.invalidate(buildingStatementProvider);
      ref.invalidate(myStatementProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.addTransaction,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'payment', label: Text(l10n.payment)),
              ButtonSegment(value: 'charge', label: Text(l10n.charge)),
              ButtonSegment(value: 'expense', label: Text(l10n.expense)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          if (_type != 'expense')
            DropdownButtonFormField<int>(
              initialValue: _unitId,
              decoration: InputDecoration(
                labelText: l10n.units,
                border: const OutlineInputBorder(),
              ),
              items: _units
                  .map((u) => DropdownMenuItem<int>(
                        value: u['id'] as int,
                        child: Text(
                            '${u['unit_number']} — ${u['resident_name']}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _unitId = v),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.amount,
              border: const OutlineInputBorder(),
              suffixText: '₪',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: l10n.note,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
