import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/features/capture/presentation/barcode_scan_screen.dart';
import 'package:grabbit/features/capture/presentation/camera_permission.dart';
import 'package:permission_handler/permission_handler.dart';

class _FakePermission extends CameraPermission {
  const _FakePermission(this._status);
  final PermissionStatus _status;
  @override
  Future<PermissionStatus> request() async => _status;
  @override
  Future<void> openSettings() async {}
}

void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/grab/scan',
    routes: [
      GoRoute(
        path: '/grab/scan',
        builder: (context, state) => const BarcodeScanScreen(),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, PermissionStatus status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraPermissionProvider.overrideWithValue(_FakePermission(status)),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('denied → shows rationale + allow-camera action', (tester) async {
    await pump(tester, PermissionStatus.denied);
    expect(find.textContaining('needs camera access'), findsOneWidget);
    expect(find.text('Allow camera'), findsOneWidget);
  });

  testWidgets('permanentlyDenied → shows open-settings action', (tester) async {
    await pump(tester, PermissionStatus.permanentlyDenied);
    expect(find.text('Open settings'), findsOneWidget);
  });
}
