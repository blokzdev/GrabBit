import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_engine_provider.dart';
import 'package:grabbit/core/ai/model_catalog.dart';

void main() {
  test('activeEmbedderModel resolves Gecko via the tier matrix (P12a)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Tier defaults to low (the probe is async/Noop on the test host); the
    // matrix maps every tier to the Gecko floor today, so selection == default.
    expect(container.read(activeEmbedderModelProvider), defaultEmbedder);
  });
}
