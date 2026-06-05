import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/presentation/connection_path_provider.dart';
import 'package:grabbit/features/library/presentation/connection_path_screen.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  title: 'Clip $id',
  sourceUrl: 'u',
  site: 'youtube',
  filePath: '/m/$id',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

Future<void> _pump(WidgetTester tester, ConnectionPathView? view) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectionPathProvider(('a', 'c')).overrideWith((ref) async => view),
      ],
      child: const MaterialApp(
        home: ConnectionPathScreen(sourceId: 'a', targetId: 'c'),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the item chain with connectors', (tester) async {
    await _pump(
      tester,
      ConnectionPathView(
        items: [_item('a'), _item('b'), _item('c')],
        connectors: const ['same channel', "shared tag 'blender'"],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clip a'), findsOneWidget);
    expect(find.text('Clip b'), findsOneWidget);
    expect(find.text('Clip c'), findsOneWidget);
    expect(find.text('same channel'), findsOneWidget);
    expect(find.text("shared tag 'blender'"), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no path', (tester) async {
    await _pump(tester, null);
    await tester.pumpAndSettle();

    expect(find.text('No connection found'), findsOneWidget);
  });
}
