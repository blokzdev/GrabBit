/// Friendly, platform-aware description for a link the engine can't download
/// because **no extractor matched it** (`DownloadErrorCode.unsupportedSite`) —
/// i.e. "not supported (yet)", as opposed to a genuine error. Pure, so it's
/// unit-testable without a device.
library;

class UnsupportedLinkInfo {
  const UnsupportedLinkInfo({required this.message, required this.offerUpdate});

  final String message;

  /// Whether an engine update might plausibly add support. True only for
  /// entirely-unknown sites; false for known platforms' unsupported post types
  /// (e.g. TikTok photo posts), where updating won't help — so we don't send the
  /// user chasing a fix that can't work.
  final bool offerUpdate;
}

/// Known hosts → display label. Extensible — add a host to give it a named hint.
const Map<String, String> _platformLabels = {
  'tiktok.com': 'TikTok',
  'vt.tiktok.com': 'TikTok',
  'vm.tiktok.com': 'TikTok',
  'instagram.com': 'Instagram',
  'youtube.com': 'YouTube',
  'youtu.be': 'YouTube',
  'x.com': 'X',
  'twitter.com': 'X',
  't.co': 'X',
  'facebook.com': 'Facebook',
  'fb.watch': 'Facebook',
  'reddit.com': 'Reddit',
  'pinterest.com': 'Pinterest',
};

/// Describes why [pastedUrl] isn't supported and what the user can try. When
/// available, [rawError] is preferred for detection because it carries the
/// engine-*resolved* URL (e.g. a `vt.tiktok.com` short link expanded to
/// `tiktok.com/@user/photo/…`), which exposes the path for content-type hints.
UnsupportedLinkInfo describeUnsupportedLink(
  String pastedUrl, {
  String? rawError,
}) {
  final uri = _bestUri(pastedUrl, rawError);
  final host = _host(uri);
  final platform = host == null ? null : _platformLabels[host];
  final path = (uri?.path ?? '').toLowerCase();

  // Known content-type gaps on supported platforms (an update won't help).
  if (platform == 'TikTok' && path.contains('/photo/')) {
    return const UnsupportedLinkInfo(
      message:
          "TikTok photo/slideshow posts aren't supported yet — regular videos "
          'download fine.',
      offerUpdate: false,
    );
  }

  if (platform != null) {
    return UnsupportedLinkInfo(
      message:
          "This $platform link isn't supported — open a specific video or post "
          '(not a profile, search, or hashtag page).',
      offerUpdate: false,
    );
  }

  return const UnsupportedLinkInfo(
    message:
        "This site isn't supported yet. GrabBit supports many sites — updating "
        'the engine occasionally adds new ones.',
    offerUpdate: true,
  );
}

/// Prefer the resolved URL embedded in the engine error ("Unsupported URL: …"),
/// falling back to what the user pasted.
Uri? _bestUri(String pastedUrl, String? rawError) {
  if (rawError != null) {
    final match = RegExp(r'Unsupported URL:\s*(\S+)').firstMatch(rawError);
    final fromError = match?.group(1);
    if (fromError != null) {
      final u = Uri.tryParse(fromError);
      if (u != null && u.host.isNotEmpty) return u;
    }
  }
  return Uri.tryParse(pastedUrl.trim());
}

String? _host(Uri? uri) {
  final h = uri?.host.toLowerCase();
  if (h == null || h.isEmpty) return null;
  return h.startsWith('www.') ? h.substring(4) : h;
}
