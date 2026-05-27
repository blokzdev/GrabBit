import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raises terminal **OS (system-tray) notifications** for download events (P11d),
/// complementing the in-app Activity Inbox. Tapping one carries a go_router
/// `route` payload so the app can deep-link to the relevant screen.
///
/// A no-op off Android / in tests, so callers stay platform-agnostic and the
/// download queue is unit-testable without the plugin.
abstract class SystemNotificationService {
  /// One-time setup. [onTap] receives the tapped notification's route payload
  /// (foreground/warm taps). Cold-start taps are handled via [takeLaunchRoute].
  Future<void> initialize({required void Function(String route) onTap});

  /// Shows a download-activity notification carrying [route] as its tap payload.
  Future<void> showDownload({
    required String taskId,
    required String title,
    String? body,
    required String route,
    required bool isError,
  });

  /// The route the app was cold-launched with by tapping a notification, if any
  /// (consumed once). Null when the app wasn't launched from a notification.
  Future<String?> takeLaunchRoute();
}

/// One-shot activity channel, distinct from the foreground service's ongoing
/// `grabbit_downloads` progress channel (id 42) so the two never clobber.
const _channelId = 'grabbit_activity';
const _channelName = 'Activity';

class LocalSystemNotificationService implements SystemNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  void Function(String route)? _onTap;
  bool _initialized = false;

  @override
  Future<void> initialize({required void Function(String route) onTap}) async {
    _onTap = onTap;
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _onTap?.call(route);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Download activity from GrabBit',
            importance: Importance.defaultImportance,
          ),
        );
    _initialized = true;
  }

  @override
  Future<void> showDownload({
    required String taskId,
    required String title,
    String? body,
    required String route,
    required bool isError,
  }) async {
    if (!_initialized) {
      // Defensive: startup init normally runs first, but a very early completion
      // shouldn't drop the notification (taps still route via the stored _onTap).
      await initialize(onTap: _onTap ?? (_) {});
    }
    await _plugin.show(
      id: taskId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Download activity from GrabBit',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      payload: route,
    );
  }

  @override
  Future<String?> takeLaunchRoute() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
}

class NoopSystemNotificationService implements SystemNotificationService {
  @override
  Future<void> initialize({required void Function(String route) onTap}) async {}

  @override
  Future<void> showDownload({
    required String taskId,
    required String title,
    String? body,
    required String route,
    required bool isError,
  }) async {}

  @override
  Future<String?> takeLaunchRoute() async => null;
}

final systemNotificationServiceProvider = Provider<SystemNotificationService>(
  (ref) => Platform.isAndroid
      ? LocalSystemNotificationService()
      : NoopSystemNotificationService(),
);
