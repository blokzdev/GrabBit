package dev.blokz.grabbit

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.documentfile.provider.DocumentFile
import java.io.File
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/// Pigeon HostApi for exporting a private file to the device: either a
/// user-picked SAF tree, or the public MediaStore (gallery-visible, API 29+).
class StorageHost(private val activity: Activity) : StorageHostApi {
    companion object {
        const val requestPickFolder = 7001
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var pendingPick: ((Result<String?>) -> Unit)? = null

    override fun pickExportFolder(callback: (Result<String?>) -> Unit) {
        pendingPick = callback
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        activity.startActivityForResult(intent, requestPickFolder)
    }

    /// Returns true if it handled the result.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != requestPickFolder) return false
        val callback = pendingPick ?: return true
        pendingPick = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (uri != null) {
            activity.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        }
        callback(Result.success(uri?.toString()))
        return true
    }

    override fun exportToTree(
        filePath: String,
        treeUri: String,
        type: String,
        subdir: String?,
        callback: (Result<String>) -> Unit,
    ) {
        scope.launch {
            val result = runCatching {
                val tree = DocumentFile.fromTreeUri(activity, Uri.parse(treeUri))
                    ?: error("Export folder is no longer accessible")
                val target = if (subdir.isNullOrEmpty()) {
                    tree
                } else {
                    tree.findFile(subdir)?.takeIf { it.isDirectory }
                        ?: tree.createDirectory(subdir) ?: tree
                }
                val src = File(filePath)
                val doc = target.createFile(mimeFor(type, src.extension), src.name)
                    ?: error("Could not create the export file")
                activity.contentResolver.openOutputStream(doc.uri)!!.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                }
                doc.uri.toString()
            }
            withContext(Dispatchers.Main) { callback(result) }
        }
    }

    override fun exportToMediaStore(
        filePath: String,
        type: String,
        subdir: String?,
        callback: (Result<String>) -> Unit,
    ) {
        scope.launch {
            val result = runCatching {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    error("Pick an export folder on this Android version")
                }
                val src = File(filePath)
                val (collection, base) = when (type) {
                    "audio" -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI to
                        Environment.DIRECTORY_MUSIC
                    "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI to
                        Environment.DIRECTORY_PICTURES
                    else -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI to
                        Environment.DIRECTORY_MOVIES
                }
                val relative = if (subdir.isNullOrEmpty()) {
                    "$base/GrabBit"
                } else {
                    "$base/$subdir"
                }
                val resolver = activity.contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, src.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, mimeFor(type, src.extension))
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relative)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val uri = resolver.insert(collection, values)
                    ?: error("MediaStore insert failed")
                resolver.openOutputStream(uri)!!.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                }
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                uri.toString()
            }
            withContext(Dispatchers.Main) { callback(result) }
        }
    }

    private fun mimeFor(type: String, ext: String): String {
        val suffix = ext.ifEmpty { if (type == "image") "jpeg" else "mp4" }
        return when (type) {
            "audio" -> "audio/$suffix"
            "image" -> "image/$suffix"
            else -> "video/$suffix"
        }
    }
}
