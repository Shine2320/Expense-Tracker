package com.example.expense_tracker

import android.content.ContentValues
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val downloadsChannel = "expense_tracker/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> saveToDownloads(call.arguments, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val fileName = args?.get("fileName") as? String
        val mimeType = args?.get("mimeType") as? String
        val bytes = args?.get("bytes") as? ByteArray

        if (fileName.isNullOrBlank() || mimeType.isNullOrBlank() || bytes == null) {
            result.error("invalid_args", "Missing fileName, mimeType, or bytes.", null)
            return
        }

        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("insert_failed", "Could not create the export file in Downloads.", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { stream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("Could not open the Downloads output stream.")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            result.success("Downloads/$fileName")
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            result.error("write_failed", error.message, null)
        }
    }
}
