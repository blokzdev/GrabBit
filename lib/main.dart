import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/app.dart';
import 'package:grabbit/core/diagnostics/crash_log.dart';
import 'package:grabbit/core/diagnostics/crash_log_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On-device crash capture (no telemetry): resolve the log file + app version
  // once, then route all uncaught errors to it so the next launch can surface a
  // copyable report. FlutterError.onError (framework) + PlatformDispatcher.onError
  // (everything else) is the complete pair post-Flutter-3.3.
  final crashLog = await CrashLog.create();
  FlutterError.onError = (details) {
    crashLog.record(details.exception, details.stack);
    FlutterError.presentError(details); // keep the console dump (debug)
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashLog.record(error, stack);
    return true;
  };
  runApp(
    ProviderScope(
      overrides: [crashLogProvider.overrideWithValue(crashLog)],
      child: const GrabBitApp(),
    ),
  );
}
