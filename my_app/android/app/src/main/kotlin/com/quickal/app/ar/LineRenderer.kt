package com.quickal.app.ar

import android.opengl.GLES20
import android.opengl.Matrix
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer

/**
 * Draws a thick colored line segment in world space between two 3D points.
 */
class LineRenderer {

    private var program = 0
    private var positionAttrib = 0
    private var mvpUniform = 0
    private var colorUniform = 0
    private val vertices: FloatBuffer = ByteBuffer
        .allocateDirect(6 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()

    private val vpMatrix = FloatArray(16)

    fun createOnGlThread() {
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
        start: FloatArray,
        end: FloatArray,
        viewMatrix: FloatArray,
        projectionMatrix: FloatArray,
        color: FloatArray,
        lineWidth: Float = 8f,
    ) {
        vertices.position(0)
        vertices.put(start[0]).put(start[1]).put(start[2])
        vertices.put(end[0]).put(end[1]).put(end[2])
        vertices.position(0)

        Matrix.multiplyMM(vpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)

        GLES20.glUseProgram(program)
        GLES20.glUniformMatrix4fv(mvpUniform, 1, false, vpMatrix, 0)
        GLES20.glUniform4fv(colorUniform, 1, color, 0)
        GLES20.glLineWidth(lineWidth)

        GLES20.glVertexAttribPointer(
            positionAttrib, 3, GLES20.GL_FLOAT, false, 0, vertices,
        )
        GLES20.glEnableVertexAttribArray(positionAttrib)

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDrawArrays(GLES20.GL_LINES, 0, 2)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)

        GLES20.glDisableVertexAttribArray(positionAttrib)
        ShaderUtil.checkGlError("LineRenderer.draw")
    }
}
