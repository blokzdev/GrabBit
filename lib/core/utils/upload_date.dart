/// Parses yt-dlp's `upload_date` (`YYYYMMDD`, UTC) into a [DateTime].
/// Returns null for anything malformed — wrong length, non-numeric, or an
/// impossible calendar date (e.g. month 13, Feb 30) — so a format change can't
/// silently corrupt stored metadata.
DateTime? parseUploadDate(String? raw) {
  if (raw == null || raw.length != 8) return null;
  final year = int.tryParse(raw.substring(0, 4));
  final month = int.tryParse(raw.substring(4, 6));
  final day = int.tryParse(raw.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime.utc(year, month, day);
  // DateTime.utc rolls invalid days over (Feb 30 → Mar 1); reject those.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
