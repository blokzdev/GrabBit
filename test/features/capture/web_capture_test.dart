import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/capture/data/web_capture.dart';

void main() {
  group('extractReadableText', () {
    test('prefers the <article> body and strips boilerplate', () {
      const html = '''
<html><body>
  <nav>Home About Contact</nav>
  <header>Site banner</header>
  <article>
    <h1>The Title</h1>
    <p>First real paragraph with enough words to count as content here.</p>
    <p>Second paragraph continues the article body for the reader to enjoy.</p>
  </article>
  <footer>Copyright 2026</footer>
  <script>var x = 1;</script>
</body></html>''';

      final text = extractReadableText(html);
      expect(text, contains('First real paragraph'));
      expect(text, contains('Second paragraph'));
      expect(text, isNot(contains('Home About Contact')));
      expect(text, isNot(contains('Copyright 2026')));
      expect(text, isNot(contains('var x')));
    });

    test('collapses whitespace', () {
      final html =
          '<article>'
          '<p>alpha</p>\n\n   <p>beta</p>'
          '<p>${'word ' * 60}</p>'
          '</article>';
      final text = extractReadableText(html);
      expect(text, isNot(contains('\n')));
      expect(text, isNot(contains('  ')));
    });

    test('falls back to the densest block when no <article>/<main>', () {
      final html =
          '''
<html><body>
  <div>tiny</div>
  <div><p>${'content ' * 50}</p></div>
</body></html>''';
      expect(extractReadableText(html), contains('content content'));
    });
  });

  group('extractPageTitle', () {
    test('prefers og:title over <title>', () {
      const html =
          '<html><head>'
          '<title>Tab title</title>'
          '<meta property="og:title" content="Social Title"/>'
          '</head><body></body></html>';
      expect(extractPageTitle(html), 'Social Title');
    });

    test('falls back to <title>', () {
      const html = '<html><head><title>Just a title</title></head></html>';
      expect(extractPageTitle(html), 'Just a title');
    });

    test('returns null when there is no title', () {
      expect(extractPageTitle('<html><body>hi</body></html>'), isNull);
    });
  });
}
