import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/core/auth_store.dart';
import 'src/router.dart';
import 'src/ui/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: InsightsStaffApp()));
}

class InsightsStaffApp extends ConsumerStatefulWidget {
  const InsightsStaffApp({super.key});

  @override
  ConsumerState<InsightsStaffApp> createState() => _InsightsStaffAppState();
}

class _InsightsStaffAppState extends ConsumerState<InsightsStaffApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(authControllerProvider.notifier).refreshSessionOnAppOpen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Insights Staff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
