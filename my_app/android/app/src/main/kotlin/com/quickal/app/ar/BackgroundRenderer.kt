package com.quickal.app.ar

import android.opengl.GLES11Ext
import android.opengl.GLES20
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Draws the ARCore camera preview into a full-screen GL quad using an
 * external OES texture. ARCore supplies UV coordinates per frame via
 * [Frame.transformCoordinates2d] so the image stays correctly oriented
 * regardless of device rotation.
 */
class BackgroundRenderer {

    var textureId: Int = -1
        private set

    private var program = 0
    private var positionAttrib = 0
    private var texCoordAttrib = 0

    private lateinit var quadVertices: FloatBuffer
    private lateinit var quadTexCoords: FloatBuffer
    private lateinit var quadTexCoordsTransformed: FloatBuffer

    fun createOnGlThread() {
        // Generate the external OES texture that ARCore writes camera frames to.
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR,
        )

        // Fullscreen quad in normalized device coords.
        val quad = floatArrayOf(
            -1f, -1f,
            +1f, -1f,
            -1f, +1f,
            +1f, +1f,
        )
        quadVertices = ByteBuffer
            .allocateDirect(quad.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(quad)
        quadVertices.position(0)

        quadTexCoords = ByteBuffer
            .allocateDirect(quad.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f))
        quadTexCoords.position(0)

        quadTexCoordsTransformed = ByteBuffer
            .allocateDirect(quad.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        quadTexCoordsTransformed.position(0)

        val vertexShader = ShaderUtil.loadShader(
            GLES20.GL_VERTEX_SHADER,
            """
            attribute vec2 a_Position;
            attribute vec2 a_TexCoord;
            varying vec2 v_TexCoord;
            void main() {
                gl_Position = vec4(a_Position, 0.0, 1.0);
                v_TexCoord = a_TexCoord;
            }
            """.trimIndent(),
        )
        val fragmentShader = ShaderUtil.loadShader(
            GLES20.GL_FRAGMENT_SHADER,
            """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 v_TexCoord;
            uniform samplerExternalOES u_Texture;
            void main() {
                gl_FragColor = texture2D(u_Texture, v_TexCoord);
            }
            """.trimIndent(),
        )
        program = ShaderUtil.linkProgram(vertexShader, fragmentShader)
        positionAttrib = GLES20.glGetAttribLocation(program, "a_Position")
        texCoordAttrib = GLES20.glGetAttribLocation(program, "a_TexCoord")
    }

    fun draw(frame: Frame) {
        if (frame.hasDisplayGeometryChanged()) {
            frame.transformCoordinates2d(
                Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                quadVertices,
                Coordinates2d.TEXTURE_NORMALIZED,
                quadTexCoordsTransformed,
            )
        } else if (quadTexCoordsTransformed.position() == 0) {
            // First-frame initialization.
            frame.transformCoordinates2d(
                Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                quadVertices,
                Coordinates2d.TEXTURE_NORMALIZED,
                quadTexCoordsTransformed,
            )
        }

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)

        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, textureId)
        GLES20.glUseProgram(program)

        GLES20.glVertexAttribPointer(
            positionAttrib, 2, GLES20.GL_FLOAT, false, 0, quadVertices,
        )
        GLES20.glVertexAttribPointer(
            texCoordAttrib, 2, GLES20.GL_FLOAT, false, 0, quadTexCoordsTransformed,
        )
        GLES20.glEnableVertexAttribArray(positionAttrib)
        GLES20.glEnableVertexAttribArray(texCoordAttrib)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(positionAttrib)
        GLES20.glDisableVertexAttribArray(texCoordAttrib)

        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)

        ShaderUtil.checkGlError("BackgroundRenderer.draw")
    }
}
