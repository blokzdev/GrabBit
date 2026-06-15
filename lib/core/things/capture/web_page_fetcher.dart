import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Why a web-page fetch failed (P16b-2) — a small typed taxonomy so the UI can
/// show a friendly, actionable message (mirrors `DownloadErrorCode`).
enum WebFetchError {
  /// Not a parseable https URL.
  invalidUrl,

  /// Connection failed / offline / DNS.
  network,

  /// Timed out before the page arrived.
  timeout,

  /// The server answered with a non-2xx status.
  httpError,

  /// The response wasn't an HTML document (e.g. a PDF, image, or JSON API).
  notHtml,
}

/// A web-page fetch failure carrying a typed [code] and a user-facing [message].
class WebFetchException implements Exception {
  const WebFetchException(this.code, this.message, {this.cause});

  final WebFetchError code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'WebFetchException($code): $message';
}

/// A successfully fetched page: its HTML [body] and the [finalUrl] after any
/// redirects (used as the capture's `sourceRef`).
class FetchedPage {
  const FetchedPage({required this.body, required this.finalUrl});

  final String body;
  final String finalUrl;
}

/// Fetches a web page's HTML for the capture pipeline (P16b-2). The single seam
/// for the app's only user-initiated page fetch — pure interface so it's swappable
/// (Windows P17) and fakeable in tests; the model/curator never touch the network.
abstract interface class WebPageFetcher {
  Future<FetchedPage> fetch(String url);
}

/// The default [WebPageFetcher] over `package:http`: https-only, follows
/// redirects, a [timeout] cap, a size cap, and a `Content-Type: text/html` check.
/// No cookies, no auth, no telemetry — a plain GET with a generic UA.
class HttpWebPageFetcher implements WebPageFetcher {
  HttpWebPageFetcher({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Cap the downloaded body so a pathological page can't exhaust memory (~5 MB
  /// of HTML is far more than any article needs).
  static const int _maxBytes = 5 * 1024 * 1024;

  @override
  Future<FetchedPage> fetch(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw const WebFetchException(
        WebFetchError.invalidUrl,
        'Enter a valid web address (https://…).',
      );
    }

    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: const {'User-Agent': 'GrabBit', 'Accept': 'text/html'},
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw WebFetchException(
        WebFetchError.timeout,
        'The page took too long to respond. Try again.',
        cause: e,
      );
    } catch (e) {
      throw WebFetchException(
        WebFetchError.network,
        'Network problem. Check your connection and try again.',
        cause: e,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebFetchException(
        WebFetchError.httpError,
        "Couldn't open this page (HTTP ${response.statusCode}).",
      );
    }

    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('html')) {
      throw const WebFetchException(
        WebFetchError.notHtml,
        "This link isn't a web page we can read. Try a downloadable link, or add it manually.",
      );
    }

    if (response.bodyBytes.length > _maxBytes) {
      throw const WebFetchException(
        WebFetchError.notHtml,
        'This page is too large to read.',
      );
    }

    return FetchedPage(
      body: response.body,
      finalUrl: response.request?.url.toString() ?? uri.toString(),
    );
  }
}

final webPageFetcherProvider = Provider<WebPageFetcher>(
  (ref) => HttpWebPageFetcher(),
);
