import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/ai_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/captions_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/downloads_settings_screen.dart';
import 'package:grabbit/features/settings/presentation/settings_screen.dart';
import 'package:grabbit/features/settings/presentation/settings_search.dart';

Widget _screenFor(String destination) {
  switch (destination) {
    case downloadsSettingsRoute:
      return const DownloadsSettingsScreen();
    case captionsSettingsRoute:
      return const CaptionsSettingsScreen();
    case aiSettingsRoute:
      return const AiSettingsScreen();
    default:
      return const SettingsScreen();
  }
}

void main() {
  group('searchSettings', () {
    test('matches on label', () {
      expect(
        searchSettings('sponsor').map((e) => e.label),
        contains('SponsorBlock'),
      );
      expect(
        searchSettings('amoled').map((e) => e.label),
        contains('Pure black (AMOLED)'),
      );
    });

    test('matches on keyword synonyms', () {
      expect(
        searchSettings('subtitles').map((e) => e.label),
        contains('Download captions'),
      );
      expect(searchSettings('pin').map((e) => e.label), contains('App lock'));
    });

    test('is case-insensitive', () {
      expect(searchSettings('SPONSOR'), isNotEmpty);
    });

    test('a blank query returns nothing', () {
      expect(searchSettings(''), isEmpty);
      expect(searchSettings('   '), isEmpty);
    });
  });

  test('every index entry has a known destination', () {
    for (final entry in kSettingsSearchIndex) {
      expect(
        kSettingsDestinations,
        contains(entry.destination),
        reason: '${entry.label} → ${entry.destination}',
      );
    }
  });

  testWidgets('drift guard: every indexed label renders on its destination', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Reveal every conditional row so all indexed labels are present.
    await SettingsRepository(db).write(
      const SettingsModel(
        mode: UiMode.advanced,
        subtitleLangs: 'en',
        pauseOnLowBattery: true,
      ),
    );

    for (final destination in kSettingsDestinations) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(home: _screenFor(destination)),
        ),
      );
      await tester.pumpAndSettle();

      for (final entry in kSettingsSearchIndex.where(
        (e) => e.destination == destination,
      )) {
        expect(
          find.text(entry.label),
          findsWidgets,
          reason: '"${entry.label}" missing on $destination',
        );
      }
    }
  });

  testWidgets('typing filters; tapping a landing result clears + reveals it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'amoled');
    await tester.pumpAndSettle();
    // Result row shows the label + its section.
    expect(find.text('Pure black (AMOLED)'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Pure black (AMOLED)'));
    await tester.pumpAndSettle();
    // Landing restored (search cleared) with the control on screen.
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('Pure black (AMOLED)'), findsOneWidget);
  });

  testWidgets('tapping a sub-screen result navigates to that screen', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/settings/downloads',
          builder: (_, _) => const DownloadsSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/captions',
          builder: (_, _) => const CaptionsSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/ai',
          builder: (_, _) => const AiSettingsScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(SearchBar), 'sponsorblock');
    await tester.pumpAndSettle();
    await tester.tap(find.text('SponsorBlock'));
    await tester.pumpAndSettle();

    // Downloads sub-screen is now shown.
    expect(find.text('Max concurrent downloads'), findsOneWidget);
  });
}
