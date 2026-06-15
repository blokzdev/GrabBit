import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper over the camera runtime permission (P16b-4), behind a provider so
/// the barcode-scan screen's permission states are testable without a device.
class CameraPermission {
  const CameraPermission();

  Future<PermissionStatus> request() => Permission.camera.request();

  Future<void> openSettings() => openAppSettings();
}

final cameraPermissionProvider = Provider<CameraPermission>(
  (ref) => const CameraPermission(),
);
