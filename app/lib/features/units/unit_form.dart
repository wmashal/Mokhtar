import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import 'units_provider.dart';

/// Add a new unit (+ resident login) or edit an existing one.
/// Pass [unit] to edit; omit it to add.
Future<void> showUnitFormSheet(BuildContext context, WidgetRef ref,
    {Unit? unit}) {
  final l10n = AppLocalizations.of(context)!;
  final numberCtrl = TextEditingController(text: unit?.unitNumber);
  final nameCtrl = TextEditingController(text: unit?.residentName);
  final phoneCtrl = TextEditingController(text: unit?.phone);
  final feeCtrl = TextEditingController(text: unit?.monthlyFee);
  final isEdit = unit != null;

  return showModalBottomSheet(
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
          Text(isEdit ? l10n.editUnit : l10n.addUnit,
              style: Theme.of(ctx).textTheme.titleLarge),
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
              final body = {
                'unit_number': numberCtrl.text.trim(),
                'resident_name': nameCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
                if (feeCtrl.text.trim().isNotEmpty)
                  'monthly_fee': feeCtrl.text.trim(),
              };
              try {
                if (isEdit) {
                  await ref
                      .read(apiClientProvider)
                      .patch('/units/${unit.id}', data: body);
                } else {
                  final bid = ref.read(currentBuildingIdProvider);
                  await ref.read(apiClientProvider).post(
                      '/buildings/$bid/units',
                      data: body);
                }
                ref.invalidate(unitsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              } on DioException catch (e) {
                if (ctx.mounted) {
                  final msg = e.response?.statusCode == 409
                      ? l10n.phoneTaken
                      : l10n.error;
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(msg)));
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
