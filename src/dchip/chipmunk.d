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
module dchip.chipmunk;

import core.stdc.stdlib : calloc, realloc, free;
import core.stdc.string : memcpy;

import std.string;

import dchip.cpBB;
import dchip.cpBody;
import dchip.cpPolyShape;
import dchip.chipmunk_types;
import dchip.cpVect;
import dchip.cpSpatialIndex;
import dchip.util;

/** Workaround for cycles between module constructors. */
shared static this()
{
    import dchip.cpBBTree;
    import dchip.cpCollision;
    import dchip.cpCollision;
    import dchip.cpDampedRotarySpring;
    import dchip.cpDampedSpring;
    import dchip.cpGearJoint;
    import dchip.cpGrooveJoint;
    import dchip.cpPinJoint;
    import dchip.cpPivotJoint;
    import dchip.cpPolyShape;
    import dchip.cpRatchetJoint;
    import dchip.cpRotaryLimitJoint;
    import dchip.cpShape;
    import dchip.cpSimpleMotor;
    import dchip.cpSlideJoint;
    import dchip.cpSpaceHash;
    import dchip.cpSweep1D;

    _initModuleCtor_cpBBTree();
    _initModuleCtor_cpCollision();
    _initModuleCtor_cpDampedRotarySpring();
    _initModuleCtor_cpDampedSpring();
    _initModuleCtor_cpGearJoint();
    _initModuleCtor_cpGrooveJoint();
    _initModuleCtor_cpPinJoint();
    _initModuleCtor_cpPivotJoint();
    _initModuleCtor_cpPolyShape();
    _initModuleCtor_cpRatchetJoint();
    _initModuleCtor_cpRotaryLimitJoint();
    _initModuleCtor_cpShape();
    _initModuleCtor_cpSimpleMotor();
    _initModuleCtor_cpSlideJoint();
    _initModuleCtor_cpSpaceHash();
    _initModuleCtor_cpSweep1D();
}

/**
    Workaround for a linker bug with RDMD local imports:
    http://d.puremagic.com/issues/show_bug.cgi?id=7016
*/
version (CHIP_ENABLE_UNITTESTS)
{
    import dchip.util;
}

