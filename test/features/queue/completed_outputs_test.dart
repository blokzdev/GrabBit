import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/queue/data/completed_outputs.dart';

List<File> _files(List<String> paths) => paths.map(File.new).toList();

void main() {
  group('classifyDownloadOutputs', () {
    test('excludes subtitle and json sidecars, keeps the media + thumb', () {
      final out = classifyDownloadOutputs(
        _files([
          '/d/clip.mp4',
          '/d/clip.info.json',
          '/d/clip.jpg',
          '/d/clip.en.srt',
          '/d/clip.es.vtt',
          '/d/clip.live_chat.json',
        ]),
      );
      expect(out.media.map((f) => f.path), ['/d/clip.mp4']);
      expect(out.thumb?.path, '/d/clip.jpg');
      expect(out.info?.path, '/d/clip.info.json');
    });

    test('returns all media files for split-chapters (sorted)', () {
      final out = classifyDownloadOutputs(
        _files([
          '/d/clip - 003 Outro.mkv',
          '/d/clip - 001 Intro.mkv',
          '/d/clip - 002 Body.mkv',
          '/d/clip.info.json',
        ]),
      );
      expect(out.media.map((f) => f.path), [
        '/d/clip - 001 Intro.mkv',
        '/d/clip - 002 Body.mkv',
        '/d/clip - 003 Outro.mkv',
      ]);
    });

    test('excludes youtube .srv auto-sub formats', () {
      final out = classifyDownloadOutputs(
        _files(['/d/clip.mp4', '/d/clip.en.srv3']),
      );
      expect(out.media.map((f) => f.path), ['/d/clip.mp4']);
    });

    test('no media yields an empty media list', () {
      final out = classifyDownloadOutputs(_files(['/d/clip.en.srt']));
      expect(out.media, isEmpty);
    });
  });
}
