import 'package:flutter/foundation.dart';

/// Where a searched setting lives: one of the settings sub-screen routes, or
/// `'landing'` for a control shown inline on the main settings screen.
const settingsLandingDestination = 'landing';
const downloadsSettingsRoute = '/settings/downloads';
const captionsSettingsRoute = '/settings/captions';
const aiSettingsRoute = '/settings/ai';
const notificationsSettingsRoute = '/settings/notifications';

const Set<String> kSettingsDestinations = {
  settingsLandingDestination,
  downloadsSettingsRoute,
  captionsSettingsRoute,
  aiSettingsRoute,
  notificationsSettingsRoute,
};

/// One searchable control. [label] is the control's exact on-screen title (the
/// search-index drift guard asserts this text renders on [destination]).
/// [section] is the friendly group name shown as the result's subtitle and, for
/// landing entries, the key used to scroll to the inline section.
@immutable
class SettingsSearchEntry {
  const SettingsSearchEntry({
    required this.label,
    required this.section,
    required this.destination,
    this.keywords = const [],
  });

  final String label;
  final String section;
  final String destination;
  final List<String> keywords;

  bool get isLanding => destination == settingsLandingDestination;
}

/// The hand-maintained search index. One entry per notable control across the
/// landing and the three sub-screens. Keep [SettingsSearchEntry.label] equal to
/// the on-screen title — `settings_search_test.dart` pumps each destination and
/// asserts every label renders, so this can't silently drift from the UI.
const List<SettingsSearchEntry> kSettingsSearchIndex = [
  // --- Downloads sub-screen ---------------------------------------------------
  SettingsSearchEntry(
    label: 'Advanced mode',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['simple', 'expert'],
  ),
  SettingsSearchEntry(
    label: 'Default quality',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['resolution', '1080', '720', 'audio only'],
  ),
  SettingsSearchEntry(
    label: 'Max concurrent downloads',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['parallel', 'at once', 'simultaneous'],
  ),
  SettingsSearchEntry(
    label: 'Faster downloads (beta)',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['speed', 'fragments', 'parallel'],
  ),
  SettingsSearchEntry(
    label: 'Wi-Fi only',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['mobile data', 'network', 'cellular'],
  ),
  SettingsSearchEntry(
    label: 'Pause when storage is low',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['free space', 'disk', 'storage'],
  ),
  SettingsSearchEntry(
    label: 'Pause on low battery',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['power saver'],
  ),
  SettingsSearchEntry(
    label: 'Low-battery threshold',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['battery percent'],
  ),
  SettingsSearchEntry(
    label: 'Download filename',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['template', 'name', 'naming'],
  ),
  SettingsSearchEntry(
    label: 'Embed thumbnail',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['cover art'],
  ),
  SettingsSearchEntry(
    label: 'Embed metadata',
    section: 'Downloads',
    destination: downloadsSettingsRoute,
    keywords: ['tags', 'id3'],
  ),
  // --- Advanced download options (Downloads sub-screen, Advanced mode) --------
  SettingsSearchEntry(
    label: 'Concurrent fragments',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['parallel pieces', 'speed'],
  ),
  SettingsSearchEntry(
    label: 'Download speed limit',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['rate limit', 'throttle', 'bandwidth'],
  ),
  SettingsSearchEntry(
    label: 'Audio format',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['codec', 'mp3', 'm4a', 'opus'],
  ),
  SettingsSearchEntry(
    label: 'Audio quality',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['bitrate', 'kbps'],
  ),
  SettingsSearchEntry(
    label: 'Skip already-downloaded',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['archive', 'duplicate', 'dedupe'],
  ),
  SettingsSearchEntry(
    label: 'SponsorBlock',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['sponsor', 'ads', 'skip segments'],
  ),
  SettingsSearchEntry(
    label: 'Embed chapters',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['markers'],
  ),
  SettingsSearchEntry(
    label: 'Split into chapters',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['split', 'segments'],
  ),
  SettingsSearchEntry(
    label: 'Extra yt-dlp arguments',
    section: 'Advanced download options',
    destination: downloadsSettingsRoute,
    keywords: ['args', 'flags', 'command line', 'advanced'],
  ),
  // --- Captions & transcripts sub-screen --------------------------------------
  SettingsSearchEntry(
    label: 'Download captions',
    section: 'Captions & transcripts',
    destination: captionsSettingsRoute,
    keywords: ['subtitles', 'cc'],
  ),
  SettingsSearchEntry(
    label: 'Caption languages',
    section: 'Captions & transcripts',
    destination: captionsSettingsRoute,
    keywords: ['subtitle languages', 'langs'],
  ),
  SettingsSearchEntry(
    label: 'Include auto-generated',
    section: 'Captions & transcripts',
    destination: captionsSettingsRoute,
    keywords: ['auto captions', 'asr'],
  ),
  SettingsSearchEntry(
    label: 'Caption format',
    section: 'Captions & transcripts',
    destination: captionsSettingsRoute,
    keywords: ['srt', 'vtt', 'subtitle format'],
  ),
  SettingsSearchEntry(
    label: 'Build a searchable transcript',
    section: 'Captions & transcripts',
    destination: captionsSettingsRoute,
    keywords: ['transcript', 'transcribe'],
  ),
  SettingsSearchEntry(
    label: 'Backfill on open',
    section: 'Captions & transcripts',
    destination: captionsSettingsRoute,
    keywords: ['transcript', 'older downloads'],
  ),
  SettingsSearchEntry(
    label: 'Auto-fetch captions for transcripts',
    section: 'Captions & transcripts',
    destination: captionsSettingsRoute,
    keywords: ['auto download captions'],
  ),
  // --- AI & graph sub-screen --------------------------------------------------
  SettingsSearchEntry(
    label: 'Rebuild graph index',
    section: 'AI & graph',
    destination: aiSettingsRoute,
    keywords: ['graph', 'reproject', 'reindex'],
  ),
  SettingsSearchEntry(
    label: 'Semantic search',
    section: 'AI & graph',
    destination: aiSettingsRoute,
    keywords: ['ai', 'meaning', 'embeddings', 'vector'],
  ),
  SettingsSearchEntry(
    label: 'Test embedder',
    section: 'AI & graph',
    destination: aiSettingsRoute,
    keywords: ['diagnostic', 'embedding model'],
  ),
  // --- Notifications sub-screen -----------------------------------------------
  SettingsSearchEntry(
    label: 'Keep notifications',
    section: 'Notifications',
    destination: notificationsSettingsRoute,
    keywords: ['retention', 'history', 'clear', 'days', 'auto delete'],
  ),
  SettingsSearchEntry(
    label: 'Download activity',
    section: 'Notifications',
    destination: notificationsSettingsRoute,
    keywords: ['download notifications', 'complete', 'finished', 'alerts'],
  ),
  SettingsSearchEntry(
    label: 'Transcript activity',
    section: 'Notifications',
    destination: notificationsSettingsRoute,
    keywords: ['transcript notifications', 'captions', 'alerts'],
  ),
  SettingsSearchEntry(
    label: 'AI activity',
    section: 'Notifications',
    destination: notificationsSettingsRoute,
    keywords: ['ai notifications', 'semantic', 'embeddings', 'alerts'],
  ),
  SettingsSearchEntry(
    label: 'Graph activity',
    section: 'Notifications',
    destination: notificationsSettingsRoute,
    keywords: ['graph notifications', 'index', 'rebuild', 'alerts'],
  ),
  // --- Landing (inline sections) ----------------------------------------------
  SettingsSearchEntry(
    label: 'yt-dlp',
    section: 'Downloader engine',
    destination: settingsLandingDestination,
    keywords: ['engine', 'update', 'version'],
  ),
  SettingsSearchEntry(
    label: 'Check for updates on app open',
    section: 'Downloader engine',
    destination: settingsLandingDestination,
    keywords: ['auto update', 'yt-dlp'],
  ),
  SettingsSearchEntry(
    label: 'Auto-save to device',
    section: 'Storage',
    destination: settingsLandingDestination,
    keywords: ['export', 'gallery'],
  ),
  SettingsSearchEntry(
    label: 'Export folder',
    section: 'Storage',
    destination: settingsLandingDestination,
    keywords: ['gallery', 'directory'],
  ),
  SettingsSearchEntry(
    label: 'Storage & cleanup',
    section: 'Storage',
    destination: settingsLandingDestination,
    keywords: ['usage', 'duplicates', 'free space'],
  ),
  SettingsSearchEntry(
    label: 'Theme',
    section: 'Appearance',
    destination: settingsLandingDestination,
    keywords: ['dark', 'light', 'system'],
  ),
  SettingsSearchEntry(
    label: 'Dynamic color',
    section: 'Appearance',
    destination: settingsLandingDestination,
    keywords: ['material you', 'wallpaper'],
  ),
  SettingsSearchEntry(
    label: 'Pure black (AMOLED)',
    section: 'Appearance',
    destination: settingsLandingDestination,
    keywords: ['amoled', 'oled', 'dark'],
  ),
  SettingsSearchEntry(
    label: 'App lock',
    section: 'Security',
    destination: settingsLandingDestination,
    keywords: ['pin', 'biometric', 'fingerprint', 'passcode'],
  ),
  SettingsSearchEntry(
    label: 'Block screenshots',
    section: 'Privacy',
    destination: settingsLandingDestination,
    keywords: ['screenshot', 'recents', 'secure flag'],
  ),
  SettingsSearchEntry(
    label: 'Secure delete',
    section: 'Privacy',
    destination: settingsLandingDestination,
    keywords: ['overwrite', 'shred', 'wipe'],
  ),
  SettingsSearchEntry(
    label: 'About',
    section: 'General',
    destination: settingsLandingDestination,
    keywords: ['version', 'licenses', 'donations'],
  ),
  SettingsSearchEntry(
    label: 'Reset to defaults',
    section: 'General',
    destination: settingsLandingDestination,
    keywords: ['restore', 'clear settings'],
  ),
  SettingsSearchEntry(
    label: 'Clear cache',
    section: 'General',
    destination: settingsLandingDestination,
    keywords: ['temporary files', 'free space'],
  ),
];

/// Case-insensitive substring search over each entry's label + keywords.
/// A blank query returns nothing (the caller shows the normal landing instead).
List<SettingsSearchEntry> searchSettings(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return [
    for (final e in kSettingsSearchIndex)
      if ('${e.label} ${e.keywords.join(' ')}'.toLowerCase().contains(q)) e,
  ];
}
