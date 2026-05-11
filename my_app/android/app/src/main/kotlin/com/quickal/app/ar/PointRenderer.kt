package com.quickal.app.ar

import android.opengl.GLES20
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Draws a small colored disc at a given world position. The disc is rendered
 * as a triangle fan that always faces the camera (simple billboard) so the
 * marker stays visible from any angle.
 */
class PointRenderer {

    private var program = 0
    private var positionAttrib = 0
    private var mvpUniform = 0
    private var colorUniform = 0
    private lateinit var vertices: FloatBuffer

    private val modelMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)

    fun createOnGlThread() {
        // Triangle fan: center + 16 perimeter points.
        val segments = 16
        val radius = 0.025f // 2.5 cm in world space
        val data = FloatArray((segments + 2) * 3)
        var idx = 0
        // Center.
        data[idx++] = 0f; data[idx++] = 0f; data[idx++] = 0f
        for (i in 0..segments) {
            val theta = (i.toDouble() / segments) * 2.0 * Math.PI
            data[idx++] = (radius * Math.cos(theta)).toFloat()
            data[idx++] = (radius * Math.sin(theta)).toFloat()
            data[idx++] = 0f
        }
        vertices = ByteBuffer
            .allocateDirect(data.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(data)
        vertices.position(0)

        val vertexShader = ShaderUtil.loadShader(
            GLES20.GL_VERTEX_SHADER,
            """
            uniform mat4 u_MVP;
            attribute vec3 a_Position;
            void main() {
                gl_Position = u_MVP * vec4(a_Position, 1.0);
            }
            """.trimIndent(),
        )
        val fragmentShader = ShaderUtil.loadShader(
            GLES20.GL_FRAGMENT_SHADER,
            """
            precision mediump float;
            uniform vec4 u_Color;
            void main() {
                gl_FragColor = u_Color;
            }
            """.trimIndent(),
        )
        program = ShaderUtil.linkProgram(vertexShader, fragmentShader)
        positionAttrib = GLES20.glGetAttribLocation(program, "a_Position")
        mvpUniform = GLES20.glGetUniformLocation(program, "u_MVP")
        colorUniform = GLES20.glGetUniformLocation(program, "u_Color")
    }

    fun draw(
        modelMatrix: FloatArray,
        viewMatrix: FloatArray,
        projectionMatrix: FloatArray,
        color: FloatArray,
    ) {
        val vp = FloatArray(16)
        Matrix.multiplyMM(vp, 0, projectionMatrix, 0, viewMatrix, 0)
        Matrix.multiplyMM(mvpMatrix, 0, vp, 0, modelMatrix, 0)

        GLES20.glUseProgram(program)
        GLES20.glUniformMatrix4fv(mvpUniform, 1, false, mvpMatrix, 0)
        GLES20.glUniform4fv(colorUniform, 1, color, 0)

        GLES20.glVertexAttribPointer(
            positionAttrib, 3, GLES20.GL_FLOAT, false, 0, vertices,
        )
        GLES20.glEnableVertexAttribArray(positionAttrib)

        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_FAN, 0, 18)

        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDisableVertexAttribArray(positionAttrib)

        ShaderUtil.checkGlError("PointRenderer.draw")
    }
}
