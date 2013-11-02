/*
 * Copyright (c) 2007-2013 Scott Lembcke and Howling Moon Software
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
module demo.ChipmunkDemoShaderSupport;

import std.stdio;
import std.string;

import dchip;

import glad.gl.all;
import glad.gl.loader;

void CheckGLErrors();
auto CHECK_GL_ERRORS() { CheckGLErrors(); }

string SET_ATTRIBUTE(string program, string type, string name, string gltype)
{
    return q{
        SetAttribute(program, "%1$s", %2$s.%1$s.sizeof / GLfloat.sizeof, %3$s, %2$s.sizeof, cast(GLvoid *)%2$s.%1$s.offsetof);
    }.format(name, type, gltype);
}

void CheckGLErrors()
{
    for (GLenum err = glGetError(); err; err = glGetError())
    {
        if (err)
        {
            stderr.writefln("GLError(%s:%d) 0x%04X\n", __FILE__, __LINE__, err);
            assert(0);
        }
    }
}

alias PFNGLGETSHADERIVPROC = fp_glGetShaderiv;
alias PFNGLGETSHADERINFOLOGPROC = fp_glGetProgramInfoLog;

//typedef GLAPIENTRY void (*GETIV)(GLuint shader, GLenum pname, GLint *params);
//typedef GLAPIENTRY void (*GETINFOLOG)(GLuint shader, GLsizei maxLength, GLsizei *length, GLchar *infoLog);

static cpBool CheckError(GLint obj, GLenum status, PFNGLGETSHADERIVPROC getiv, PFNGLGETSHADERINFOLOGPROC getInfoLog)
{
    GLint success;
    getiv(obj, status, &success);

    if (!success)
    {
        GLint length;
        getiv(obj, GL_INFO_LOG_LENGTH, &length);

        char* log = cast(char*)alloca(length);
        getInfoLog(obj, length, null, log);

        stderr.writefln("Shader compile error for 0x%04X: %s\n", status, log);
        return cpFalse;
    }
    else
    {
        return cpTrue;
    }
}

GLint CompileShader(GLenum type, string source)
{
    GLint shader = glCreateShader(type);

    auto ssp = source.ptr;
    int ssl = cast(int)(source.length);
    glShaderSource(shader, 1, &ssp, &ssl);
    glCompileShader(shader);

    // TODO return placeholder shader instead?
    cpAssertHard(CheckError(shader, GL_COMPILE_STATUS, glGetShaderiv, glGetShaderInfoLog), "Error compiling shader");

    return shader;
}

GLint LinkProgram(GLint vshader, GLint fshader)
{
    GLint program = glCreateProgram();

    glAttachShader(program, vshader);
    glAttachShader(program, fshader);
    glLinkProgram(program);

    // todo return placeholder program instead?
    cpAssertHard(CheckError(program, GL_LINK_STATUS, glGetProgramiv, glGetProgramInfoLog), "Error linking shader program");

    return program;
}

cpBool ValidateProgram(GLint program)
{
    // TODO
    return cpTrue;
}

void SetAttribute(GLuint program, string name, GLint size, GLenum gltype, GLsizei stride, GLvoid* offset)
{
    GLint index = glGetAttribLocation(program, name.toStringz);
    glEnableVertexAttribArray(index);
    glVertexAttribPointer(index, size, gltype, GL_FALSE, stride, offset);
}
