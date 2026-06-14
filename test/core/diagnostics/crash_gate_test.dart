import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/diagnostics/crash_log.dart';
import 'package:grabbit/core/diagnostics/crash_log_providers.dart';

void main() {
  final t = DateTime(2026, 6, 14, 12);
  CrashReport report(DateTime time) => CrashReport(time: time, text: 'x');

  test('no report → never show', () {
    expect(shouldShowCrash(null, null), isFalse);
    expect(shouldShowCrash(null, t), isFalse);
  });

  test('a report never seen before → show', () {
    expect(shouldShowCrash(report(t), null), isTrue);
  });

  test('a report newer than the last seen → show', () {
    expect(
      shouldShowCrash(report(t.add(const Duration(minutes: 1))), t),
      isTrue,
    );
  });

  test('a report same as / older than the last seen → hide', () {
    expect(shouldShowCrash(report(t), t), isFalse);
    expect(
      shouldShowCrash(report(t.subtract(const Duration(minutes: 1))), t),
      isFalse,
    );
  });
}
