import 'package:grabbit/core/engine/engine_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'engine_update_controller.g.dart';

class EngineUpdateState {
  const EngineUpdateState({this.version, this.updating = false, this.message});

  final String? version;
  final bool updating;
  final String? message;
}

/// Loads the yt-dlp version and runs a user-triggered self-update.
@riverpod
class EngineUpdateController extends _$EngineUpdateController {
  @override
  Future<EngineUpdateState> build() async {
    final version = await ref.read(downloadEngineProvider).version();
    return EngineUpdateState(version: version.ytDlp);
  }

  Future<void> runUpdate() async {
    final current = state.asData?.value.version;
    state = AsyncData(EngineUpdateState(version: current, updating: true));
    try {
      await ref.read(downloadEngineProvider).update();
      final version = await ref.read(downloadEngineProvider).version();
      state = AsyncData(
        EngineUpdateState(version: version.ytDlp, message: 'Up to date'),
      );
    } catch (e) {
      state = AsyncData(
        EngineUpdateState(version: current, message: 'Update failed'),
      );
    }
  }
}
