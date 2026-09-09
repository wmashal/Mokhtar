import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

import '../../core/api/api_client.dart';
import '../auth/auth_provider.dart';
import '../finance/add_transaction_sheet.dart';
import '../finance/finance_screen.dart';
import '../units/units_screen.dart';
import '../meters/meters_screen.dart';
import '../meetings/meetings_screen.dart';
import '../announcements/announcements_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider).value;
    final isManager = auth?.isManager == true;

    // Manager sees: My statement, Building, Units, Meters, Meetings, Announcements
    // Resident sees: My statement, Building, Meetings, Announcements
    final destinations = <NavigationDestination>[
      NavigationDestination(icon: const Icon(Icons.person_outline), label: l10n.myStatement),
      NavigationDestination(icon: const Icon(Icons.account_balance_outlined), label: l10n.buildingStatement),
      if (isManager)
        NavigationDestination(icon: const Icon(Icons.apartment), label: l10n.units),
      if (isManager)
        NavigationDestination(icon: const Icon(Icons.water_drop_outlined), label: l10n.meters),
      NavigationDestination(icon: const Icon(Icons.groups_outlined), label: l10n.meetings),
      NavigationDestination(icon: const Icon(Icons.campaign_outlined), label: l10n.announcements),
    ];

    // clamp index when role changes the tab count
    if (_tab >= destinations.length) _tab = 0;

    final screens = <Widget>[
      const FinanceScreen(myOnly: true),
      const FinanceScreen(myOnly: false),
      if (isManager) const UnitsScreen(),
      if (isManager) const MetersScreen(),
      const MeetingsScreen(),
      const AnnouncementsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.logout,
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: screens[_tab],
      floatingActionButton: _buildFab(context, l10n, auth, isManager),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
      ),
    );
  }

  Widget? _buildFab(BuildContext context, AppLocalizations l10n, dynamic auth, bool isManager) {
    if (!isManager) return null;
    // FAB only on finance-related tabs (0,1) for now
    if (_tab > 1) return null;
    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: Text(l10n.addTransaction),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddTransactionSheet(buildingId: auth!.buildingId!),
      ),
    );
  }
}
