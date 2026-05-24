import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

class _FakeShare implements ExternalShareService {
  final List<String> sharedPaths = [];
  String? openedUrl;
  @override
  Future<void> shareFiles(List<String> paths) async =>
      sharedPaths.addAll(paths);
  @override
  Future<void> openUrl(String url) async => openedUrl = url;
}

MediaItem _item() => MediaItem(
  id: 'i1',
  title: 'Clip',
  sourceUrl: 'https://y/i1',
  site: 'youtube',
  filePath: '/tmp/i1.mp4',
  type: 'video',
  createdAt: DateTime.utc(2026),
  storageState: 'private',
  isFavorite: false,
);

void main() {
  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('long-press opens the action sheet with all actions', (
    tester,
  ) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          externalShareServiceProvider.overrideWithValue(_FakeShare()),
        ],
        child: MaterialApp(
          home: Scaffold(body: MediaGrid(items: [_item()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Clip'));
    await tester.pumpAndSettle();

    for (final label in const [
      'Open',
      'Favorite',
      'Save to device',
      'Add to collection',
      'Move to folder',
      'Edit info',
      'Edit in Studio',
      'Share file',
      'Copy source URL',
      'Open source link',
      'Delete',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('Delete from the menu is confirm-gated', (tester) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          externalShareServiceProvider.overrideWithValue(_FakeShare()),
        ],
        child: MaterialApp(
          home: Scaffold(body: MediaGrid(items: [_item()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Clip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this item?'), findsOneWidget);
  });

  testWidgets('Share file routes the path to the share service', (
    tester,
  ) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final share = _FakeShare();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          externalShareServiceProvider.overrideWithValue(share),
        ],
        child: MaterialApp(
          home: Scaffold(body: MediaGrid(items: [_item()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Clip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share file'));
    await tester.pumpAndSettle();

    expect(share.sharedPaths, ['/tmp/i1.mp4']);
  });

  testWidgets('no Select entry in the default menu (P9h)', (tester) async {
    tallSurface(tester);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          externalShareServiceProvider.overrideWithValue(_FakeShare()),
        ],
        child: MaterialApp(
          home: Scaffold(body: MediaGrid(items: [_item()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Clip'));
    await tester.pumpAndSettle();
    expect(find.text('Select'), findsNothing);
  });
}
