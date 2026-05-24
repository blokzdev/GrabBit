import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/subtitle_files.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('grabbit_subs'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('subtitleSidecars finds only subtitle files beside the media', () {
    File('${dir.path}/clip.mp4').writeAsStringSync('v');
    File('${dir.path}/clip.en.srt').writeAsStringSync('s');
    File('${dir.path}/clip.es.vtt').writeAsStringSync('s');
    File('${dir.path}/clip.info.json').writeAsStringSync('{}');
    File('${dir.path}/clip.jpg').writeAsStringSync('t');

    final subs = subtitleSidecars(
      '${dir.path}/clip.mp4',
    ).map((f) => f.path.split('/').last).toSet();
    expect(subs, {'clip.en.srt', 'clip.es.vtt'});
  });

  test('subtitleSidecars is empty when the folder is missing', () {
    expect(subtitleSidecars('/no/such/dir/clip.mp4'), isEmpty);
  });

  test('subtitleLabel extracts the language segment', () {
    expect(subtitleLabel('/m/clip.en.srt'), 'en');
    expect(subtitleLabel('/m/clip.pt-BR.vtt'), 'pt-BR');
    expect(subtitleLabel('/m/clip.srt'), 'clip'); // no language segment
  });
}
