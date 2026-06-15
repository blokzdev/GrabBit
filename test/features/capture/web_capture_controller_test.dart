import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/capture/capture_service.dart';
import 'package:grabbit/core/things/capture/web_page_fetcher.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/core/things/thing_suggestion_repository.dart';
import 'package:grabbit/features/capture/presentation/web_capture_controller.dart';
import 'package:grabbit/features/notifications/data/notification_center.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';

class _FakeFetcher implements WebPageFetcher {
  _FakeFetcher.page(this._page);
  _FakeFetcher.error(this._error);

  FetchedPage? _page;
  WebFetchException? _error;

  @override
  Future<FetchedPage> fetch(String url) async {
    if (_error != null) throw _error!;
    return _page!;
  }
}

CaptureGen _genThatFails() => (
  generate: (toolDefs, prompt, {systemPrompt}) async =>
      fail('generate must not be called'),
  modelId: null,
);

CaptureGen _genReturning(StructuredResult r) => (
  generate: (toolDefs, prompt, {systemPrompt}) async => r,
  modelId: 'qwen3-0-6b',
);

CaptureGen _genUnavailable() => (
  generate: (toolDefs, prompt, {systemPrompt}) async =>
      throw const InferenceException(InferenceErrorCode.unavailable, 'off'),
  modelId: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SchemaOrgVocabulary vocab;
  late AppDatabase db;
  late ThingRepository things;
  late ThingSuggestionRepository suggestions;
  late NotificationCenter center;
  late NotificationsRepository notifications;

  setUpAll(() async {
    vocab = SchemaOrgVocabulary.parse(
      await rootBundle.loadString(schemaOrgVocabularyAsset),
    );
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    things = ThingRepository(db);
    suggestions = ThingSuggestionRepository(db);
    notifications = NotificationsRepository(db);
    center = NotificationCenter(
      notifications,
      () async => const SettingsModel(),
    );
  });

  tearDown(() => db.close());

  DefaultWebCaptureController controller(
    WebPageFetcher fetcher,
    CaptureGen gen,
  ) => DefaultWebCaptureController(
    fetcher,
    CaptureService(vocab),
    CaptureCommitService(things),
    suggestions,
    center,
    () async => gen,
    now: () => DateTime.utc(2026, 6, 15),
    newCaptureId: () => 'cap_test',
  );

  test('structured markup → asserts a Thing directly (committed)', () async {
    const html = '''
<html><body>
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Recipe","name":"Soup",
 "recipeIngredient":["water"]}
</script></body></html>''';
    final result = await controller(
      _FakeFetcher.page(
        const FetchedPage(body: html, finalUrl: 'https://x.test/r'),
      ),
      _genThatFails(),
    ).capture('https://x.test/r');

    expect(result, isA<WebCaptureCommitted>());
    expect((result as WebCaptureCommitted).type, 'Recipe');
    expect(await things.countThings(), 1);
    // Direct assert leaves nothing pending.
    expect(await suggestions.countPending(), 0);
  });

  test('markup-less page + a model → pending suggestion for review', () async {
    const html =
        '<html><head><title>Easy Carbonara Recipe</title></head>'
        '<body><article><p>Add the ingredients, stir the sauce, simmer, '
        'and serve this recipe.</p></article></body></html>';
    final result = await controller(
      _FakeFetcher.page(
        const FetchedPage(body: html, finalUrl: 'https://x.test/c'),
      ),
      _genReturning(
        const StructuredResult(
          toolName: 'Recipe',
          arguments: {'name': 'Carbonara'},
        ),
      ),
    ).capture('https://x.test/c');

    expect(result, isA<WebCaptureReview>());
    expect((result as WebCaptureReview).captureId, 'cap_test');
    // Stored under the synthetic capture id, not asserted.
    expect(await things.countThings(), 0);
    final pending = await suggestions.pendingForItem('cap_test');
    expect(pending, hasLength(1));
    expect(pending.single.type, 'Recipe');
    // A review notification deep-links to the capture review surface.
    final feed = await notifications.watchFeed().first;
    expect(feed.single.targetRoute, '/capture/cap_test/suggestions');
  });

  test('markup-less page + no model → nothing found', () async {
    const html =
        '<html><body><article><p>Add the ingredients and stir the '
        'sauce and simmer this recipe well.</p></article></body></html>';
    final result = await controller(
      _FakeFetcher.page(
        const FetchedPage(body: html, finalUrl: 'https://x.test/n'),
      ),
      _genUnavailable(),
    ).capture('https://x.test/n');

    expect(result, isA<WebCaptureNothingFound>());
    expect(await things.countThings(), 0);
    expect(await suggestions.countPending(), 0);
  });

  test('a fetch failure surfaces as an error result', () async {
    final result = await controller(
      _FakeFetcher.error(
        const WebFetchException(WebFetchError.network, 'no net'),
      ),
      _genThatFails(),
    ).capture('https://x.test/down');

    expect(result, isA<WebCaptureError>());
    expect((result as WebCaptureError).code, WebFetchError.network);
  });
}