/**
    Throw when an internal library condition is unsatisfied.
    Continuing the use of the library after this error is
    thrown will lead to undefined behavior.
*/
class DChipError : Error
{
    ///
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

/**
    If the $(D CHIP_ENABLE_WARNINGS) version is set,
    print a warning to stderr if condition is false.
*/
void cpAssertWarn(string file = __FILE__, size_t line = __LINE__, E, Args...)
                         (lazy E condition, lazy string expr, lazy Args args)
{
    version (CHIP_ENABLE_WARNINGS)
    {
        import std.stdio : stderr, writefln;

        if (!!condition)
            return;

        static if (Args.length)
        {
            static if (Args.length > 1)
            {
                import std.string : format;
                string msg = format(args[0], args[1 .. $]);
            }
            else
            {
                import std.conv : text;
                string msg = text(args);
            }
        }
        else
            enum msg = "Requirement failed";

        stderr.writefln(`%s(%s): Warning: %s. Failed condition: "%s".`, file, line, msg, expr);
    }
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    int iteration = 10;
    int WARN_GJK_ITERATIONS = 10;

    static assert (is(typeof({
    cpAssertWarn(iteration < WARN_GJK_ITERATIONS,
                "iteration < WARN_GJK_ITERATIONS");

    cpAssertWarn(iteration < WARN_GJK_ITERATIONS,
                "iteration < WARN_GJK_ITERATIONS",
        "High GJK iterations: %d", iteration);
    }())));
}

/**
    If the $(D CHIP_ENABLE_WARNINGS) version is set,
    throw a $(D DChipError) if condition is false.
*/
void cpAssertSoft(string file = __FILE__, size_t line = __LINE__, E, Args...)
                         (lazy E condition, lazy string expr, lazy Args args)
{
    version (CHIP_ENABLE_WARNINGS)
    {
        cpAssertHard!(file, line, E, Args)(condition, expr, args);
    }
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    import std.exception : assertNotThrown;
    import dchip.util : assertErrorsWith;

    int iteration = 10;
    int WARN_GJK_ITERATIONS = 10;

    version (CHIP_ENABLE_WARNINGS)
    {
        cpAssertSoft(iteration < WARN_GJK_ITERATIONS, "iteration < WARN_GJK_ITERATIONS")
            .assertErrorsWith(`Error: Requirement failed. Failed condition: "iteration < WARN_GJK_ITERATIONS".`);

        assertNotThrown!DChipError(cpAssertSoft(iteration == WARN_GJK_ITERATIONS,
                                               "iteration == WARN_GJK_ITERATIONS"));
    }
    else
    {
        assertNotThrown!DChipError(cpAssertSoft(iteration < WARN_GJK_ITERATIONS,
                                               "iteration < WARN_GJK_ITERATIONS"));
    }
}

/** Throw a $(D DChipError) if condition is false. */
void cpAssertHard(string file = __FILE__, size_t line = __LINE__, E, Args...)
                         (lazy E condition, lazy string expr, lazy Args args)
{
    import std.string : format;

    if (!!condition)
        return;

    static if (Args.length)
    {
        static if (Args.length > 1)
        {
            string msg = format(args[0], args[1 .. $]);
        }
        else
        {
            import std.conv : text;
            string msg = text(args);
        }
    }
    else
        enum msg = "Requirement failed";

    throw new DChipError(format(`Error: %s. Failed condition: "%s".`, msg, expr), file, line);
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    import std.exception : assertNotThrown;
    import dchip.util : assertErrorsWith;

    int iteration = 10;
    int WARN_GJK_ITERATIONS = 10;

    cpAssertHard(iteration < WARN_GJK_ITERATIONS, "iteration < WARN_GJK_ITERATIONS")
        .assertErrorsWith(`Error: Requirement failed. Failed condition: "iteration < WARN_GJK_ITERATIONS".`);

    assertNotThrown!DChipError(cpAssertHard(iteration == WARN_GJK_ITERATIONS,
                                           "iteration == WARN_GJK_ITERATIONS"));
}

/// Allocated size for various Chipmunk buffers.
enum CP_BUFFER_BYTES = 32 * 1024;

/// Chipmunk calloc() alias.
alias cpcalloc = calloc;

/// Chipmunk realloc() alias.
alias cprealloc = realloc;

/// Chipmunk free() alias.
alias cpfree = free;

/// Chipmunk 6.2.1
enum CP_VERSION_MAJOR = 6;
enum CP_VERSION_MINOR = 2;
enum CP_VERSION_RELEASE = 1;

/// Version string.
enum cpVersionString = format("%s.%s.%s", CP_VERSION_MAJOR, CP_VERSION_MINOR, CP_VERSION_RELEASE);

/// @deprecated
deprecated("cpInitChipmunk is deprecated and no longer required. It will be removed in the future.")
void cpInitChipmunk() { }

/// Calculate the moment of inertia for a circle.
/// @c r1 and @c r2 are the inner and outer diameters. A solid circle has an inner diameter of 0.
cpFloat cpMomentForCircle(cpFloat m, cpFloat r1, cpFloat r2, cpVect offset)
{
    return m * (0.5f * (r1 * r1 + r2 * r2) + cpvlengthsq(offset));
}

/// Calculate area of a hollow circle.
/// @c r1 and @c r2 are the inner and outer diameters. A solid circle has an inner diameter of 0.
cpFloat cpAreaForCircle(cpFloat r1, cpFloat r2)
{
    return safeCast!cpFloat(M_PI) * cpfabs(r1 * r1 - r2 * r2);
}

/// Calculate the moment of inertia for a line segment.
/// Beveling radius is not supported.
cpFloat cpMomentForSegment(cpFloat m, cpVect a, cpVect b)
{
    cpVect offset = cpvmult(cpvadd(a, b), 0.5f);
    return m * (cpvdistsq(b, a) / 12.0f + cpvlengthsq(offset));
}

/// Calculate the area of a fattened (capsule shaped) line segment.
cpFloat cpAreaForSegment(cpVect a, cpVect b, cpFloat r)
{
    return r * (safeCast!cpFloat(M_PI) * r + 2.0f * cpvdist(a, b));
}

/// Calculate the moment of inertia for a solid polygon shape assuming it's center of gravity is at it's centroid. The offset is added to each vertex.
cpFloat cpMomentForPoly(cpFloat m, const int numVerts, const cpVect* verts, cpVect offset)
{
    if (numVerts == 2)
        return cpMomentForSegment(m, verts[0], verts[1]);

    cpFloat sum1 = 0.0f;
    cpFloat sum2 = 0.0f;

    for (int i = 0; i < numVerts; i++)
    {
        cpVect v1 = cpvadd(verts[i], offset);
        cpVect v2 = cpvadd(verts[(i + 1) % numVerts], offset);

        cpFloat a = cpvcross(v2, v1);
        cpFloat b = cpvdot(v1, v1) + cpvdot(v1, v2) + cpvdot(v2, v2);

        sum1 += a * b;
        sum2 += a;
    }

    return (m * sum1) / (6.0f * sum2);
}

/// Calculate the signed area of a polygon. A Clockwise winding gives positive area.
/// This is probably backwards from what you expect, but matches Chipmunk's the winding for poly shapes.
cpFloat cpAreaForPoly(const int numVerts, const cpVect* verts)
{
    cpFloat area = 0.0f;

    for (int i = 0; i < numVerts; i++)
    {
        area += cpvcross(verts[i], verts[(i + 1) % numVerts]);
    }

    return -area / 2.0f;
}

void cpLoopIndexes(cpVect* verts, int count, int* start, int* end)
{
    (*start) = (*end) = 0;
    cpVect min = verts[0];
    cpVect max = min;

    for (int i = 1; i < count; i++)
    {
        cpVect v = verts[i];

        if (v.x < min.x || (v.x == min.x && v.y < min.y))
        {
            min      = v;
            (*start) = i;
        }
        else if (v.x > max.x || (v.x == max.x && v.y > max.y))
        {
            max    = v;
            (*end) = i;
        }
    }
}

/** Avoid bringing in std.algorithm. */
void SWAP(ref cpVect a, ref cpVect b)
{
    cpVect tmp = a;
    a = b;
    b = tmp;
}

int QHullPartition(cpVect* verts, int count, cpVect a, cpVect b, cpFloat tol)
{
    if (count == 0)
        return 0;

    cpFloat max = 0;
    int pivot   = 0;

    cpVect  delta    = cpvsub(b, a);
    cpFloat valueTol = tol * cpvlength(delta);

    int head = 0;

    for (int tail = count - 1; head <= tail; )
    {
        cpFloat value = cpvcross(delta, cpvsub(verts[head], a));

        if (value > valueTol)
        {
            if (value > max)
            {
                max   = value;
                pivot = head;
            }

            head++;
        }
        else
        {
            SWAP(verts[head], verts[tail]);
            tail--;
        }
    }

    // move the new pivot to the front if it's not already there.
    if (pivot != 0)
        SWAP(verts[0], verts[pivot]);
    return head;
}

int QHullReduce(cpFloat tol, cpVect* verts, int count, cpVect a, cpVect pivot, cpVect b, cpVect* result)
{
    if (count < 0)
    {
        return 0;
    }
    else if (count == 0)
    {
        result[0] = pivot;
        return 1;
    }
    else
    {
        int left_count = QHullPartition(verts, count, a, pivot, tol);
        int index      = QHullReduce(tol, verts + 1, left_count - 1, a, verts[0], pivot, result);

        result[index++] = pivot;

        int right_count = QHullPartition(verts + left_count, count - left_count, pivot, b, tol);
        return index + QHullReduce(tol, verts + left_count + 1, right_count - 1, pivot, verts[left_count], b, result + index);
    }
}

/// Calculate the natural centroid of a polygon.
cpVect cpCentroidForPoly(const int numVerts, const cpVect* verts)
{
    cpFloat sum  = 0.0f;
    cpVect  vsum = cpvzero;

    for (int i = 0; i < numVerts; i++)
    {
        cpVect  v1    = verts[i];
        cpVect  v2    = verts[(i + 1) % numVerts];
        cpFloat cross = cpvcross(v1, v2);

        sum += cross;
        vsum = cpvadd(vsum, cpvmult(cpvadd(v1, v2), cross));
    }

    return cpvmult(vsum, 1.0f / (3.0f * sum));
}

/// Center the polygon on the origin. (Subtracts the centroid of the polygon from each vertex)
void cpRecenterPoly(const int numVerts, cpVect* verts)
{
    cpVect centroid = cpCentroidForPoly(numVerts, verts);

    for (int i = 0; i < numVerts; i++)
    {
        verts[i] = cpvsub(verts[i], centroid);
    }
}

/// Calculate the moment of inertia for a solid box.
cpFloat cpMomentForBox(cpFloat m, cpFloat width, cpFloat height)
{
    return m * (width * width + height * height) / 12.0f;
}

/// Calculate the moment of inertia for a solid box.
cpFloat cpMomentForBox2(cpFloat m, cpBB box)
{
    cpFloat width  = box.r - box.l;
    cpFloat height = box.t - box.b;
    cpVect  offset = cpvmult(cpv(box.l + box.r, box.b + box.t), 0.5f);

    // TODO NaN when offset is 0 and m is INFINITY
    return cpMomentForBox(m, width, height) + m * cpvlengthsq(offset);
}

/// Calculate the convex hull of a given set of points. Returns the count of points in the hull.
/// @c result must be a pointer to a @c cpVect array with at least @c count elements. If @c result is @c NULL, then @c verts will be reduced instead.
/// @c first is an optional pointer to an integer to store where the first vertex in the hull came from (i.e. verts[first] == result[0])
/// @c tol is the allowed amount to shrink the hull when simplifying it. A tolerance of 0.0 creates an exact hull.
/// QuickHull seemed like a neat algorithm, and efficient-ish for large input sets.
/// My implementation performs an in place reduction using the result array as scratch space.
int cpConvexHull(int count, cpVect* verts, cpVect* result, int* first, cpFloat tol)
{
    if (result)
    {
        // Copy the line vertexes into the empty part of the result polyline to use as a scratch buffer.
        memcpy(result, verts, count * cpVect.sizeof);
    }
    else
    {
        // If a result array was not specified, reduce the input instead.
        result = verts;
    }

    // Degenerate case, all poins are the same.
    int start, end;
    cpLoopIndexes(verts, count, &start, &end);

    if (start == end)
    {
        if (first)
            (*first) = 0;
        return 1;
    }

    SWAP(result[0], result[start]);
    SWAP(result[1], result[end == 0 ? start : end]);

    cpVect a = result[0];
    cpVect b = result[1];

    if (first)
        (*first) = start;
    int resultCount = QHullReduce(tol, result + 2, count - 2, a, b, a, result + 1) + 1;
    cpAssertSoft(cpPolyValidate(result, resultCount),
                 "Internal error: cpConvexHull() and cpPolyValidate() did not agree."~
                 "Please report this error with as much info as you can.");
    return resultCount;
}
