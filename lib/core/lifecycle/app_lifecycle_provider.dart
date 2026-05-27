import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's current [AppLifecycleState], updated by the root widget's lifecycle
/// observer (`lib/app.dart`). Lets background services decide whether the app is
/// in the foreground — e.g. P11d suppresses OS notifications while it's resumed,
/// since the in-app inbox already covers that case. Defaults to [resumed].
class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void set(AppLifecycleState state) => this.state = state;
}

final appLifecycleStateProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );
