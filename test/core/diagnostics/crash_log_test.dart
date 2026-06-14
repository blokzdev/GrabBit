import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/diagnostics/crash_log.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crashlog_test');
    file = File('${dir.path}/last_crash.log');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('record writes a parseable report; readPending round-trips', () async {
    final log = CrashLog.forFile(file, 'v1.2.3 (build 9)');
    log.record(StateError('boom'), StackTrace.fromString('#0 main'));

    expect(file.existsSync(), isTrue);
    final report = await log.readPending();
    expect(report, isNotNull);
    expect(report!.text, contains('Bad state: boom'));
    expect(report.text, contains('v1.2.3 (build 9)'));
    expect(report.text, contains('#0 main'));
    expect(report.time.isAfter(DateTime(2020)), isTrue); // parsed Time: header
  });

  test('readPending returns null when nothing recorded', () async {
    expect(await CrashLog.forFile(file).readPending(), isNull);
  });

  test('record keeps only the latest (overwrites)', () async {
    final log = CrashLog.forFile(file);
    log.record(Exception('first'), null);
    log.record(Exception('second'), null);
    final report = await log.readPending();
    expect(report!.text, contains('second'));
    expect(report.text, isNot(contains('first')));
  });

  test('clear deletes the recorded crash', () async {
    final log = CrashLog.forFile(file);
    log.record(Exception('x'), null);
    expect(file.existsSync(), isTrue);
    await log.clear();
    expect(file.existsSync(), isFalse);
    expect(await log.readPending(), isNull);
  });

  test('disabled() is a no-op (never throws, never records)', () async {
    final log = CrashLog.disabled();
    log.record(Exception('ignored'), StackTrace.current);
    expect(await log.readPending(), isNull);
    await log.clear(); // must not throw
  });
}
