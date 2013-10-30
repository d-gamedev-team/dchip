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
module dchip.types;

import std.math : sqrt, sin, cos, acos, atan2, fmod, exp, pow, floor, ceil, PI, E;

version (StdDdoc)
{
    /**
        The floating-point type used internally.
        By default it is aliased to $(D float).

        Use the $(D CHIP_USE_DOUBLES) version switch
        to set it to $(D double) instead. Using doubles
        will increase precision at the cost of performance.
    */
    alias cpFloat = float;
}
else
version (CHIP_USE_DOUBLES)
{
    /// The floating-point type used internally.
    /// Use the $(D CHIP_USE_DOUBLES) version switch to enable this.
    alias cpFloat = double;
}
else
{
    ///
    alias cpFloat = float;
}

version (CHIP_USE_DOUBLES)
{
    alias cpfsqrt = sqrt;
    alias cpfsin = sin;
    alias cpfcos = cos;
    alias cpfacos = acos;
    alias cpfatan2 = atan2;
    alias cpfmod = fmod;
    alias cpfexp = exp;
    alias cpfpow = pow;
    alias cpffloor = floor;
    alias cpfceil = ceil;
}
else
{
    alias cpfsqrt = sqrtf;
    alias cpfsin = sinf;
    alias cpfcos = cosf;
    alias cpfacos = acosf;
    alias cpfatan2 = atan2f;
    alias cpfmod = fmodf;
    alias cpfexp = expf;
    alias cpfpow = powf;
    alias cpffloor = floorf;
    alias cpfceil = ceilf;
}

///
enum CPFLOAT_MIN = cpFloat.min_normal;

///
enum INFINITY = cpFloat.infinity;

///
alias M_PI = PI;

///
alias M_E = E;

/// Return the max of two cpFloats.
cpFloat cpfmax(cpFloat a, cpFloat b)
{
    return (a > b) ? a : b;
}

/// Return the min of two cpFloats.
cpFloat cpfmin(cpFloat a, cpFloat b)
{
    return (a < b) ? a : b;
}

/// Return the absolute value of a cpFloat.
cpFloat cpfabs(cpFloat f)
{
    return (f < 0) ? -f : f;
}

/// Clamp $(D f) to be between $(D min) and $(D max).
cpFloat cpfclamp(cpFloat f, cpFloat min, cpFloat max)
{
    return cpfmin(cpfmax(f, min), max);
}

/// Clamp $(D f) to be between 0 and 1.
cpFloat cpfclamp01(cpFloat f)
{
    return cpfmax(0.0f, cpfmin(f, 1.0f));
}

/// Linearly interpolate (or extrapolate) between $(D f1) and $(D f2) by $(D t) percent.
cpFloat cpflerp(cpFloat f1, cpFloat f2, cpFloat t)
{
    return f1 * (1.0f - t) + f2 * t;
}

/// Linearly interpolate from $(D f1) to $(D f2) by no more than $(D d).
cpFloat cpflerpconst(cpFloat f1, cpFloat f2, cpFloat d)
{
    return f1 + cpfclamp(f2 - f1, -d, d);
}
