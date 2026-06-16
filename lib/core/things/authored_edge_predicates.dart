import 'package:grabbit/core/things/thing_edge_repository.dart';

/// The curated set of relationship labels offered when a user authors an edge
/// (P16e). Loosely-typed (ADR-0004) — `relatedTo` is the default — but a small
/// shared vocabulary keeps authored links lightly normalized; a "Custom…" option
/// still allows any label.
const List<String> kAuthoredEdgePredicates = [
  kRelatedToPredicate, // relatedTo
  'about',
  'partOf',
  'similarTo',
  'references',
];
