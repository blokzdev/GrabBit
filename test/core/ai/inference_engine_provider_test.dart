import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_engine_provider.dart';
import 'package:grabbit/core/ai/model_catalog.dart';

void main() {
  test('activeEmbedderModel returns the default embedder (P10g-2 seam)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(activeEmbedderModelProvider), defaultEmbedder);
  });
}
