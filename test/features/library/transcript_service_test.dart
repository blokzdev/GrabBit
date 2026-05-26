import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/library/data/transcript_service.dart';

void main() {
  late Directory dir;
  const service = TranscriptService();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('transcript_test');
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  String mediaPath() => '${dir.path}/clip.mp4';

  test('extracts and dedupes text from a .vtt sidecar', () async {
    await File('${dir.path}/clip.en.vtt').writeAsString(
      'WEBVTT\n\n'
      '00:00:00.000 --> 00:00:01.000\nthe quick brown\n\n'
      '00:00:01.000 --> 00:00:02.000\nquick brown fox\n',
    );
    final out = await service.extractTranscript(mediaPath());
    expect(out, 'the quick brown fox');
  });

  test('parses .srt sidecars too', () async {
    await File('${dir.path}/clip.srt').writeAsString(
      '1\n00:00:00,000 --> 00:00:01,000\nhello there\n\n'
      '2\n00:00:01,000 --> 00:00:02,000\ngeneral kenobi\n',
    );
    final out = await service.extractTranscript(mediaPath());
    expect(out, 'hello there general kenobi');
  });

  test('prefers the requested language track', () async {
    await File(
      '${dir.path}/clip.en.vtt',
    ).writeAsString('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\nenglish text\n');
    await File(
      '${dir.path}/clip.es.vtt',
    ).writeAsString('WEBVTT\n\n00:00:00.000 --> 00:00:01.000\ntexto espanol\n');
    final out = await service.extractTranscript(mediaPath(), preferLang: 'es');
    expect(out, 'texto espanol');
  });

  test('returns null when no parseable caption file exists', () async {
    await File('${dir.path}/clip.ass').writeAsString('[Script Info]\n');
    expect(await service.extractTranscript(mediaPath()), isNull);
  });
}
