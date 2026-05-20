import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/routing/app_router.dart';
import 'package:grabbit/core/theme/app_theme.dart';

class GrabBitApp extends ConsumerWidget {
  const GrabBitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'GrabBit',
          theme: AppTheme.light(lightDynamic?.harmonized()),
          darkTheme: AppTheme.dark(darkDynamic?.harmonized()),
          themeMode: ThemeMode.system,
          routerConfig: router,
        );
      },
    );
  }
}
