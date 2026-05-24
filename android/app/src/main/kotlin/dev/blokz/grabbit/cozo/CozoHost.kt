package dev.blokz.grabbit.cozo

import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.cozodb.CozoJavaBridge

/// Pigeon HostApi backed by the cozo_android AAR (CozoDB). Uses the low-level,
/// all-String `CozoJavaBridge` (script + params JSON in, result JSON out) rather
/// than the high-level `CozoDb`, which depends on mjson and returns typed rows —
/// the bridge maps 1:1 onto this string-based Pigeon contract and needs no extra
/// deps. Queries run on a background dispatcher; results post back on the main
/// thread. A single SQLite-backed handle is held for the app's lifetime.
///
/// If the native .so isn't bundled for this device's ABI, constructing the
/// bridge throws UnsatisfiedLinkError/NoClassDefFoundError; openDb reports false
/// so graph features degrade gracefully (the download core is unaffected).
class CozoHost : CozoHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var db: CozoJavaBridge? = null

    override fun openDb(path: String, callback: (Result<Boolean>) -> Unit) {
        scope.launch {
            val result = runCatching {
                if (db == null) {
                    // "sqlite": a single persistent file (smaller than rocksdb,
                    // survives process death), loaded via the existing
                    // useLegacyPackaging/extractNativeLibs setup.
                    db = CozoJavaBridge("sqlite", path, "{}")
                }
                true
            }.recoverCatching { e ->
                if (e is UnsatisfiedLinkError || e is NoClassDefFoundError) {
                    false
                } else {
                    throw e
                }
            }
            post { callback(result) }
        }
    }

    override fun runScript(
        script: String,
        paramsJson: String,
        callback: (Result<String>) -> Unit,
    ) {
        scope.launch {
            val result = runCatching {
                val handle = db ?: error("Cozo database is not open")
                handle.query(script, paramsJson)
            }
            post { callback(result) }
        }
    }

    override fun closeDb(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            val result = runCatching {
                db?.close()
                db = null
            }
            post { callback(result) }
        }
    }

    private fun post(block: () -> Unit) = mainHandler.post(block)
}
