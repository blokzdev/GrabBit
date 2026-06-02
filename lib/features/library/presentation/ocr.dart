/// Pure, engine-free helper for auto-OCR-on-download (P13b-3). Kept out of the
/// queue controller so the gating decision is unit-testable in isolation
/// (mirrors `autoSummaryDecision`).
library;

/// Whether a freshly downloaded item should be auto-scanned for text now.
/// [enabled] is `autoOcrOnDownload`; [engineAvailable] is whether ML Kit OCR can
/// run on this host; [isImage] is whether the item is an image; [alreadyScanned]
/// is whether OCR text is already stored.
bool shouldAutoOcr({
  required bool enabled,
  required bool engineAvailable,
  required bool isImage,
  required bool alreadyScanned,
}) => enabled && engineAvailable && isImage && !alreadyScanned;
