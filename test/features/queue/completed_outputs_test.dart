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

    test('image-only download → the image is the media, no thumb (P13b-3)', () {
      final out = classifyDownloadOutputs(
        _files(['/d/photo.jpg', '/d/photo.info.json']),
      );
      expect(out.media.map((f) => f.path), ['/d/photo.jpg']);
      expect(out.thumb, isNull);
      expect(out.info?.path, '/d/photo.info.json');
    });

    test(
      'image + its written thumbnail → largest is media, smaller is thumb (P13b-3)',
      () async {
        // yt-dlp `--write-thumbnail` lands a second image beside the photo;
        // the larger file is the real photo, the smaller is its thumbnail.
        final dir = await Directory.systemTemp.createTemp('grabbit_cls_');
        addTearDown(() => dir.delete(recursive: true));
        final photo = File('${dir.path}/post.webp')
          ..writeAsBytesSync(List.filled(5000, 0));
        final thumb = File('${dir.path}/post.jpg')
          ..writeAsBytesSync(List.filled(300, 0));

        final out = classifyDownloadOutputs([
          thumb,
          photo,
        ]); // order shouldn't matter
        expect(out.media.map((f) => f.path), [photo.path]);
        expect(out.thumb?.path, thumb.path);
      },
    );

    test('video + image keeps the image as the thumbnail (unchanged)', () {
      final out = classifyDownloadOutputs(
        _files(['/d/clip.mp4', '/d/clip.jpg']),
      );
      expect(out.media.map((f) => f.path), ['/d/clip.mp4']);
      expect(out.thumb?.path, '/d/clip.jpg');
    });
  });
}
