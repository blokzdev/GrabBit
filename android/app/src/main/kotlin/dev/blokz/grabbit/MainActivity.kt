package dev.blokz.grabbit

import android.os.Bundle
import android.util.Log
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLException
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize the bundled yt-dlp + ffmpeg off the main thread; the first
        // run extracts a Python runtime, which is slow. Probe/download wait on
        // this in later P1 chunks.
        Thread {
            try {
                YoutubeDL.getInstance().init(applicationContext)
                FFmpeg.getInstance().init(applicationContext)
                Log.i(TAG, "youtubedl-android initialized")
            } catch (e: YoutubeDLException) {
                Log.e(TAG, "failed to initialize youtubedl-android", e)
            }
        }.start()
    }

    private companion object {
        const val TAG = "GrabBitEngine"
    }
}
