package com.quickal.app.ar

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import android.os.Bundle
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.widget.Button
import android.widget.ImageButton
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableApkTooOldException
import com.google.ar.core.exceptions.UnavailableArcoreNotInstalledException
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableSdkTooOldException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import com.quickal.app.R
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Full-screen ARCore Activity that lets the user measure WIDTH then HEIGHT
 * of a window by tapping two points each. Returns the result as an Intent
 * extra:
 *   - RESULT_WIDTH_METERS (Double)
 *   - RESULT_HEIGHT_METERS (Double)
 *   - RESULT_WIDTH_CONFIDENCE / RESULT_HEIGHT_CONFIDENCE ("high"|"medium"|"low")
 *
 * Communicates with Flutter via [com.quickal.app.MainActivity]'s MethodChannel.
 */
class ARMeasurementActivity : AppCompatActivity(), GLSurfaceView.Renderer {

    companion object {
        const val RESULT_WIDTH_METERS = "width_meters"
        const val RESULT_HEIGHT_METERS = "height_meters"
        const val RESULT_WIDTH_CONFIDENCE = "width_confidence"
        const val RESULT_HEIGHT_CONFIDENCE = "height_confidence"
        private const val CAMERA_PERMISSION_CODE = 9111
    }

    private enum class Step { WIDTH, HEIGHT, REVIEW }

    // GL + ARCore.
    private lateinit var surfaceView: GLSurfaceView
    private var session: Session? = null
    private var installRequested = false
    private val displayRotationHelper by lazy { DisplayRotationHelper(this) }
    private val backgroundRenderer = BackgroundRenderer()
    private val pointRenderer = PointRenderer()
    private val lineRenderer = LineRenderer()

    // UI.
    private lateinit var instructionText: TextView
    private lateinit var distanceText: TextView
    private lateinit var stepIndicator: TextView
    private lateinit var trackingStateView: TextView
    private lateinit var savedMeasurementsText: TextView
    private lateinit var captureButton: Button
    private lateinit var resetButton: Button
    private lateinit var confirmButton: Button
    private lateinit var cancelButton: ImageButton

    // State.
    @Volatile private var step: Step = Step.WIDTH
    private val currentAnchors = mutableListOf<Anchor>()
    private var widthMeters: Float? = null
    private var heightMeters: Float? = null
    private var widthConfidence: String = "low"
    private var heightConfidence: String = "low"

    // Last detected tracking quality (for confidence label).
    @Volatile private var trackingGood: Boolean = false

    // Pending screen tap handed off to the GL thread.
    private val tapLock = Any()
    private var pendingTap: MotionEvent? = null

