// Pigeon definition for the CozoDB graph/vector engine bridge (docs/GRAPH-SPEC.md §2).
//
// Generate with:
//   dart run pigeon --input pigeons/cozo.dart
//
// Mirrors the youtubedl-android bridge (pigeons/engine.dart): a thin @HostApi
// over the cozo_android Maven AAR. CozoDB is request/response (no streaming), so
// there is no @FlutterApi and the surface is just strings in / JSON out.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/graph/pigeon/cozo.pigeon.dart',
    kotlinOut: 'android/app/src/main/kotlin/dev/blokz/grabbit/CozoPigeon.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.blokz.grabbit'),
    dartPackageName: 'grabbit',
  ),
)
@HostApi()
abstract class CozoHostApi {
  /// Opens (or creates) the SQLite-backed Cozo database at [path]. Returns
  /// false if the native library is unavailable on this device's ABI (graph
  /// features then degrade gracefully); throws on a genuine open failure.
  @async
  bool openDb(String path);

  /// Runs a CozoScript [script] with JSON-encoded [paramsJson] and returns the
  /// JSON-encoded result. Executed off the platform thread.
  @async
  String runScript(String script, String paramsJson);

  /// Closes the database and releases the native handle.
  @async
  void closeDb();
}
