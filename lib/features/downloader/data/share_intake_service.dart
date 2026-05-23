import 'dart:async';
import 'dart:io';

import 'package:grabbit/core/engine/pigeon/engine.pigeon.dart';
import 'package:grabbit/core/utils/shared_url.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'share_intake_service.g.dart';

/// Bridges the Android share sheet (P8a) into Dart: pulls the cold-start share
/// via [ShareHostApi] and streams warm-start ones delivered through
/// [ShareFlutterApi.onSharedText]. URLs are extracted/normalized before reaching
/// callers, so the UI only ever sees a clean link.
class ShareIntakeService implements ShareFlutterApi {
  ShareIntakeService({ShareHostApi? host}) : _host = host ?? ShareHostApi() {
    ShareFlutterApi.setUp(this);
  }

  final ShareHostApi _host;
  final StreamController<String> _urls = StreamController<String>.broadcast();

  /// Links shared while the app is already running.
  Stream<String> get sharedUrls => _urls.stream;

  /// The URL the app was cold-launched with via a share, if any (consumed once).
  Future<String?> takeInitialUrl() async {
    final text = await _host.takeInitialSharedText();
    return text == null ? null : extractSharedUrl(text);
  }

  @override
  void onSharedText(String text) {
    final url = extractSharedUrl(text);
    if (url != null) _urls.add(url);
  }

  void dispose() => _urls.close();
}

/// Share intake is an Android platform feature; null elsewhere (and in host-VM
/// tests) so callers can no-op safely.
@Riverpod(keepAlive: true)
ShareIntakeService? shareIntake(Ref ref) {
  if (!Platform.isAndroid) return null;
  final service = ShareIntakeService();
  ref.onDispose(service.dispose);
  return service;
}

/// A URL shared into the app awaiting pickup by the Add-Download screen.
@riverpod
class PendingSharedUrl extends _$PendingSharedUrl {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void put(String? url) => state = url;

  /// Reads and clears the pending URL so it isn't applied twice.
  String? take() {
    final url = state;
    state = null;
    return url;
  }
}
