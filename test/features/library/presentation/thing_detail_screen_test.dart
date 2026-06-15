import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_hydration.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';
import 'package:grabbit/features/library/presentation/thing_detail_screen.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Fixed-settings controller, to drive the Simple/Advanced gate in tests.
class _FakeSettings extends SettingsController {
  _FakeSettings(this._value);
  final SettingsModel _value;
  @override
  Future<SettingsModel> build() async => _value;
}

Thing _recipe() => Thing(
  id: 'thing_1',
  type: 'Recipe',
  jsonld:
      '{"@type":"Recipe","name":"Carbonara","recipeIngredient":["eggs"],'
      '"grabbit:provenance":{"provenance":"single-tool"}}',
  name: 'Carbonara',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

ThingRelationships _relationships() => const ThingRelationships(
  outgoing: [
    ThingRelation(
      'isBasedOn',
      HydratedNode(id: 'item-1', title: 'Source Clip', type: 'VideoObject'),
    ),
  ],
  incoming: [],
  mentions: [],
);

void main() {
  Future<void> pump(WidgetTester tester, {UiMode mode = UiMode.simple}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(
            () => _FakeSettings(SettingsModel(mode: mode)),
          ),
          thingByIdProvider('thing_1').overrideWith((ref) async => _recipe()),
          thingRelationshipsProvider(
            'thing_1',
          ).overrideWith((ref) async => _relationships()),
        ],
        child: const MaterialApp(home: ThingDetailScreen(thingId: 'thing_1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the Recipe header, bespoke card, and a Based-on link', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Carbonara'), findsOneWidget); // header name
    // 'Recipe' shows in the header subtitle and the bespoke card title.
    expect(find.text('Recipe'), findsWidgets);
    expect(find.text('Ingredients'), findsOneWidget); // bespoke card section
    expect(find.text('•  eggs'), findsOneWidget); // bespoke ingredient row
    expect(find.text('Based on'), findsOneWidget); // relationships section
    // The link shows the hydrated target name, not the raw id.
    expect(find.text('Source Clip'), findsOneWidget);
    expect(find.text('item-1'), findsNothing);
  });

  testWidgets('shows the share/export action for an exportable type', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('hides the JSON-LD action in Simple mode', (tester) async {
    await pump(tester);
    expect(find.byIcon(Icons.code), findsNothing);
  });

  testWidgets('shows the JSON-LD action in Advanced mode', (tester) async {
    await pump(tester, mode: UiMode.advanced);
    expect(find.byIcon(Icons.code), findsOneWidget);
  });
}
