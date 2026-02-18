import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/router.dart';
import 'src/ui/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: InsightsStaffApp()));
}

class InsightsStaffApp extends ConsumerWidget {
  const InsightsStaffApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Insights Staff',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
