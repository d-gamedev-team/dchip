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
module dchip.constraints.constraint;

import std.string;

import dchip.body_;
import dchip.space;
import dchip.types;

alias cpConstraintPreStepImpl = void function(cpConstraint* constraint, cpFloat dt);
alias cpConstraintApplyCachedImpulseImpl = void function(cpConstraint* constraint, cpFloat dt_coef);
alias cpConstraintApplyImpulseImpl = void function(cpConstraint* constraint, cpFloat dt);
alias cpConstraintGetImpulseImpl = cpFloat function(cpConstraint* constraint);

/// @private
struct cpConstraintClass
{
    cpConstraintPreStepImpl preStep;
    cpConstraintApplyCachedImpulseImpl applyCachedImpulse;
    cpConstraintApplyImpulseImpl applyImpulse;
    cpConstraintGetImpulseImpl getImpulse;
}

/// Callback function type that gets called before solving a joint.
alias cpConstraintPreSolveFunc = void function(cpConstraint* constraint, cpSpace* space);

/// Callback function type that gets called after solving a joint.
alias cpConstraintPostSolveFunc = void function(cpConstraint* constraint, cpSpace* space);

/// Opaque cpConstraint struct.
struct cpConstraint
{
    version (CHIP_ALLOW_PRIVATE_ACCESS)
        const cpConstraintClass * klass;
    else
        package const cpConstraintClass * klass;

    /// The first body connected to this constraint.
    cpBody* a;

    /// The second body connected to this constraint.
    cpBody* b;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpSpace * space;
    else
        package cpSpace * space;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpConstraint * next_a;
    else
        package cpConstraint * next_a;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpConstraint * next_b;
    else
        package cpConstraint * next_b;

    /// The maximum force that this constraint is allowed to use.
    /// Defaults to infinity.
    cpFloat maxForce;

    /// The rate at which joint error is corrected.
    /// Defaults to pow(1.0 - 0.1, 60.0) meaning that it will
    /// correct 10% of the error every 1/60th of a second.
    cpFloat errorBias;

    /// The maximum rate at which joint error is corrected.
    /// Defaults to infinity.
    cpFloat maxBias;

    /// Function called before the solver runs.
    /// Animate your joint anchors, update your motor torque, etc.
    cpConstraintPreSolveFunc preSolve;

    /// Function called after the solver runs.
    /// Use the applied impulse to perform effects like breakable joints.
    cpConstraintPostSolveFunc postSolve;

    /// User definable data pointer.
    /// Generally this points to your the game object class so you can access it
    /// when given a cpConstraint reference in a callback.
    cpDataPointer data;
}

/// Destroy a constraint.
void cpConstraintDestroy(cpConstraint* constraint);

/// Destroy and free a constraint.
void cpConstraintFree(cpConstraint* constraint);

/// @private
void cpConstraintActivateBodies(cpConstraint* constraint)
{
    cpBody* a = constraint.a;

    if (a)
        cpBodyActivate(a);

    cpBody* b = constraint.b;

    if (b)
        cpBodyActivate(b);
}

mixin template CP_DefineConstraintStructGetter(type, string member, string name)
{
    mixin(q{
        type cpConstraintGet%s(const cpConstraint * constraint) { return constraint.%s; }
    }.format(name, member));
}

mixin template CP_DefineConstraintStructSetter(type, string member, string name)
{
    mixin(q{
        void cpConstraintSet%s(cpConstraint * constraint, type value)
        {
            cpConstraintActivateBodies(constraint);
            constraint.%s = value;
        }
    }.format(name, member));
}

mixin template CP_DefineConstraintStructProperty(type, string member, string name)
{
    mixin CP_DefineConstraintStructGetter!(type, member, name);
    mixin CP_DefineConstraintStructSetter!(type, member, name);
}

mixin CP_DefineConstraintStructGetter!(cpSpace*, CP_PRIVATE(space), Space);

mixin CP_DefineConstraintStructGetter!(cpBody*, a, A);
mixin CP_DefineConstraintStructGetter!(cpBody*, b, B);
mixin CP_DefineConstraintStructProperty!(cpFloat, maxForce, MaxForce);
mixin CP_DefineConstraintStructProperty!(cpFloat, errorBias, ErrorBias);
mixin CP_DefineConstraintStructProperty!(cpFloat, maxBias, MaxBias);
mixin CP_DefineConstraintStructProperty!(cpConstraintPreSolveFunc, preSolve, PreSolveFunc);
mixin CP_DefineConstraintStructProperty!(cpConstraintPostSolveFunc, postSolve, PostSolveFunc);
mixin CP_DefineConstraintStructProperty!(cpDataPointer, data, UserData);

// Get the last impulse applied by this constraint.
cpFloat cpConstraintGetImpulse(cpConstraint* constraint)
{
    return constraint.klass.getImpulse(constraint);
}

string cpConstraintCheckCast(string constraint, string struct_)
{
    return `cpAssertHard(%1$s.klass == %2$sGetClass(), "Constraint is not a %2$s");`;
}

mixin template CP_DefineConstraintGetter(string struct_, type, string member, string name)
{
    mixin(q{
        type %1$sGet%2$s(const cpConstraint* constraint)
        {
            mixin(cpConstraintCheckCast(constraint, %1$s));
            return (cast(%1$s*)constraint).%3$s;
        }
    }.format(struct_, name, member));
}

mixin template CP_DefineConstraintSetter(string struct_, type, string member, string name)
{
    mixin(q{
        type %1$sSet%2$s(cpConstraint * constraint, type value)
        {
            mixin(cpConstraintCheckCast(constraint, %1$s));
            cpConstraintActivateBodies(constraint);
            (cast(%1$s*)constraint).%3$s= value;
        }
    }.format(struct_, name, member));
}

mixin template CP_DefineConstraintProperty(string struct_, type, string member, string name)
{
    mixin CP_DefineConstraintGetter!(struct_, type, member, name);
    mixin CP_DefineConstraintSetter!(struct_, type, member, name);
}
