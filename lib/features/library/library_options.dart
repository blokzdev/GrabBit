import 'package:grabbit/features/library/data/metadata_repository.dart';

/// Single source of truth for *which* sorts/filters apply to *which* media
/// types, driving the type-aware narrowing of the library sort menu and filter
/// sheet (P10i). Pure Dart; consumed by the UI and the controller's
/// reconciliation.

/// Every media type GrabBit stores.
const Set<String> kAllTypes = {'video', 'audio', 'image'};

/// Types that carry a timeline (duration, transcripts, …).
const Set<String> kTimedTypes = {'video', 'audio'};

/// Types that have pixel dimensions (for the resolution filter).
const Set<String> kSizedTypes = {'video', 'image'};

/// The active type scope: the explicit selection, or all types when nothing is
/// selected (an empty selection means "no type filter").
Set<String> activeTypeScope(Set<String> selected) =>
    selected.isEmpty ? kAllTypes : selected;

/// Media types a sort is meaningful for. Duration sorts narrow to timed media;
/// everything else (incl. upload-date — any media can carry one) is universal.
Set<String> sortAppliesTo(LibrarySort sort) => switch (sort) {
  LibrarySort.longest || LibrarySort.shortest => kTimedTypes,
  _ => kAllTypes,
};

/// Whether a sort should be offered for the current type selection.
bool sortVisible(LibrarySort sort, Set<String> selectedTypes) =>
    sortAppliesTo(sort).intersection(activeTypeScope(selectedTypes)).isNotEmpty;

/// Whether the has-transcript filter applies to the active scope (timed media).
bool transcriptApplies(Set<String> selectedTypes) =>
    kTimedTypes.intersection(activeTypeScope(selectedTypes)).isNotEmpty;

/// Whether the duration range filter applies to the active scope (timed media).
bool durationApplies(Set<String> selectedTypes) =>
    kTimedTypes.intersection(activeTypeScope(selectedTypes)).isNotEmpty;

/// Whether the resolution filter applies to the active scope (sized media).
bool resolutionApplies(Set<String> selectedTypes) =>
    kSizedTypes.intersection(activeTypeScope(selectedTypes)).isNotEmpty;

/// Corrects a query after its type selection changes: resets an inapplicable
/// sort (→ relevance while searching, else newest) and clears filters that no
/// longer apply to the active type scope. Date ranges always apply.
LibraryQuery reconcile(LibraryQuery q) {
  var next = q;
  if (!sortVisible(next.sort, next.types)) {
    next = next.copyWith(
      sort: next.search.trim().isEmpty
          ? LibrarySort.newest
          : LibrarySort.relevance,
    );
  }
  if (next.hasTranscript && !transcriptApplies(next.types)) {
    next = next.copyWith(hasTranscript: false);
  }
  if (next.durationBucket != null && !durationApplies(next.types)) {
    next = next.copyWith(durationBucket: () => null);
  }
  if (next.resolutionBucket != null && !resolutionApplies(next.types)) {
    next = next.copyWith(resolutionBucket: () => null);
  }
  return next;
}
