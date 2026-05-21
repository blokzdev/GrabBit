package dev.blokz.grabbit

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.yausername.youtubedl_android.mapper.VideoFormat
import com.yausername.youtubedl_android.mapper.VideoInfo
import java.util.Collections
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Pigeon HostApi implementation backed by youtubedl-android. Engine calls run
/// on a background dispatcher; Pigeon callbacks are posted to the main thread
/// (ordered via a Handler so progress events keep their sequence).
class YtDlpHost(
    private val context: Context,
    private val flutterApi: YtDlpFlutterApi,
) : YtDlpHostApi {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val canceled = Collections.synchronizedSet(mutableSetOf<String>())

    override fun probe(url: String, callback: (Result<MediaInfoDto>) -> Unit) {
        scope.launch {
            val result = runCatching {
                YtDlpEngine.ensureInitialized(context)
                YoutubeDL.getInstance().getInfo(YoutubeDLRequest(url)).toDto()
            }
            withContext(Dispatchers.Main) { callback(result) }
        }
    }

    override fun expandRaw(url: String, callback: (Result<String>) -> Unit) {
        scope.launch {
            val result = runCatching {
                YtDlpEngine.ensureInitialized(context)
                val request = YoutubeDLRequest(url).apply {
                    addOption("--flat-playlist")
                    addOption("-J")
                }
                YoutubeDL.getInstance().execute(request).out
            }
            withContext(Dispatchers.Main) { callback(result) }
        }
    }

    override fun startDownload(request: DownloadRequestDto) {
        scope.launch {
            try {
                YtDlpEngine.ensureInitialized(context)
                val ytReq = YoutubeDLRequest(request.url).apply {
                    // Download into a per-task subfolder so the taskId names the
                    // folder (deterministic pickup) while the user's template
                    // names the file. Empty template falls back to the title.
                    val template = request.filenameTemplate.ifEmpty { "%(title)s.%(ext)s" }
                    addOption("-o", "${request.outputDir}/${request.taskId}/$template")
                    if (request.audioOnly) {
                        addOption("-x")
                        addOption("--audio-format", request.container ?: "m4a")
                    } else {
                        request.formatId?.takeIf { it.isNotEmpty() }?.let { addOption("-f", it) }
                        addOption("--merge-output-format", request.container ?: "mp4")
                    }
                    addOption("--write-thumbnail")
                    addOption("--convert-thumbnails", "jpg")
                    // Full metadata sidecar, parsed at completion + retained on
                    // disk for future re-derivation (P5).
                    addOption("--write-info-json")
                    if (request.embedThumbnail) addOption("--embed-thumbnail")
                    if (request.embedMetadata) addOption("--embed-metadata")
                    if (request.subtitles) {
                        addOption("--write-subs")
                        addOption("--write-auto-subs")
                        addOption("--embed-subs")
                    }
                }
                YoutubeDL.getInstance().execute(ytReq, request.taskId) { progress, etaInSeconds, line ->
                    val stage = if (line.contains("[Merger]") || line.contains("Merging")) {
                        "merging"
                    } else {
                        "downloading"
                    }
                    emit(
                        ProgressDto(
                            taskId = request.taskId,
                            percent = progress.toDouble(),
                            speedBps = 0.0,
                            etaSec = etaInSeconds.takeIf { it >= 0 },
                            stage = stage,
                            error = null,
                        ),
                    )
                }
                emit(ProgressDto(request.taskId, 100.0, 0.0, 0, "done", null))
            } catch (e: Exception) {
                val stage = if (canceled.remove(request.taskId)) "canceled" else "error"
                emit(ProgressDto(request.taskId, 0.0, 0.0, null, stage, e.message))
            }
        }
    }

    override fun cancel(taskId: String) {
        canceled.add(taskId)
        YoutubeDL.getInstance().destroyProcessById(taskId)
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

    private fun emit(dto: ProgressDto) {
        mainHandler.post { flutterApi.onProgress(dto) {} }
    }
}

private fun VideoInfo.toDto(): MediaInfoDto = MediaInfoDto(
    title = title ?: "",
    uploader = uploader,
    durationSec = duration.takeIf { it > 0 }?.toLong(),
    thumbnailUrl = thumbnail,
    site = extractor,
    description = description,
    uploadDate = uploadDate,
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
