int _seq = 0;

/// Process-unique download id. A timestamp keeps ids roughly time-ordered and
/// human-readable; the monotonic counter guarantees uniqueness even when many
/// ids are minted in the same microsecond or for duplicate URLs (the id is also
/// the media-item primary key and the on-disk filename prefix).
String newTaskId() => 'dl_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
