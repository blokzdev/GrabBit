/// Known tracking / referrer query params stripped from shared links. Kept
/// deliberately narrow so meaningful params survive (e.g. YouTube's `v`, `list`,
/// `t`; Instagram post ids).
const _trackingParams = {
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_term',
  'utm_content',
  'fbclid',
  'gclid',
  'igshid',
  'si',
  'feature',
  'spm',
};

/// Pulls the first http(s) URL out of arbitrary shared text. A share sheet often
/// hands over prose around the link ("Title — https://… via App"), so we scan
/// rather than assume the whole string is a URL. Returns null when none is found.
String? extractSharedUrl(String text) {
  final match = RegExp(r'https?://\S+').firstMatch(text);
  if (match == null) return null;
  // Trim punctuation that commonly clings to a URL embedded in prose.
  final raw = match.group(0)!.replaceAll(RegExp(r'''[)\]>.,"']+$'''), '');
  return stripTrackingParams(raw);
}

/// Removes [_trackingParams] from a URL's query while preserving order and all
/// other params. Returns [url] unchanged when it can't be parsed.
String stripTrackingParams(String url) {
  final Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException {
    return url;
  }
  if (uri.queryParametersAll.isEmpty) return url;

  final kept = <String, String>{};
  for (final entry in uri.queryParametersAll.entries) {
    if (_trackingParams.contains(entry.key.toLowerCase())) continue;
    kept[entry.key] = entry.value.isEmpty ? '' : entry.value.last;
  }

  final cleaned = kept.isEmpty
      ? uri.replace(query: '')
      : uri.replace(queryParameters: kept);
  // Uri.replace(query: '') leaves a dangling '?'; drop it for tidiness.
  final out = cleaned.toString();
  return out.endsWith('?') ? out.substring(0, out.length - 1) : out;
}
