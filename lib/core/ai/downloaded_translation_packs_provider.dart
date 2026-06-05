import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/translation_provider.dart';

/// The BCP-47 codes of downloaded ML Kit translation packs (P13f-2) — drives the
/// Translation settings card's "Downloaded / delete" state. Existence-based
/// (cheap); invalidate after a download or delete to refresh.
final downloadedTranslationPacksProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(translationEngineProvider).downloadedLanguageCodes(),
);
