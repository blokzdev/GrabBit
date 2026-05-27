int _seq = 0;

/// Process-unique activity-inbox id. A timestamp keeps ids roughly time-ordered
/// and human-readable; the monotonic counter guarantees uniqueness even when
/// many entries are posted in the same microsecond.
String newNotificationId() =>
    'ntf_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
