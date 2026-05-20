package dev.blokz.grabbit

import android.content.Context
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.mapper.VideoFormat
import com.yausername.youtubedl_android.mapper.VideoInfo
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Pigeon HostApi implementation backed by youtubedl-android. Engine calls run
/// on a background dispatcher; Pigeon callbacks are posted to the main thread.
class YtDlpHost(private val context: Context) : YtDlpHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun probe(url: String, callback: (Result<MediaInfoDto>) -> Unit) {
        scope.launch {
            val result = runCatching {
                YtDlpEngine.ensureInitialized(context)
                YoutubeDL.getInstance().getInfo(YoutubeDLRequest(url)).toDto()
            }
            withContext(Dispatchers.Main) { callback(result) }
        }
    }

    override fun startDownload(request: DownloadRequestDto) {
        throw UnsupportedOperationException("Download is implemented in P1 chunk 3")
    }

    override fun cancel(taskId: String) {
        throw UnsupportedOperationException("Cancel is implemented in P1 chunk 3")
    }

    override fun engineVersions(callback: (Result<String>) -> Unit) {
        scope.launch {
            val result = runCatching {
                YtDlpEngine.ensureInitialized(context)
                YoutubeDL.getInstance().version(context) ?: "unknown"
            }
            withContext(Dispatchers.Main) { callback(result) }
        }
    }

    override fun updateEngine(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            val result = runCatching {
                YtDlpEngine.ensureInitialized(context)
                YoutubeDL.getInstance().updateYoutubeDL(context)
                Unit
            }
            withContext(Dispatchers.Main) { callback(result) }
        }
    }
}

private fun VideoInfo.toDto(): MediaInfoDto = MediaInfoDto(
    title = title ?: "",
    uploader = uploader,
    durationSec = duration.takeIf { it > 0 }?.toLong(),
    thumbnailUrl = thumbnail,
    site = extractor,
    formats = formats?.map { it.toDto() } ?: emptyList(),
)

private fun VideoFormat.toDto(): FormatDto {
    val hasVideo = vcodec != null && vcodec != "none"
    val hasAudio = acodec != null && acodec != "none"
    return FormatDto(
        id = formatId ?: "",
        ext = ext ?: "",
        height = height.takeIf { it > 0 }?.toLong(),
        tbr = tbr.takeIf { it > 0 }?.toLong(),
        vcodec = vcodec,
        acodec = acodec,
        audioOnly = hasAudio && !hasVideo,
        filesize = (fileSize.takeIf { it > 0 } ?: fileSizeApproximate.takeIf { it > 0 }),
        label = format ?: formatNote ?: (formatId ?: ""),
    )
}
