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
module demo.types;

import glad.gl.all;

import dchip;

/**
    This module contains all the types which the various drawing modules use.
    In the C source the types were duplicated across source files,
    probably to avoid too many #include's.
*/

struct Color
{
    float r, g, b, a;
}

Color RGBAColor(float r, float g, float b, float a)
{
    Color color = { r, g, b, a };
    return color;
}

Color LAColor(float l, float a)
{
    Color color = { l, l, l, a };
    return color;
}

struct v2f
{
    static v2f opCall(cpVect v)
    {
        v2f v2 = { cast(GLfloat)v.x, cast(GLfloat)v.y };
        return v2;
    }

    GLfloat x, y;
}

struct Vertex
{
    v2f vertex, aa_coord;
    Color fill_color, outline_color;
}

struct Triangle
{
    Vertex a, b, c;
}
