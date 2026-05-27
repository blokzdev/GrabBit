import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/lifecycle/app_lifecycle_provider.dart';

void main() {
  test('defaults to resumed and reflects set()', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(appLifecycleStateProvider),
      AppLifecycleState.resumed,
    );

    container
        .read(appLifecycleStateProvider.notifier)
        .set(AppLifecycleState.paused);
    expect(container.read(appLifecycleStateProvider), AppLifecycleState.paused);
  });
}
