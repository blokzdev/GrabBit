import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/settings/presentation/widgets/info_hint.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_tiles.dart';

void main() {
  testWidgets('InfoHintButton opens a sheet showing the hint body on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoHintButton(
            InfoHint(title: 'About captions', body: 'Captions explained here.'),
          ),
        ),
      ),
    );

    // Body is hidden until tapped (touch-first, not long-press).
    expect(find.text('Captions explained here.'), findsNothing);

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    expect(find.text('About captions'), findsOneWidget);
    expect(find.text('Captions explained here.'), findsOneWidget);
  });

  testWidgets('SettingsChoiceTile fires onChanged with the selected value', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsChoiceTile<String>(
            title: 'Format',
            value: 'a',
            onChanged: (v) => picked = v,
            items: const [
              DropdownMenuItem(value: 'a', child: Text('Option A')),
              DropdownMenuItem(value: 'b', child: Text('Option B')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Option A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option B').last);
    await tester.pumpAndSettle();

    expect(picked, 'b');
  });

  testWidgets('SettingsSwitchTile renders a tappable hint when provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsSwitchTile(
            title: 'Auto-build transcripts',
            value: false,
            onChanged: (_) {},
            hint: const InfoHint(
              title: 'Auto-build transcripts',
              body: 'Build a transcript from captions automatically.',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(InfoHintButton), findsOneWidget);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(
      find.text('Build a transcript from captions automatically.'),
      findsOneWidget,
    );
  });
}
