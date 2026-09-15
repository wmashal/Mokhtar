import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import '../users/users_screen.dart';

/// Manager-only: building configuration (water/electricity prices, fee)
/// plus the entry point to user management.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _waterPriceCtrl = TextEditingController();
  final _electricityPriceCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider).value;
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/buildings/${auth!.buildingId}');
      setState(() {
        _waterPriceCtrl.text = '${res.data['water_unit_price']}';
        _electricityPriceCtrl.text = '${res.data['electricity_unit_price']}';
        _feeCtrl.text = '${res.data['monthly_fee']}';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = ref.read(authProvider).value;
    try {
      await ref.read(apiClientProvider).patch(
        '/buildings/${auth!.buildingId}',
        data: {
          'water_unit_price': _waterPriceCtrl.text.trim(),
          'electricity_unit_price': _electricityPriceCtrl.text.trim(),
          'monthly_fee': _feeCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.saved)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _waterPriceCtrl.dispose();
    _electricityPriceCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _waterPriceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.waterPrice} (₪/m³)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.water_drop_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _electricityPriceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.electricityPrice} (₪/kWh)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.bolt_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _feeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: '${l10n.monthlyFee} (₪)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.save),
                ),
                const SizedBox(height: 32),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: Text(l10n.userManagement),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsersScreen()),
                  ),
                ),
              ],
            ),
    );
  }
}
