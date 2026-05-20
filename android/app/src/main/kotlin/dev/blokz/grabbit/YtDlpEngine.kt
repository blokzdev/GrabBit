package dev.blokz.grabbit

import android.content.Context
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/// Lazily initializes the bundled yt-dlp + ffmpeg exactly once. The first init
/// extracts a Python runtime and is slow, so callers await it before use.
object YtDlpEngine {
    private val initMutex = Mutex()
    @Volatile
    private var initialized = false

    suspend fun ensureInitialized(context: Context) {
        if (initialized) return
        initMutex.withLock {
            if (initialized) return
            withContext(Dispatchers.IO) {
                YoutubeDL.getInstance().init(context)
                FFmpeg.getInstance().init(context)
            }
            initialized = true
        }
    }
}
