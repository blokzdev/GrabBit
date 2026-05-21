import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/filename_template.dart';

void main() {
  group('resolveOutputTemplate', () {
    test('translates curated tokens to yt-dlp fields and appends ext', () {
      expect(
        resolveOutputTemplate('{channel} - {title}'),
        '%(uploader)s - %(title)s.%(ext)s',
      );
      expect(
        resolveOutputTemplate('{username}_{id}'),
        '%(uploader_id)s_%(id)s.%(ext)s',
      );
    });

    test('substitutes app-side {num} with a zero-padded 1-based index', () {
      expect(
        resolveOutputTemplate('{num} {title}', index: 1),
        '01 %(title)s.%(ext)s',
      );
      expect(
        resolveOutputTemplate('{num} {title}', index: 12),
        '12 %(title)s.%(ext)s',
      );
    });

    test('drops unknown tokens', () {
      expect(resolveOutputTemplate('{bogus}{title}'), '%(title)s.%(ext)s');
    });

    test('strips path separators so it cannot escape the task folder', () {
      expect(
        resolveOutputTemplate('{channel}/{title}'),
        '%(uploader)s-%(title)s.%(ext)s',
      );
      expect(resolveOutputTemplate(r'a\b'), 'a-b.%(ext)s');
    });

    test('falls back to the title template when empty', () {
      expect(resolveOutputTemplate(''), '%(title)s.%(ext)s');
      expect(resolveOutputTemplate('{bogus}'), '%(title)s.%(ext)s');
    });
  });

  group('renderPreview', () {
    test('uses sample values and a representative extension', () {
      expect(
        renderPreview('{channel} - {title}'),
        'Rick Astley - Never Gonna Give You Up.mp4',
      );
      expect(
        renderPreview('{num}. {title}'),
        '01. Never Gonna Give You Up.mp4',
      );
    });

    test('honors a custom extension and falls back when empty', () {
      expect(
        renderPreview('{title}', ext: 'm4a'),
        'Never Gonna Give You Up.m4a',
      );
      expect(renderPreview(''), 'Never Gonna Give You Up.mp4');
    });
  });
}
