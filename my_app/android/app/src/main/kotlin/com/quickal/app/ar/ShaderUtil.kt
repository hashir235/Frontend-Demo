package com.quickal.app.ar

import android.opengl.GLES20

/** Tiny helpers for compiling GLSL shaders and checking GL errors. */
object ShaderUtil {

    fun loadShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)

        val compiled = IntArray(1)
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, compiled, 0)
        if (compiled[0] == 0) {
            val info = GLES20.glGetShaderInfoLog(shader)
            GLES20.glDeleteShader(shader)
            throw RuntimeException("Shader compile failed: $info")
        }
        return shader
    }

    fun linkProgram(vertexShader: Int, fragmentShader: Int): Int {
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vertexShader)
        GLES20.glAttachShader(program, fragmentShader)
        GLES20.glLinkProgram(program)
        val linked = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linked, 0)
        if (linked[0] == 0) {
            val info = GLES20.glGetProgramInfoLog(program)
            GLES20.glDeleteProgram(program)
            throw RuntimeException("Program link failed: $info")
        }
        return program
    }

    fun checkGlError(tag: String) {
        var error = GLES20.glGetError()
        while (error != GLES20.GL_NO_ERROR) {
            android.util.Log.e("ARMeasurement", "$tag: GL error 0x${error.toString(16)}")
            error = GLES20.glGetError()
        }
    }
}
