import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/graph/graph_sync_provider.dart';
import 'package:grabbit/core/routing/app_router.dart';
import 'package:grabbit/core/theme/app_theme.dart';
import 'package:grabbit/features/downloader/data/share_intake_service.dart';
import 'package:grabbit/features/lock/auto_lock_controller.dart';
import 'package:grabbit/features/settings/data/privacy_service.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/engine_update_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class GrabBitApp extends ConsumerStatefulWidget {
  const GrabBitApp({super.key});

  @override
  ConsumerState<GrabBitApp> createState() => _GrabBitAppState();
}

class _GrabBitAppState extends ConsumerState<GrabBitApp>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _shareSub;
  ProviderSubscription<bool>? _secureFlagSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Apply the saved FLAG_SECURE preference at startup and whenever it changes.
    _secureFlagSub = ref.listenManual(
      settingsControllerProvider.select(
        (s) => s.asData?.value.blockScreenshots ?? false,
      ),
      (_, blockScreenshots) =>
          ref.read(privacyServiceProvider).setSecureFlag(blockScreenshots),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoUpdate();
      _maybeSyncGraph();
      _initShareIntake();
    });
  }

  /// Starts the graph sync listener and self-heals the derived Cozo index if its
  /// projection shape changed (or on first run). Non-blocking; offline-safe.
  Future<void> _maybeSyncGraph() async {
    final settings = await ref.read(settingsControllerProvider.future);
    final sync = ref.read(graphSyncServiceProvider); // starts the live listener
    await sync.syncIfStale(
      storedVersion: settings.graphIndexVersion,
      stamp: ref.read(settingsControllerProvider.notifier).setGraphIndexVersion,
    );
  }

  /// Routes links shared into the app (Android share sheet, P8a) to the
  /// Add-Download screen, pre-filled. Covers both the cold-start share and any
  /// that arrive while the app is running.
  void _initShareIntake() {
    final service = ref.read(shareIntakeProvider);
    if (service == null) return;
    _shareSub = service.sharedUrls.listen(_openShared);
    unawaited(
      service
          .takeInitialUrl()
          .then((url) {
            if (url != null) _openShared(url);
          })
          .catchError((_) {}),
    );
  }

  void _openShared(String url) {
    if (!mounted) return;
    ref.read(pendingSharedUrlProvider.notifier).put(url);
    ref.read(appRouterProvider).go('/add');
  }

  /// Throttled, non-blocking yt-dlp self-update on launch (keeps the engine
  /// current so public videos don't fail with "Please sign in"). Offline-safe.
  Future<void> _maybeAutoUpdate() async {
    final settings = await ref.read(settingsControllerProvider.future);
    if (!shouldAutoCheckEngine(
      enabled: settings.autoCheckEngineUpdate,
      lastCheck: settings.lastEngineCheck,
      now: DateTime.now(),
    )) {
      return;
    }
    // Stamp before updating so a slow/failed update doesn't retry every launch.
    await ref
        .read(settingsControllerProvider.notifier)
        .setLastEngineCheck(DateTime.now());
    try {
      await ref.read(downloadEngineProvider).update();
    } catch (_) {}
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _secureFlagSub?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLock = ref.read(autoLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        autoLock.appBackgrounded();
      case AppLifecycleState.resumed:
        autoLock.appForegrounded();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    // Render with sensible defaults while settings load (sub-frame DB read);
    // a splash would only flash.
    final settings = ref.watch(settingsControllerProvider).asData?.value;
    final useDynamic = settings?.dynamicColor ?? true;
    final amoled = settings?.amoledDark ?? false;
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
            amoled,
          ),
          themeMode: themeMode,
          routerConfig: router,
        );
      },
    );
  }
}
