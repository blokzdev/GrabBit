import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/inference_engine_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/onboarding/presentation/ai_setup_screen.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// In-memory [InferenceEngine] for widget tests: records the download call and
/// optionally fails, so the screen's set-up vs. skip flows are exercised without
/// the native runtime.
class _FakeInferenceEngine implements InferenceEngine {
  _FakeInferenceEngine({this.failDownload = false});

  final bool failDownload;
  bool downloadCalled = false;

  @override
  EmbedderModel get model => embeddingGemmaEmbedder;

  @override
  bool get isAvailable => downloadCalled && !failDownload;

  @override
  int get dimension => embeddingGemmaEmbedder.dimension;

  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    downloadCalled = true;
    onProgress?.call(0.5);
    if (failDownload) {
      throw const InferenceException(InferenceErrorCode.downloadFailed, 'boom');
    }
    onProgress?.call(1);
  }

  @override
  Future<bool> ensureReady() async => isAvailable;

  @override
  Future<List<double>> embed(String text) async =>
      List<double>.filled(dimension, 0);

  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async => [
    for (final _ in texts) List<double>.filled(dimension, 0),
  ];

  @override
  Future<void> close() async {}
}

Future<(ProviderContainer, AppDatabase)> _harness(
  InferenceEngine engine, {
  SettingsModel? initial,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  if (initial != null) await SettingsRepository(db).write(initial);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      inferenceEngineProvider.overrideWithValue(engine),
    ],
  );
  await container.read(settingsControllerProvider.future);
  return (container, db);
}

void main() {
  testWidgets('Skip marks ai-setup seen without downloading', (tester) async {
    final engine = _FakeInferenceEngine();
    final (container, db) = await _harness(engine);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiSetupScreen()),
      ),
    );

    await tester.tap(find.text('Skip for now'));
    await tester.pump();

    final settings = await SettingsRepository(db).read();
    expect(settings.aiSetupSeen, isTrue);
    expect(settings.semanticSearchEnabled, isFalse);
    expect(engine.downloadCalled, isFalse);
  });

  testWidgets('Set up enables semantic search and downloads the model', (
    tester,
  ) async {
    final engine = _FakeInferenceEngine();
    final (container, db) = await _harness(engine);
    addTearDown(container.dispose);
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiSetupScreen()),
      ),
    );

    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();

    expect(engine.downloadCalled, isTrue);
    final settings = await SettingsRepository(db).read();
    expect(settings.semanticSearchEnabled, isTrue);
    expect(settings.aiSetupSeen, isTrue);
  });

  testWidgets('Set up reverts and surfaces an error on download failure', (
    tester,
  ) async {
    final engine = _FakeInferenceEngine(failDownload: true);
    // Simulate a new user fresh off the disclaimer (aiSetupSeen still false).
    final (container, db) = await _harness(
      engine,
      initial: const SettingsModel(
        disclaimerAccepted: true,
        aiSetupSeen: false,
      ),
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiSetupScreen()),
      ),
    );

    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();

    expect(find.textContaining('try again later'), findsOneWidget);
    final settings = await SettingsRepository(db).read();
    expect(settings.semanticSearchEnabled, isFalse);
    // Stays on the screen (not marked seen) so the user can retry or skip.
    expect(settings.aiSetupSeen, isFalse);
  });
}
