import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/download_error.dart';
import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/features/downloader/presentation/downloader_controller.dart';
import 'package:grabbit/features/queue/data/queued_download.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// An expandable URL with the entries it produced (or an error).
class ExpandedSource {
  const ExpandedSource({
    required this.url,
    this.entries = const [],
    this.error,
  });

  final String url;
  final List<MediaEntry> entries;
  final String? error;
}

class SelectionState {
  const SelectionState({
    this.sources = const [],
    this.selected = const {},
    this.preset = QualityPreset.best,
    this.expanding = false,
  });

  final List<ExpandedSource> sources;
  final Set<String> selected; // entry urls
  final QualityPreset preset;
  final bool expanding;

  List<MediaEntry> get allEntries => [for (final s in sources) ...s.entries];
  int get totalCount => allEntries.length;

  SelectionState copyWith({
    List<ExpandedSource>? sources,
    Set<String>? selected,
    QualityPreset? preset,
    bool? expanding,
  }) => SelectionState(
    sources: sources ?? this.sources,
    selected: selected ?? this.selected,
    preset: preset ?? this.preset,
    expanding: expanding ?? this.expanding,
  );
}

/// Expands one or more pasted URLs into a selectable entry list and turns the
/// chosen entries into download requests (run now or held in a batch).
class SelectionController extends Notifier<SelectionState> {
  @override
  SelectionState build() => const SelectionState();

  /// Injects already-expanded sources (e.g. handed off from the downloader when
  /// a single URL turned out to be a playlist), selecting all entries.
  void setSources(List<ExpandedSource> sources) {
    state = SelectionState(
      sources: sources,
      selected: {
        for (final s in sources)
          for (final e in s.entries) e.url,
      },
    );
  }

  /// Expands each whitespace/newline-separated URL, capturing per-URL errors.
  Future<void> expandUrls(String raw) async {
    final urls = raw
        .split(RegExp(r'\s+'))
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();
    if (urls.isEmpty) return;

    state = state.copyWith(expanding: true);
    final engine = ref.read(downloadEngineProvider);
    final sources = <ExpandedSource>[];
    for (final url in urls) {
      try {
        final info = await engine.expand(url);
        sources.add(ExpandedSource(url: url, entries: info.entries));
      } on DownloadException catch (e) {
        sources.add(ExpandedSource(url: url, error: e.message));
      }
    }
    // Select everything by default.
    final selected = {
      for (final s in sources)
        for (final e in s.entries) e.url,
    };
    state = state.copyWith(
      sources: sources,
      selected: selected,
      expanding: false,
    );
  }

  void toggle(String entryUrl) {
    final next = Set<String>.from(state.selected);
    next.contains(entryUrl) ? next.remove(entryUrl) : next.add(entryUrl);
    state = state.copyWith(selected: next);
  }

  void selectAll() => state = state.copyWith(
    selected: {for (final e in state.allEntries) e.url},
  );

  void selectNone() => state = state.copyWith(selected: {});

  void setPreset(QualityPreset preset) =>
      state = state.copyWith(preset: preset);

  /// "Download now" — enqueue the selected entries and start them.
  Future<void> downloadNow() async {
    final batch = await _buildSelected();
    await ref.read(queueControllerProvider.notifier).enqueueNow(batch);
  }

  /// "Add to batch" — hold the selected entries for a later "Start all".
  Future<void> addToBatch() async {
    final batch = await _buildSelected();
    await ref.read(queueControllerProvider.notifier).enqueueHeld(batch);
  }

  Future<List<QueuedDownload>> _buildSelected() async {
    final dir = await ref.read(mediaStorageProvider).mediaDirectory();
    final settings = await ref.read(settingsControllerProvider.future);
    final preset = state.preset;
    final entries = state.allEntries.where(
      (e) => state.selected.contains(e.url),
    );
    return [
      for (final e in entries)
        QueuedDownload(
          request: DownloadRequest(
            taskId:
                'dl_${DateTime.now().microsecondsSinceEpoch}_${e.url.hashCode}',
            url: e.url,
            outputDir: dir.path,
            filenameTemplate: '%(title)s.%(ext)s',
            formatId: preset.formatSelector,
            audioOnly: preset.audioOnly,
            container: preset.audioOnly ? 'm4a' : 'mp4',
            subtitles: settings.defaultSubtitles,
            embedThumbnail: settings.embedThumbnail,
            embedMetadata: settings.embedMetadata,
          ),
          title: e.title,
          durationSec: e.durationSec,
          originalUrl: e.url,
        ),
    ];
  }
}

final selectionControllerProvider =
    NotifierProvider<SelectionController, SelectionState>(
      SelectionController.new,
    );
