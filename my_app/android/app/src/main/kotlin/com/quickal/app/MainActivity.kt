package com.quickal.app

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadPdf" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val fileName = call.argument<String>("fileName")?.trim().orEmpty()
                    val description = call.argument<String>("description")?.trim().orEmpty()

                    if (url.isEmpty() || fileName.isEmpty()) {
                        result.error(
                            "invalid_args",
                            "Download URL or file name is missing.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                        val request = DownloadManager.Request(Uri.parse(url))
                            .setMimeType("application/pdf")
                            .setTitle(fileName)
                            .setDescription(
                                if (description.isEmpty()) "Downloading PDF" else description,
                            )
                            .setNotificationVisibility(
                                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                            )
                            .setAllowedOverMetered(true)
                            .setAllowedOverRoaming(true)
                            .setDestinationInExternalPublicDir(
                                Environment.DIRECTORY_DOWNLOADS,
                                fileName,
                            )

                        manager.enqueue(request)
                        result.success(fileName)
                    } catch (error: Exception) {
                        result.error(
                            "download_failed",
                            error.message ?: "Unable to download PDF.",
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val CHANNEL_NAME = "quick_al/downloads"
    }
}
