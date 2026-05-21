import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits an event whenever network connectivity changes, so the queue can
/// re-attempt Wi-Fi-only downloads once an unmetered network is back.
abstract class NetworkMonitor {
  Stream<void> get onChanged;
}

class ConnectivityNetworkMonitor implements NetworkMonitor {
  @override
  Stream<void> get onChanged =>
      Connectivity().onConnectivityChanged.map((_) {});
}

class NoopNetworkMonitor implements NetworkMonitor {
  @override
  Stream<void> get onChanged => const Stream.empty();
}

final networkMonitorProvider = Provider<NetworkMonitor>(
  (ref) =>
      Platform.isAndroid ? ConnectivityNetworkMonitor() : NoopNetworkMonitor(),
);
