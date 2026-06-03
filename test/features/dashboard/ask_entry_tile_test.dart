import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/ask_entry_tile.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

import '../../support/graph_fakes.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  title: id,
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/tmp/$id',
  type: 'video',
  sizeBytes: 1,
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

Future<void> _pump(
  WidgetTester tester, {
  required GenerationModel? model,
  required bool graphAvailable,
  required List<MediaItem> items,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeGenerationModelProvider.overrideWith((ref) => model),
        graphStoreProvider.overrideWithValue(
          FakeGraphStore(available: graphAvailable),
        ),
        libraryItemsProvider.overrideWith((ref) => Stream.value(items)),
      ],
      child: const MaterialApp(home: Scaffold(body: AskEntryTile())),
    ),
  );
}

void main() {
  testWidgets(
    'shows when generation is eligible, graph available, items exist',
    (tester) async {
      await _pump(
        tester,
        model: qwen3_0_6b,
        graphAvailable: true,
        items: [_item('a')],
      );
      await tester.pump();
      expect(find.text('Ask your library'), findsOneWidget);
    },
  );

  testWidgets('auto-hides when no generation model fits the device', (
    tester,
  ) async {
    await _pump(tester, model: null, graphAvailable: true, items: [_item('a')]);
    await tester.pump();
    expect(find.text('Ask your library'), findsNothing);
  });

  testWidgets('auto-hides when the graph is unavailable', (tester) async {
    await _pump(
      tester,
      model: qwen3_0_6b,
      graphAvailable: false,
      items: [_item('a')],
    );
    await tester.pump();
    expect(find.text('Ask your library'), findsNothing);
  });

  testWidgets('auto-hides when the library is empty', (tester) async {
    await _pump(
      tester,
      model: qwen3_0_6b,
      graphAvailable: true,
      items: const [],
    );
    await tester.pump();
    expect(find.text('Ask your library'), findsNothing);
  });
}
