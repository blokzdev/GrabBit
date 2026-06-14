import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/settings/presentation/about_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('renders the version and a licenses entry', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'GrabBit',
      packageName: 'dev.blokz.grabbit',
      version: '1.2.3',
      buildNumber: '7',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AboutScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('GrabBit'), findsWidgets);
    expect(find.text('v1.2.3 (build 7)'), findsOneWidget);
    expect(find.text('Open-source licenses'), findsOneWidget);
    expect(find.text('User responsibility & disclaimer'), findsOneWidget);
    // The crash diagnostic shows its empty state with no crashes recorded.
    expect(find.text('No crashes recorded'), findsOneWidget);
  });
}
