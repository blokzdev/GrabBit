import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/capture/web_page_fetcher.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  HttpWebPageFetcher fetcherReturning(
    http.Response Function(http.Request) handler,
  ) => HttpWebPageFetcher(client: MockClient((req) async => handler(req)));

  test('returns the body + final url on a 200 HTML response', () async {
    final fetcher = fetcherReturning(
      (req) => http.Response(
        '<html><body>hello</body></html>',
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
        request: req,
      ),
    );

    final page = await fetcher.fetch('https://example.com/article');
    expect(page.body, contains('hello'));
    expect(page.finalUrl, 'https://example.com/article');
  });

  test('rejects a non-https/invalid URL before any request', () async {
    final fetcher = HttpWebPageFetcher(
      client: MockClient((_) async => fail('must not request')),
    );
    await expectLater(
      fetcher.fetch('not a url'),
      throwsA(
        isA<WebFetchException>().having(
          (e) => e.code,
          'code',
          WebFetchError.invalidUrl,
        ),
      ),
    );
  });

  test('maps a non-HTML content-type to notHtml', () async {
    final fetcher = fetcherReturning(
      (req) => http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
        request: req,
      ),
    );
    await expectLater(
      fetcher.fetch('https://api.example.com/data'),
      throwsA(
        isA<WebFetchException>().having(
          (e) => e.code,
          'code',
          WebFetchError.notHtml,
        ),
      ),
    );
  });

  test('maps a non-2xx status to httpError', () async {
    final fetcher = fetcherReturning(
      (req) => http.Response('nope', 404, request: req),
    );
    await expectLater(
      fetcher.fetch('https://example.com/missing'),
      throwsA(
        isA<WebFetchException>().having(
          (e) => e.code,
          'code',
          WebFetchError.httpError,
        ),
      ),
    );
  });
}
