/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module dchip.util;

import core.exception;
import std.traits;
import std.typetuple;

/**
    See: https://github.com/slembcke/Chipmunk2D/issues/56

    For two function pointers to be safely casted:
    Either return type and parameters must match perfectly,
    or they have to be pointers.
*/
T safeCast(T, S)(S s)
{
    static if (is(Unqual!T == Unqual!S))
        return cast(T)s;
    else
    static if (isSomeFunction!T && isSomeFunction!S)
    {
        alias TParams = ParameterTypeTuple!T;
        alias SParams = ParameterTypeTuple!S;

        alias TReturn = ReturnType!T;
        alias SReturn = ReturnType!S;

        static assert(is(TReturn == SReturn) || isPointer!TReturn && isPointer!SReturn);

        static assert(TParams.length == SParams.length);

        static if (is(TParams == SParams))
        {
            return cast(T)s;
        }
        else
        {
            foreach (IDX, _; SParams)
            {
                static assert(is(SParams[IDX] == TParams[IDX])
                              || isPointer!(SParams[IDX]) && isPointer!(TParams[IDX]));
            }

            return cast(T)s;
        }
    }
    else
    static if (isFloatingPoint!T && isFloatingPoint!S)
        return cast(T)s;
    else
        static assert(0);
}

/**
    Return the exception of type $(D Exc) that is
    expected to be thrown when $(D expr) is evaluated.

    This is useful to verify the custom exception type
    holds some interesting state.

    If no exception is thrown, then a new exception
    is thrown to notify the user of the missing exception.
*/
Exc getException(Exc, E)(lazy E expr, string file = __FILE__, size_t line = __LINE__)
{
    try
    {
        expr();
        throw new Exception("Error: No exception was thrown.", file, line);
    }
    catch (Exc e)
    {
        return e;
    }
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    assert({ throw new Exception("my message"); }().getException!Exception.msg == "my message");

    static class MyExc : Exception
    {
        this(string file)
        {
            this.file = file;
            super("");
        }

        string file;
    }

    assert({ throw new MyExc("file.txt"); }().getException!MyExc.file == "file.txt");

    try
    {
        assert(getException!MyExc({ }()).file == "file.txt");
    }
    catch (Exception exc)
    {
        assert(exc.msg == "Error: No exception was thrown.");
    }
}

/**
    Return the exception message of an exception.
    If no exception was thrown, then a new exception
    is thrown to notify the user of the missing exception.
*/
string getExceptionMsg(E)(lazy E expr, string file = __FILE__, size_t line = __LINE__)
{
    import std.exception : collectExceptionMsg;

    auto result = collectExceptionMsg!Throwable(expr);

    if (result is null)
        throw new Exception("Error: No exception was thrown.", file, line);

    return result;
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    assert(getExceptionMsg({ throw new Exception("my message"); }()) == "my message");
    assert(getExceptionMsg({ }()).getExceptionMsg == "Error: No exception was thrown.");
}

/** Verify that calling $(D expr) throws and contains the exception message $(D msg). */
void assertErrorsWith(E)(lazy E expr, string msg, string file = __FILE__, size_t line = __LINE__)
{
    try
    {
        expr.getExceptionMsg.assertEqual(msg);
    }
    catch (AssertError ae)
    {
        ae.file = file;
        ae.line = line;
        throw ae;
    }
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    require(1 == 2).assertErrorsWith("requirement failed.");
    require(1 == 2, "%s is not true").assertErrorsWith("%s is not true");
    require(1 == 2, "%s is not true", "1 == 2").assertErrorsWith("1 == 2 is not true");

    require(1 == 1).assertErrorsWith("requirement failed.")
                   .assertErrorsWith("Error: No exception was thrown.");
}

/**
    Similar to $(D enforce), except it can take a formatting string as the second argument.
    $(B Note:) Until Issue 8687 is fixed, $(D file) and $(D line) have to be compile-time
    arguments, which might create template bloat.
*/
T require(string file = __FILE__, size_t line = __LINE__, T, Args...)
    (T value, Args args)
{
    if (value)
        return value;

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
        enum msg = "requirement failed.";

    throw new Exception(msg, file, line);
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    require(1 == 2).getExceptionMsg.assertEqual("requirement failed.");
    require(1 == 2, "%s is not true").getExceptionMsg.assertEqual("%s is not true");
    require(1 == 2, "%s is not true", "1 == 2").getExceptionMsg.assertEqual("1 == 2 is not true");
}

template assertEquality(bool checkEqual)
{
    import std.string : format;

    void assertEquality(T1, T2)(T1 lhs, T2 rhs, string file = __FILE__, size_t line = __LINE__)
        //~ if (is(typeof(lhs == rhs) : bool))  // note: errors are better without this
    {
        static if (is(typeof(lhs == rhs) : bool))
            enum string compare = "lhs == rhs";
        else
        static if (is(typeof(equal(lhs, rhs)) : bool))
            enum string compare = "equal(lhs, rhs)";  // std.algorithm for ranges
        else
            static assert(0, format("lhs type '%s' cannot be compared against rhs type '%s'",
                __traits(identifier, T1), __traits(identifier, T2)));

        mixin(format(q{
            if (%s(%s))
                throw new AssertError(
                    format("(%%s %%s %%s) failed.", lhs.enquote, checkEqual ? "==" : "!=", rhs.enquote),
                    file, line);
        }, checkEqual ? "!" : "", compare));
    }
}

