import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import 'my_meters_tab.dart';
import 'public_meters_tab.dart';
import 'rounds_tab.dart';

/// Meters tab. Everyone: my water history + public meters + rounds.
/// Manager additionally: create rounds, enter readings, issue invoices.
class MetersScreen extends ConsumerWidget {
  const MetersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.myMeters),
              Tab(text: l10n.publicMeters),
              Tab(text: l10n.readingRounds),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                MyMetersTab(),
                PublicMetersTab(),
                RoundsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
