import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/shell/app_shell.dart';
import 'state/inventory_controller.dart';

class GiroApp extends StatelessWidget {
  const GiroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giro — Controle de estoque',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('pt', 'BR'),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final onboarded =
        context.select<InventoryController, bool>((c) => c.onboarded);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: onboarded ? const AppShell() : const OnboardingPage(),
    );
  }
}
