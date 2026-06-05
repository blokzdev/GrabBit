import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/translation_engine.dart';
import 'package:grabbit/core/ai/translation_provider.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/library/presentation/item_translation_provider.dart';

/// In-memory translation engine: detects [detected], echoes a tagged
/// translation so assertions can see source/target were applied.
class FakeTranslationEngine implements TranslationEngine {
  FakeTranslationEngine({this.detected = 'es', this.downloaded = true});
  String detected;
  bool downloaded;

  @override
  bool get isAvailable => true;
  @override
  Future<String> identifyLanguage(String text) async => detected;
  @override
  Future<bool> isModelDownloaded(String code) async => downloaded;
  @override
  Future<Set<String>> downloadedLanguageCodes() async =>
      downloaded ? {detected} : const {};
  @override
  Future<void> downloadModel(String code, {bool requireWifi = true}) async {}
  @override
  Future<void> deleteModel(String code) async {}
  @override
  Future<String> translate(
    String text, {
    required String source,
    required String target,
  }) async => '[$source→$target] $text';
  @override
  Future<void> close() async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed({String? description, String? transcript}) async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'a',
            title: 'Vid',
            sourceUrl: 'u',
            site: 'youtube',
            filePath: '/m/a',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    await db
        .into(db.mediaMetadata)
        .insert(
          MediaMetadataCompanion.insert(
            itemId: 'a',
            description: Value(description),
            transcript: Value(transcript),
          ),
        );
  }

  ProviderContainer containerWith(FakeTranslationEngine engine) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        translationEngineProvider.overrideWithValue(engine),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'translate populates description + transcript + langs (P13b-2)',
    () async {
      await seed(description: 'Hola mundo', transcript: 'una leccion');
      final c = containerWith(FakeTranslationEngine());
      await c
          .read(itemTranslationProvider('a').notifier)
          .translate(source: 'es', target: 'en');

      final s = c.read(itemTranslationProvider('a'));
      expect(s.sourceLang, 'es');
      expect(s.targetLang, 'en');
      expect(s.description, '[es→en] Hola mundo');
      expect(s.transcript, '[es→en] una leccion');
      expect(s.hasTranslation, isTrue);
      expect(s.error, isNull);
    },
  );

  test('toggleOriginal flips the shown text (P13b-2)', () async {
    await seed(description: 'Hola');
    final c = containerWith(FakeTranslationEngine());
    final notifier = c.read(itemTranslationProvider('a').notifier);
    await notifier.translate(source: 'es', target: 'en');
    expect(c.read(itemTranslationProvider('a')).hasTranslation, isTrue);

    notifier.toggleOriginal();
    expect(c.read(itemTranslationProvider('a')).showingOriginal, isTrue);
    expect(c.read(itemTranslationProvider('a')).hasTranslation, isFalse);
  });

  test('only-description item leaves transcript null (P13b-2)', () async {
    await seed(description: 'Hola');
    final c = containerWith(FakeTranslationEngine());
    await c
        .read(itemTranslationProvider('a').notifier)
        .translate(source: 'es', target: 'en');
    final s = c.read(itemTranslationProvider('a'));
    expect(s.description, '[es→en] Hola');
    expect(s.transcript, isNull);
  });
}
