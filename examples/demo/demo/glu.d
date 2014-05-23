/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module demo.glu;

import core.memory;

import core.stdc.stdio;
import core.stdc.stdlib;

import std.exception;
import std.math;
import std.random;
import std.stdio;
import std.string;

alias stderr = std.stdio.stderr;

import glad.gl.all;
import glad.gl.loader;

/*
** Make m an identity matrix
*/
void __gluMakeIdentityd(ref GLdouble[16] m)
{
    m[0 + 4 * 0] = 1;
    m[0 + 4 * 1] = 0;
    m[0 + 4 * 2] = 0;
    m[0 + 4 * 3] = 0;
    m[1 + 4 * 0] = 0;
    m[1 + 4 * 1] = 1;
    m[1 + 4 * 2] = 0;
    m[1 + 4 * 3] = 0;
    m[2 + 4 * 0] = 0;
    m[2 + 4 * 1] = 0;
    m[2 + 4 * 2] = 1;
    m[2 + 4 * 3] = 0;
    m[3 + 4 * 0] = 0;
    m[3 + 4 * 1] = 0;
    m[3 + 4 * 2] = 0;
    m[3 + 4 * 3] = 1;
}

/*
** inverse = invert(src)
*/
int __gluInvertMatrixd(ref GLdouble[16] src, ref GLdouble[16] inverse)
{
    int i, j, k, swap;
    double t = 0;
    GLdouble[4][4] temp = 0;

    for (i = 0; i < 4; i++)
    {
        for (j = 0; j < 4; j++)
        {
            temp[i][j] = src[i * 4 + j];
        }
    }

    __gluMakeIdentityd(inverse);

    for (i = 0; i < 4; i++)
    {
        /*
        ** Look for largest element in column
        */
        swap = i;

        for (j = i + 1; j < 4; j++)
        {
            if (fabs(temp[j][i]) > fabs(temp[i][i]))
            {
                swap = j;
            }
        }

        if (swap != i)
        {
            /*
            ** Swap rows.
            */
            for (k = 0; k < 4; k++)
            {
                t = temp[i][k];
                temp[i][k]    = temp[swap][k];
                temp[swap][k] = t;

                t = inverse[i * 4 + k];
                inverse[i * 4 + k]    = inverse[swap * 4 + k];
                inverse[swap * 4 + k] = t;
            }
        }

        if (temp[i][i] == 0)
        {
            /*
            ** No non-zero pivot.  The matrix is singular, which shouldn't
            ** happen.  This means the user gave us a bad matrix.
            */
            return GL_FALSE;
        }

        t = temp[i][i];

        for (k = 0; k < 4; k++)
        {
            temp[i][k]         /= t;
            inverse[i * 4 + k] /= t;
        }

        for (j = 0; j < 4; j++)
        {
            if (j != i)
            {
                t = temp[j][i];

                for (k = 0; k < 4; k++)
                {
                    temp[j][k]         -= temp[i][k] * t;
                    inverse[j * 4 + k] -= inverse[i * 4 + k] * t;
                }
            }
        }
    }

    return GL_TRUE;
}

void __gluMultMatricesd(ref GLdouble[16] a, ref GLdouble[16] b, ref GLdouble[16] r)
{
    int i, j;

    for (i = 0; i < 4; i++)
    {
        for (j = 0; j < 4; j++)
        {
            r[i * 4 + j] =
                a[i * 4 + 0] * b[0 * 4 + j] +
                a[i * 4 + 1] * b[1 * 4 + j] +
                a[i * 4 + 2] * b[2 * 4 + j] +
                a[i * 4 + 3] * b[3 * 4 + j];
        }
    }
}

void __gluMultMatrixVecd(ref GLdouble[16] matrix, ref GLdouble[4] in_, ref GLdouble[4] out_)
{
    int i;

    for (i = 0; i < 4; i++)
    {
        out_[i] =
            in_[0] * matrix[0 * 4 + i] +
            in_[1] * matrix[1 * 4 + i] +
            in_[2] * matrix[2 * 4 + i] +
            in_[3] * matrix[3 * 4 + i];
    }
}

GLint gluUnProject(ref GLdouble winx, GLdouble winy, GLdouble winz,
                   ref GLdouble[16] modelMatrix,
                   ref GLdouble[16] projMatrix,
                   ref GLint[4] viewport,
                   GLdouble* objx, GLdouble* objy, GLdouble* objz)
{
    double[16] finalMatrix = 0;
    double[4] in_ = 0;
    double[4] out_ = 0;

    __gluMultMatricesd(modelMatrix, projMatrix, finalMatrix);

    if (!__gluInvertMatrixd(finalMatrix, finalMatrix))
        return GL_FALSE;

    in_[0] = winx;
    in_[1] = winy;
    in_[2] = winz;
    in_[3] = 1.0;

    /* Map x and y from window coordinates */
    in_[0] = (in_[0] - viewport[0]) / viewport[2];
    in_[1] = (in_[1] - viewport[1]) / viewport[3];

    /* Map to range -1 to 1 */
    in_[0] = in_[0] * 2 - 1;
    in_[1] = in_[1] * 2 - 1;
    in_[2] = in_[2] * 2 - 1;

    __gluMultMatrixVecd(finalMatrix, in_, out_);

    if (out_[3] == 0.0)
        return GL_FALSE;

    out_[0] /= out_[3];
    out_[1] /= out_[3];
    out_[2] /= out_[3];
    *objx    = out_[0];
    *objy    = out_[1];
    *objz    = out_[2];

    return GL_TRUE;
}

void gluOrtho2D(GLdouble left, GLdouble right, GLdouble bottom, GLdouble top)
{
    glOrtho(left, right, bottom, top, -1, 1);
}
