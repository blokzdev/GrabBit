import 'package:grabbit/features/library/data/metadata_repository.dart';

/// Single source of truth for *which* sorts/filters apply to *which* media
/// types, driving the type-aware narrowing of the library sort menu and filter
/// sheet (P10i). Pure Dart; consumed by the UI and the controller's
/// reconciliation.

/// Every media type GrabBit stores.
const Set<String> kAllTypes = {'video', 'audio', 'image'};

/// Types that carry a timeline (duration, transcripts, …).
const Set<String> kTimedTypes = {'video', 'audio'};

/// The active type scope: the explicit selection, or all types when nothing is
/// selected (an empty selection means "no type filter").
Set<String> activeTypeScope(Set<String> selected) =>
    selected.isEmpty ? kAllTypes : selected;

/// Media types a sort is meaningful for. Universal today; the duration sorts
/// (P10i-b) will narrow to [kTimedTypes].
Set<String> sortAppliesTo(LibrarySort sort) => kAllTypes;

/// Whether a sort should be offered for the current type selection.
bool sortVisible(LibrarySort sort, Set<String> selectedTypes) =>
    sortAppliesTo(sort).intersection(activeTypeScope(selectedTypes)).isNotEmpty;

/// Whether the has-transcript filter applies to the active scope (timed media).
bool transcriptApplies(Set<String> selectedTypes) =>
    kTimedTypes.intersection(activeTypeScope(selectedTypes)).isNotEmpty;

/// Corrects a query after its type selection changes: resets an inapplicable
/// sort (→ relevance while searching, else newest) and clears filters that no
/// longer apply to the active type scope.
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
  return next;
}
