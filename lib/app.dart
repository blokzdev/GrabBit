import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/routing/app_router.dart';
import 'package:grabbit/core/theme/app_theme.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class GrabBitApp extends ConsumerStatefulWidget {
  const GrabBitApp({super.key});

  @override
  ConsumerState<GrabBitApp> createState() => _GrabBitAppState();
}

class _GrabBitAppState extends ConsumerState<GrabBitApp>
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final enabled =
          ref.read(settingsControllerProvider).asData?.value.appLock.enabled ??
          false;
      if (enabled) ref.read(lockControllerProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    // Render with sensible defaults while settings load (sub-frame DB read);
    // a splash would only flash.
    final settings = ref.watch(settingsControllerProvider).asData?.value;
    final useDynamic = settings?.dynamicColor ?? true;
    final themeMode = switch (settings?.theme) {
      ThemeChoice.light => ThemeMode.light,
      ThemeChoice.dark => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'GrabBit',
          theme: AppTheme.light(useDynamic ? lightDynamic?.harmonized() : null),
          darkTheme: AppTheme.dark(
            useDynamic ? darkDynamic?.harmonized() : null,
          ),
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
