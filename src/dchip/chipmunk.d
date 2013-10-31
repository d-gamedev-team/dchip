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


