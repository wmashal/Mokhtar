import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';

import 'core/theme/theme.dart';
import 'features/admin/admin_screen.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: MokhtarApp()));
}

class MokhtarApp extends ConsumerWidget {
  const MokhtarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Mokhtar',
      debugShowCheckedModeBanner: false,
      // Arabic-first: default locale is Arabic, RTL handled automatically.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildMokhtarTheme(),
      home: auth.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, _) => const LoginScreen(),
        data: (state) {
          if (!state.isLoggedIn) return const LoginScreen();
          // System admin: the buildings panel until he opens a building.
          if (state.isAdmin && ref.watch(activeBuildingProvider) == null) {
            return const AdminScreen();
          }
          return const HomeScreen();
        },
      ),
    );
  }
}
