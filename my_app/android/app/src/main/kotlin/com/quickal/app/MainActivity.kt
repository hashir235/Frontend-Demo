package com.quickal.app

import android.app.DownloadManager
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.google.ar.core.ArCoreApk
import com.quickal.app.ar.ARMeasurementActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val shareExecutor = Executors.newSingleThreadExecutor()
    private var pendingArResult: MethodChannel.Result? = null

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

                "sharePdf" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val fileName = call.argument<String>("fileName")?.trim().orEmpty()

                    if (url.isEmpty() || fileName.isEmpty()) {
                        result.error(
                            "invalid_args",
                            "Share URL or file name is missing.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    shareExecutor.execute {
                        try {
                            val uri = downloadPdfForShare(url, fileName)
                            runOnUiThread {
                                try {
                                    openPdfShareSheet(uri, fileName)
                                    result.success(fileName)
                                } catch (error: Exception) {
                                    result.error(
                                        "share_failed",
                                        error.message ?: "Unable to open share sheet.",
                                        null,
                                    )
                                }
                            }
                        } catch (error: Exception) {
                            runOnUiThread {
                                result.error(
                                    "share_failed",
                                    error.message ?: "Unable to prepare PDF for sharing.",
                                    null,
                                )
                            }
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AR_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAvailability" -> {
                    try {
                        val availability =
                            ArCoreApk.getInstance().checkAvailability(this)
                        val mapped = when {
                            availability.isSupported && availability.isTransient ->
                                "checking"
                            availability.isSupported -> "supported"
                            availability == ArCoreApk.Availability.UNKNOWN_CHECKING ->
                                "checking"
                            availability == ArCoreApk.Availability.UNKNOWN_ERROR ->
                                "unknown_error"
                            availability == ArCoreApk.Availability.UNKNOWN_TIMED_OUT ->
                                "unknown_timeout"
                            availability == ArCoreApk.Availability.UNSUPPORTED_DEVICE_NOT_CAPABLE ->
                                "device_not_supported"
                            else -> "not_installed"
                        }
                        result.success(mapped)
                    } catch (error: Exception) {
                        result.error(
                            "ar_availability_failed",
                            error.message ?: "Unable to check AR availability.",
                            null,
                        )
                    }
                }
                "startMeasurement" -> {
                    if (pendingArResult != null) {
                        result.error(
                            "ar_busy",
                            "An AR measurement session is already in progress.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    pendingArResult = result
                    val intent = Intent(this, ARMeasurementActivity::class.java)
                    startActivityForResult(intent, AR_REQUEST_CODE)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURE_STORE_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            val key = call.argument<String>("key")?.trim().orEmpty()
            if (key.isEmpty()) {
                result.error("invalid_args", "Secure store key is missing.", null)
                return@setMethodCallHandler
            }

            try {
                when (call.method) {
                    "read" -> result.success(readSecureValue(key))
                    "write" -> {
                        val value = call.argument<String>("value").orEmpty()
                        writeSecureValue(key, value)
                        result.success(null)
                    }
                    "delete" -> {
                        securePrefs().edit().remove(key).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "secure_store_failed",
                    error.message ?: "Secure store operation failed.",
                    null,
                )
            }
        }
    }

    private fun downloadPdfForShare(url: String, fileName: String): Uri {
        val resolver = applicationContext.contentResolver
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Files.getContentUri("external")
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, PDF_MIME_TYPE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            } else {
                val downloadsDir =
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (!downloadsDir.exists()) {
                    downloadsDir.mkdirs()
                }
                put(MediaStore.MediaColumns.DATA, downloadsDir.resolve(fileName).absolutePath)
            }
        }
        val targetUri = resolver.insert(collection, values)
            ?: throw IOException("Unable to create PDF share file.")

        try {
            val connection = URL(url).openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = 15000
                connection.readTimeout = 90000
                connection.instanceFollowRedirects = true
                connection.setRequestProperty("Accept", PDF_MIME_TYPE)

                val status = connection.responseCode
                if (status !in 200..299) {
                    throw IOException("PDF download failed with status $status.")
                }

                val output = resolver.openOutputStream(targetUri)
                    ?: throw IOException("Unable to write PDF share file.")
                connection.inputStream.use { input ->
                    output.use { stream ->
                        input.copyTo(stream)
                    }
                }
            } finally {
                connection.disconnect()
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val readyValues = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(targetUri, readyValues, null, null)
            }
            return targetUri
        } catch (error: Exception) {
            resolver.delete(targetUri, null, null)
            throw error
        }
    }

    private fun openPdfShareSheet(uri: Uri, fileName: String) {
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = PDF_MIME_TYPE
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, fileName)
            clipData = ClipData.newUri(contentResolver, fileName, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(shareIntent, "Share PDF"))
    }

    private fun securePrefs(): SharedPreferences =
        getSharedPreferences(SECURE_PREFS_NAME, Context.MODE_PRIVATE)

    private fun readSecureValue(key: String): String? {
        val stored = securePrefs().getString(key, null) ?: return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || !stored.startsWith("v1:")) {
            return stored
        }

        val parts = stored.split(":")
        if (parts.size != 3) {
            return null
        }
        val iv = Base64.decode(parts[1], Base64.NO_WRAP)
        val encrypted = Base64.decode(parts[2], Base64.NO_WRAP)
        val cipher = Cipher.getInstance(SECURE_CIPHER_TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }

    private fun writeSecureValue(key: String, value: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            securePrefs().edit().putString(key, value).apply()
            return
        }

        val cipher = Cipher.getInstance(SECURE_CIPHER_TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val iv = Base64.encodeToString(cipher.iv, Base64.NO_WRAP)
        val payload = Base64.encodeToString(encrypted, Base64.NO_WRAP)
        securePrefs().edit().putString(key, "v1:$iv:$payload").apply()
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existingKey = keyStore.getKey(SECURE_STORE_KEY_ALIAS, null)
        if (existingKey is SecretKey) {
            return existingKey
        }

        val keyGenerator =
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val keySpec = KeyGenParameterSpec.Builder(
            SECURE_STORE_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGenerator.init(keySpec)
        return keyGenerator.generateKey()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == AR_REQUEST_CODE) {
            val pending = pendingArResult
            pendingArResult = null
            if (pending == null) {
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode == RESULT_OK && data != null) {
                val payload = HashMap<String, Any?>().apply {
                    put(
                        "width_meters",
                        data.getDoubleExtra(ARMeasurementActivity.RESULT_WIDTH_METERS, 0.0),
                    )
                    put(
                        "height_meters",
                        data.getDoubleExtra(ARMeasurementActivity.RESULT_HEIGHT_METERS, 0.0),
                    )
                    put(
                        "width_confidence",
                        data.getStringExtra(ARMeasurementActivity.RESULT_WIDTH_CONFIDENCE) ?: "low",
                    )
                    put(
                        "height_confidence",
                        data.getStringExtra(ARMeasurementActivity.RESULT_HEIGHT_CONFIDENCE) ?: "low",
                    )
                }
                pending.success(payload)
            } else {
                pending.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val CHANNEL_NAME = "quick_al/downloads"
        private const val SECURE_STORE_CHANNEL_NAME = "quick_al/secure_store"
        private const val AR_CHANNEL_NAME = "quick_al/ar_measurement"
        private const val AR_REQUEST_CODE = 7321
        private const val PDF_MIME_TYPE = "application/pdf"
        private const val SECURE_PREFS_NAME = "quick_al_secure_store"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val SECURE_STORE_KEY_ALIAS = "quick_al_auth_session_key"
        private const val SECURE_CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
