package com.quickal.app.ar

import android.content.Context
import android.hardware.display.DisplayManager
import android.view.Display
import android.view.WindowManager
import com.google.ar.core.Session

/**
 * Tracks display rotation/size changes and feeds them to the ARCore [Session]
 * so the camera background renders with the right orientation and aspect.
 */
class DisplayRotationHelper(context: Context) : DisplayManager.DisplayListener {

    private var viewportChanged = false
    private var viewportWidth = 0
    private var viewportHeight = 0

    private val displayManager =
        context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val display: Display = windowManager.defaultDisplay

    fun onResume() {
        displayManager.registerDisplayListener(this, null)
    }

    fun onPause() {
        displayManager.unregisterDisplayListener(this)
    }

    fun onSurfaceChanged(width: Int, height: Int) {
        viewportWidth = width
        viewportHeight = height
        viewportChanged = true
    }

    fun updateSessionIfNeeded(session: Session) {
        if (viewportChanged) {
            val rotation = display.rotation
            session.setDisplayGeometry(rotation, viewportWidth, viewportHeight)
            viewportChanged = false
        }
    }

    val rotation: Int
        get() = display.rotation

    override fun onDisplayAdded(displayId: Int) = Unit
    override fun onDisplayRemoved(displayId: Int) = Unit
    override fun onDisplayChanged(displayId: Int) {
        viewportChanged = true
    }
}