/**
    An overload of $(D enforceEx) which allows constructing the exception with the arguments its ctor supports.
    The ctor's last parameters must be a string (file) and size_t (line).
*/
template enforceEx(E)
{
    T enforceEx(T, string file = __FILE__, size_t line = __LINE__, Args...)(T value, Args args)
        if (is(typeof(new E(args, file, line))))
    {
        if (!value) throw new E(args, file, line);
        return value;
    }
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    static class Exc : Exception
    {
        this(int x, string file, int line)
        {
            super("", file, line);
            this.x = x;
        }

        int x;
    }

    try
    {
        enforceEx!Exc(false, 1);
        assert(0);
    }
    catch (Exc ex)
    {
        assert(ex.x == 1);
    }
}

/** Unittest functions which give out a message with the failing expression. */
alias assertEqual = assertEquality!true;

/** Common mispelling. */
alias assertEquals = assertEqual;

/// Ditto
alias assertNotEqual = assertEquality!false;

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    assertEqual(1, 1);
    assertNotEqual(1, 2);

    assert(assertEqual("foo", "bar").getExceptionMsg == `("foo" == "bar") failed.`);
    assert(assertNotEqual(1, 1).getExceptionMsg == "(1 != 1) failed.");

    int x;
    int[] y;
    static assert(!__traits(compiles, x.assertEqual(y)));
}

template assertProp(string prop, bool state)
{
    void assertProp(T)(T arg, string file = __FILE__, size_t line = __LINE__)
    {
        import std.string : format;

        mixin(format(q{
            if (%sarg.%s)
            {
                throw new AssertError(
                    format(".%%s is %%s : %%s", prop, !state, arg), file, line);
            }
        }, state ? "!" : "", prop));
    }
}

/// Assert range isn't empty.
alias assertEmpty = assertProp!("empty", true);

/// Ditto
alias assertNotEmpty = assertProp!("empty", false);

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    // Issue 9588 - format prints context pointer for struct
    static struct S { int x; bool empty() { return x == 0; } }

    S s = S(1);
    assert(assertEmpty(s).getExceptionMsg == ".empty is false : S(1)");

    s.x = 0;
    assertEmpty(s);

    assert(assertNotEmpty(s).getExceptionMsg == ".empty is true : S(0)");
    s.x = 1;
    assertNotEmpty(s);
}

/// Useful template to generate an assert check function
template assertOp(string op)
{
    void assertOp(T1, T2)(T1 lhs, T2 rhs,
                          string file = __FILE__,
                          size_t line = __LINE__)
    {
        import std.string : format;

        string msg = format("(%s %s %s) failed.", lhs, op, rhs);

        mixin(format(q{
            if (!(lhs %s rhs)) throw new AssertError(msg, file, line);
        }, op));
    }
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    alias assertEqual = assertOp!"==";
    alias assertNotEqual = assertOp!"!=";
    alias assertGreaterThan = assertOp!">";
    alias assertGreaterThanOrEqual = assertOp!">=";

    assertEqual(1, 1);
    assertNotEqual(1, 2);
    assertGreaterThan(2, 1);
    assertGreaterThanOrEqual(2, 2);
}

/**
    Return string representation of argument.
    If argument is already a string or a
    character, enquote it to make it more readable.
*/
string enquote(T)(T arg)
{
    import std.conv : to;
    import std.range : isInputRange, ElementEncodingType;
    import std.string : format;
    import std.traits : isSomeString, isSomeChar;

    static if (isSomeString!T)
        return format(`"%s"`, arg);
    else
    static if (isSomeChar!T)
        return format("'%s'", arg);
    else
    static if (isInputRange!T && is(ElementEncodingType!T == dchar))
        return format(`"%s"`, to!string(arg));
    else
        return to!string(arg);
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    assert(enquote(0) == "0");
    assert(enquote(enquote(0)) == `"0"`);
    assert(enquote("foo") == `"foo"`);
    assert(enquote('a') == "'a'");
}

/**
    Export all enum members as aliases. This allows enums to be used as types
    and allows its members to be used as if they're defined in module scope.
*/
package mixin template _ExportEnumMembers(E) if (is(E == enum))
{
    mixin(_makeEnumAliases!(E)());
}

/// ditto
package string _makeEnumAliases(E)() if (is(E == enum))
{
    import std.array;
    import std.string;

    enum enumName = __traits(identifier, E);
    Appender!(string[]) result;

    foreach (string member; __traits(allMembers, E))
        result ~= format("alias %s = %s.%s;", member, enumName, member);

    return result.data.join("\n");
}

///
version (CHIP_ENABLE_UNITTESTS)
unittest
{
    enum enum_type_t
    {
        foo,
        bar,
    }

    mixin _ExportEnumMembers!enum_type_t;

    enum_type_t e1 = enum_type_t.foo;  // ok
    enum_type_t e2 = bar;    // ok
}
