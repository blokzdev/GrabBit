import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// A persisted crash record: when it happened and the full plain-text report
/// (header + error + stack) the user can copy.
class CrashReport {
  const CrashReport({required this.time, required this.text});

  final DateTime time;
  final String text;
}

/// On-device crash capture (no telemetry, no upload). Uncaught Dart/Flutter
/// errors are written **synchronously** to a single app-private file; the next
/// launch surfaces them in a copyable modal (the user shares manually). Created
/// once in `main()` ([create]); a no-op [CrashLog.disabled] is the provider
/// default so tests / non-main contexts never touch disk.
class CrashLog {
  CrashLog._(this._file, this._appLabel);

  /// Configured instance writing to the given file. App version label is
  /// best-effort.
  CrashLog.forFile(this._file, [this._appLabel = '']);

  /// A no-op instance: [record] does nothing, [readPending] returns null.
  CrashLog.disabled() : _file = null, _appLabel = '';

  final File? _file;
  final String _appLabel;

  static const _header = 'GrabBit crash report';

  /// Resolves the app-private crash file (`<appSupport>/diagnostics/last_crash.log`,
  /// beside the graph index) and caches the app-version label once.
  static Future<CrashLog> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/diagnostics');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    var appLabel = '';
    try {
      final info = await PackageInfo.fromPlatform();
      appLabel = 'v${info.version} (build ${info.buildNumber})';
    } catch (_) {
      // Best-effort; a missing version must not block crash capture.
    }
    return CrashLog._(File('${dir.path}/last_crash.log'), appLabel);
  }

  /// Persists [error] + [stack] **synchronously**, overwriting any prior record
  /// (only the latest crash is kept). Never throws — a failure to record a crash
  /// must never itself crash the error handler.
  void record(Object error, StackTrace? stack) {
    final file = _file;
    if (file == null) return;
    try {
      final report = StringBuffer()
        ..writeln(_header)
        ..writeln('Time: ${DateTime.now().toIso8601String()}')
        ..writeln('App: ${_appLabel.isEmpty ? 'unknown' : _appLabel}')
        ..writeln(
          'Platform: ${Platform.operatingSystem} '
          '${Platform.operatingSystemVersion}',
        )
        ..writeln('---')
        ..writeln(error.toString())
        ..writeln('---')
        ..writeln(stack?.toString() ?? '(no stack trace)');
      file.writeAsStringSync(report.toString(), flush: true);
    } catch (_) {
      // Swallow: recording a crash must never throw.
    }
  }

  /// The last recorded crash, or null if none. The file is **kept** after
  /// reading (the next-launch gate dedupes by timestamp; About can re-view it).
  Future<CrashReport?> readPending() async {
    final file = _file;
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      final time = _parseTime(text) ?? await file.lastModified();
      return CrashReport(time: time, text: text);
    } catch (_) {
      return null;
    }
  }

  /// Deletes the recorded crash (if any).
  Future<void> clear() async {
    final file = _file;
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort.
    }
  }

  /// Parses the `Time:` header line into a [DateTime], or null if absent/invalid.
  static DateTime? _parseTime(String report) {
    for (final line in report.split('\n')) {
      if (line.startsWith('Time: ')) {
        return DateTime.tryParse(line.substring('Time: '.length).trim());
      }
    }
    return null;
  }
}
