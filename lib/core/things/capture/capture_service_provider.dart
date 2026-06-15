import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/things/capture/capture_service.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';

/// The [CaptureService] over the lazily-loaded schema.org vocabulary. Hand-written
/// (not codegen) — the universal-intake surfaces (P16b) read it via
/// `ref.watch(captureServiceProvider.future)`.
final captureServiceProvider = FutureProvider<CaptureService>(
  (ref) async =>
      CaptureService(await ref.watch(schemaOrgVocabularyProvider.future)),
);
