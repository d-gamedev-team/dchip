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
module dchip.chipmunk_types;

import core.stdc.stdint : uintptr_t, uint32_t;

import std.math : sqrt, sin, cos, acos, atan2, fmod, exp, pow, floor, ceil, PI, E;

import dchip.cpVect;

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

/// Hash value type.
alias cpHashValue = uintptr_t;

/// Type used internally to cache colliding object info for cpCollideShapes().
/// Should be at least 32 bits.
alias cpCollisionID = uint32_t;

alias cpBool = bool;  /// Bools
enum cpTrue  = true;  /// ditto
enum cpFalse = false; /// ditto

/// Type used for user data pointers.
alias cpDataPointer = void*;

/// Type used for cpSpace.collision_type.
alias cpCollisionType = uintptr_t;

/// Type used for cpShape.group.
alias cpGroup = uintptr_t;

/// Type used for cpShape.layers.
alias cpLayers = uint;

/// Type used for various timestamps in Chipmunk.
alias cpTimestamp = uint;

/// Value for cpShape.group signifying that a shape is in no group.
enum CP_NO_GROUP = 0;

/// Value for cpShape.layers signifying that a shape is in every layer.
enum CP_ALL_LAYERS = ~cast(cpLayers)0;

/// Chipmunk's 2D vector type.
struct cpVect
{
    cpFloat x = 0, y = 0;

    cpVect opBinary(string op : "*")(const cpFloat s)
    {
        return cpvmult(this, s);
    }

    cpVect opBinary(string op : "+")(const cpVect v2)
    {
        return cpvadd(this, v2);
    }

    cpVect opBinary(string op : "-")(const cpVect v2)
    {
        return cpvsub(this, v2);
    }

    cpBool opEquals(const cpVect v2)
    {
        return cpveql(this, v2);
    }

    cpVect opUnary(string op : "-")()
    {
        return cpvneg(this);
    }
}

/// Chipmunk's 2D matrix type.
struct cpMat2x2
{
    /// Row major [[a, b][c d]]
    cpFloat a = 0, b = 0, c = 0, d = 0;
}
