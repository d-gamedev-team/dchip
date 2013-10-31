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

import dchip.bb;
import dchip.body_;
import dchip.vector;
import dchip.spatial_index;
import dchip.types;

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
package void cpAssertWarn(string file = __FILE__, size_t line = __LINE__, E, Args...)
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
package void cpAssertSoft(string file = __FILE__, size_t line = __LINE__, E, Args...)
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
package void cpAssertHard(string file = __FILE__, size_t line = __LINE__, E, Args...)
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
extern const char* cpVersionString;

/// @deprecated
void cpInitChipmunk();

/// Enables segment to segment shape collisions.
void cpEnableSegmentToSegmentCollisions();

/// Calculate the moment of inertia for a circle.
/// @c r1 and @c r2 are the inner and outer diameters. A solid circle has an inner diameter of 0.
cpFloat cpMomentForCircle(cpFloat m, cpFloat r1, cpFloat r2, cpVect offset);

/// Calculate area of a hollow circle.
/// @c r1 and @c r2 are the inner and outer diameters. A solid circle has an inner diameter of 0.
cpFloat cpAreaForCircle(cpFloat r1, cpFloat r2);

/// Calculate the moment of inertia for a line segment.
/// Beveling radius is not supported.
cpFloat cpMomentForSegment(cpFloat m, cpVect a, cpVect b);

/// Calculate the area of a fattened (capsule shaped) line segment.
cpFloat cpAreaForSegment(cpVect a, cpVect b, cpFloat r);

/// Calculate the moment of inertia for a solid polygon shape assuming it's center of gravity is at it's centroid. The offset is added to each vertex.
cpFloat cpMomentForPoly(cpFloat m, int numVerts, const cpVect* verts, cpVect offset);

/// Calculate the signed area of a polygon. A Clockwise winding gives positive area.
/// This is probably backwards from what you expect, but matches Chipmunk's the winding for poly shapes.
cpFloat cpAreaForPoly(const int numVerts, const cpVect* verts);

/// Calculate the natural centroid of a polygon.
cpVect cpCentroidForPoly(const int numVerts, const cpVect* verts);

/// Center the polygon on the origin. (Subtracts the centroid of the polygon from each vertex)
void cpRecenterPoly(const int numVerts, cpVect* verts);

/// Calculate the moment of inertia for a solid box.
cpFloat cpMomentForBox(cpFloat m, cpFloat width, cpFloat height);

/// Calculate the moment of inertia for a solid box.
cpFloat cpMomentForBox2(cpFloat m, cpBB box);

/// Calculate the convex hull of a given set of points. Returns the count of points in the hull.
/// @c result must be a pointer to a @c cpVect array with at least @c count elements. If @c result is @c NULL, then @c verts will be reduced instead.
/// @c first is an optional pointer to an integer to store where the first vertex in the hull came from (i.e. verts[first] == result[0])
/// @c tol is the allowed amount to shrink the hull when simplifying it. A tolerance of 0.0 creates an exact hull.
int cpConvexHull(int count, cpVect* verts, cpVect* result, int* first, cpFloat tol);

/// Convenience macro to work with cpConvexHull.
/// @c count and @c verts is the input array passed to cpConvexHull().
/// @c count_var and @c verts_var are the names of the variables the macro creates to store the result.
/// The output vertex array is allocated on the stack using alloca() so it will be freed automatically, but cannot be returned from the current scope.
//~ #define CP_CONVEX_HULL(__count__, __verts__, __count_var__, __verts_var__) \
    //~ cpVect * __verts_var__ = (cpVect*)alloca(__count__ * sizeof(cpVect)); \
    //~ int __count_var__ = cpConvexHull(__count__, __verts__, __verts_var__, NULL, 0.0); \