    // Cached matrices.
    private val viewMatrix = FloatArray(16)
    private val projectionMatrix = FloatArray(16)
    private val anchorMatrix = FloatArray(16)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_ar_measurement)

        surfaceView = findViewById(R.id.ar_surface_view)
        instructionText = findViewById(R.id.ar_instruction_text)
        distanceText = findViewById(R.id.ar_distance_text)
        stepIndicator = findViewById(R.id.ar_step_indicator)
        trackingStateView = findViewById(R.id.ar_tracking_state)
        savedMeasurementsText = findViewById(R.id.ar_saved_measurements)
        captureButton = findViewById(R.id.ar_capture_button)
        resetButton = findViewById(R.id.ar_reset_button)
        confirmButton = findViewById(R.id.ar_confirm_button)
        cancelButton = findViewById(R.id.ar_cancel_button)

        surfaceView.preserveEGLContextOnPause = true
        surfaceView.setEGLContextClientVersion(2)
        surfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        surfaceView.setRenderer(this)
        surfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        surfaceView.setWillNotDraw(false)

        val gestureDetector = GestureDetector(
            this,
            object : GestureDetector.SimpleOnGestureListener() {
                override fun onSingleTapUp(e: MotionEvent): Boolean {
                    synchronized(tapLock) {
                        pendingTap = MotionEvent.obtain(e)
                    }
                    return true
                }

                override fun onDown(e: MotionEvent): Boolean = true
            },
        )
        surfaceView.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
        }

        captureButton.setOnClickListener { onCaptureClicked() }
        resetButton.setOnClickListener { onResetClicked() }
        confirmButton.setOnClickListener { onConfirmClicked() }
        cancelButton.setOnClickListener { cancelAndFinish() }

        refreshUi()
    }

    override fun onResume() {
        super.onResume()
        if (session == null) {
            if (!tryEnsureSession()) {
                return
            }
        }

        try {
            session?.resume()
            surfaceView.onResume()
            displayRotationHelper.onResume()
        } catch (e: CameraNotAvailableException) {
            showFatal("Camera not available. Please try again.")
            session = null
        }
    }

    override fun onPause() {
        super.onPause()
        if (session != null) {
            displayRotationHelper.onPause()
            surfaceView.onPause()
            session?.pause()
        }
    }

    override fun onDestroy() {
        session?.close()
        session = null
        super.onDestroy()
    }

    /**
     * Ensures ARCore is installed, camera permission is granted, and a Session
     * is created. Returns true if the Activity should continue with onResume,
     * false if we're waiting on an install/permission prompt.
     */
    private fun tryEnsureSession(): Boolean {
        try {
            when (ArCoreApk.getInstance().requestInstall(this, !installRequested)) {
                ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                    installRequested = true
                    return false
                }
                ArCoreApk.InstallStatus.INSTALLED -> Unit
                null -> Unit
            }

            if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.CAMERA),
                    CAMERA_PERMISSION_CODE,
                )
                return false
            }

            val s = Session(this)
            val config = Config(s).apply {
                focusMode = Config.FocusMode.AUTO
                updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                depthMode = if (s.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                    Config.DepthMode.AUTOMATIC
                } else {
                    Config.DepthMode.DISABLED
                }
            }
            s.configure(config)
            session = s
            return true
        } catch (e: UnavailableUserDeclinedInstallationException) {
            showFatal("ARCore install was declined.")
        } catch (e: UnavailableArcoreNotInstalledException) {
            showFatal("ARCore is not installed on this device.")
        } catch (e: UnavailableApkTooOldException) {
            showFatal("Please update ARCore (Google Play Services for AR).")
        } catch (e: UnavailableSdkTooOldException) {
            showFatal("This app needs to be updated to support AR.")
        } catch (e: UnavailableDeviceNotCompatibleException) {
            showFatal("This device does not support AR.")
        } catch (e: Exception) {
            showFatal("Could not start AR: ${e.message}")
        }
        return false
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION_CODE) return
        if (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED) {
            showFatal("Camera permission is required to use AR measurement.")
        }
    }

    // ---- GL rendering ----

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        android.opengl.GLES20.glClearColor(0.05f, 0.07f, 0.10f, 1f)
        try {
            backgroundRenderer.createOnGlThread()
            pointRenderer.createOnGlThread()
            lineRenderer.createOnGlThread()
            session?.setCameraTextureName(backgroundRenderer.textureId)
        } catch (e: Exception) {
            runOnUiThread { showFatal("AR renderer init failed: ${e.message}") }
        }
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        displayRotationHelper.onSurfaceChanged(width, height)
        android.opengl.GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        android.opengl.GLES20.glClear(
            android.opengl.GLES20.GL_COLOR_BUFFER_BIT or
                android.opengl.GLES20.GL_DEPTH_BUFFER_BIT,
        )
        val s = session ?: return
        try {
            displayRotationHelper.updateSessionIfNeeded(s)
            s.setCameraTextureName(backgroundRenderer.textureId)
            val frame: Frame = s.update()
            val camera = frame.camera

            backgroundRenderer.draw(frame)

            val tracking = camera.trackingState == TrackingState.TRACKING
            trackingGood = tracking

            if (!tracking) {
                runOnUiThread { updateTrackingIndicator(false) }
                return
            }
            runOnUiThread { updateTrackingIndicator(true) }

            camera.getProjectionMatrix(projectionMatrix, 0, 0.1f, 100.0f)
            camera.getViewMatrix(viewMatrix, 0)

            // Process pending tap on the GL thread (where ARCore Frame is valid).
            val tap = synchronized(tapLock) {
                val captured = pendingTap
                pendingTap = null
                captured
            }
            if (tap != null && step != Step.REVIEW) {
                handleTap(frame, tap)
                tap.recycle()
            }

            // Draw anchors.
            val markerColor = floatArrayOf(0.18f, 0.85f, 0.42f, 1f) // green
            for (anchor in currentAnchors) {
                if (anchor.trackingState != TrackingState.TRACKING) continue
                anchor.pose.toMatrix(anchorMatrix, 0)
                pointRenderer.draw(anchorMatrix, viewMatrix, projectionMatrix, markerColor)
            }

            // Draw line if we have 2 anchors.
            if (currentAnchors.size == 2 &&
                currentAnchors.all { it.trackingState == TrackingState.TRACKING }
            ) {
                val a = currentAnchors[0].pose.translation
                val b = currentAnchors[1].pose.translation
                lineRenderer.draw(
                    a, b, viewMatrix, projectionMatrix,
                    floatArrayOf(0.18f, 0.85f, 0.42f, 1f), 10f,
                )

                val meters = distanceMeters(a, b)
                runOnUiThread { distanceText.text = formatDistance(meters) }
            } else if (currentAnchors.size < 2) {
                runOnUiThread { distanceText.text = "" }
            }
        } catch (t: Throwable) {
            android.util.Log.e("ARMeasurement", "onDrawFrame error", t)
        }
    }

    private fun handleTap(frame: Frame, tap: MotionEvent) {
        if (currentAnchors.size >= 2) return
        val hits: List<HitResult> = frame.hitTest(tap)
        // Prefer plane hits in polygon, fall back to feature point.
        var chosen: HitResult? = null
        for (hit in hits) {
            val trackable = hit.trackable
            if (trackable is Plane &&
                trackable.isPoseInPolygon(hit.hitPose) &&
                trackable.trackingState == TrackingState.TRACKING
            ) {
                chosen = hit
                break
            } else if (trackable is Point &&
                trackable.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL
            ) {
                if (chosen == null) chosen = hit
            }
        }
        if (chosen == null && hits.isNotEmpty()) {
            chosen = hits[0]
        }
        if (chosen != null) {
            val anchor = chosen.createAnchor()
            currentAnchors.add(anchor)
            runOnUiThread { refreshUi() }
        }
    }

    private fun distanceMeters(a: FloatArray, b: FloatArray): Float {
        val dx = a[0] - b[0]
        val dy = a[1] - b[1]
        val dz = a[2] - b[2]
        return Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()
    }

    private fun formatDistance(meters: Float): String {
        // Inches and sutar (1 inch = 8 sutar).
        val totalInches = meters * 39.37008f
        val whole = totalInches.toInt()
        val sutar = Math.round((totalInches - whole) * 8f)
        val (inches, sut) = if (sutar == 8) whole + 1 to 0 else whole to sutar
        return "$inches in  $sut sutar  •  ${"%.1f".format(totalInches)}\""
    }

    // ---- UI handlers ----

    private fun onCaptureClicked() {
        if (currentAnchors.size != 2) return
        val a = currentAnchors[0].pose.translation
        val b = currentAnchors[1].pose.translation
        val meters = distanceMeters(a, b)
        val confidence = when {
            !trackingGood -> "low"
            meters < 0.10f -> "low"
            else -> "high"
        }
        when (step) {
            Step.WIDTH -> {
                widthMeters = meters
                widthConfidence = confidence
                step = Step.HEIGHT
                clearAnchors()
            }
            Step.HEIGHT -> {
                heightMeters = meters
                heightConfidence = confidence
                step = Step.REVIEW
                clearAnchors()
            }
            Step.REVIEW -> Unit
        }
        refreshUi()
    }

    private fun onResetClicked() {
        clearAnchors()
        when (step) {
            Step.HEIGHT -> {
                // Allow user to redo width too.
                widthMeters = null
                step = Step.WIDTH
            }
            Step.REVIEW -> {
                heightMeters = null
                step = Step.HEIGHT
            }
            Step.WIDTH -> Unit
        }
        refreshUi()
    }

    private fun onConfirmClicked() {
        val w = widthMeters
        val h = heightMeters
        if (w == null || h == null) return
        val data = Intent().apply {
            putExtra(RESULT_WIDTH_METERS, w.toDouble())
            putExtra(RESULT_HEIGHT_METERS, h.toDouble())
            putExtra(RESULT_WIDTH_CONFIDENCE, widthConfidence)
            putExtra(RESULT_HEIGHT_CONFIDENCE, heightConfidence)
        }
        setResult(RESULT_OK, data)
        finish()
    }

    private fun cancelAndFinish() {
        setResult(RESULT_CANCELED)
        finish()
    }

    private fun clearAnchors() {
        for (a in currentAnchors) a.detach()
        currentAnchors.clear()
    }

    private fun refreshUi() {
        runOnUiThread {
            when (step) {
                Step.WIDTH -> {
                    stepIndicator.text = "Step 1 of 2 — WIDTH"
                    captureButton.text = "Save Width"
                    instructionText.text = when (currentAnchors.size) {
                        0 -> "Tap on LEFT edge of the window."
                        1 -> "Now tap on the RIGHT edge."
                        else -> "Tap 'Save Width' to lock this measurement."
                    }
                }
                Step.HEIGHT -> {
                    stepIndicator.text = "Step 2 of 2 — HEIGHT"
                    captureButton.text = "Save Height"
                    instructionText.text = when (currentAnchors.size) {
                        0 -> "Tap on TOP edge of the window."
                        1 -> "Now tap on the BOTTOM edge."
                        else -> "Tap 'Save Height' to lock this measurement."
                    }
                }
                Step.REVIEW -> {
                    stepIndicator.text = "Review measurements"
                    captureButton.text = "—"
                    instructionText.text = "Tap 'Done' to use these values, or 'Reset' to redo height."
                }
            }
            captureButton.isEnabled = step != Step.REVIEW && currentAnchors.size == 2

            val parts = mutableListOf<String>()
            widthMeters?.let { parts += "W: ${formatDistance(it)}" }
            heightMeters?.let { parts += "H: ${formatDistance(it)}" }
            savedMeasurementsText.text = parts.joinToString("\n")
            confirmButton.isEnabled = widthMeters != null && heightMeters != null
            confirmButton.visibility = View.VISIBLE
        }
    }

    private fun updateTrackingIndicator(tracking: Boolean) {
        if (tracking) {
            trackingStateView.setTextColor(0xFF66BB6A.toInt())
        } else {
            trackingStateView.setTextColor(0xFFEF5350.toInt())
        }
    }

    private fun showFatal(message: String) {
        AlertDialog.Builder(this)
            .setTitle("AR Measurement")
            .setMessage(message)
            .setCancelable(false)
            .setPositiveButton("Close") { _, _ ->
                setResult(RESULT_CANCELED)
                finish()
            }
            .show()
    }
}
