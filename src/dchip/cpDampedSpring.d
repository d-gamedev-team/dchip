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
module dchip.cpDampedSpring;

import std.string;

import dchip.chipmunk;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.chipmunk_types;

alias cpDampedSpringForceFunc = cpFloat function(cpConstraint* spring, cpFloat dist);

const cpConstraintClass* cpDampedSpringGetClass();

/// @private
struct cpDampedSpring
{
    cpConstraint constraint;
    cpVect anchr1, anchr2;
    cpFloat restLength;
    cpFloat stiffness;
    cpFloat damping;
    cpDampedSpringForceFunc springForceFunc;

    cpFloat target_vrn;
    cpFloat v_coef;

    cpVect r1, r2;
    cpFloat nMass;
    cpVect n;

    cpFloat jAcc;
}

/// Allocate a damped spring.
cpDampedSpring* cpDampedSpringAlloc();

/// Initialize a damped spring.
cpDampedSpring* cpDampedSpringInit(cpDampedSpring* joint, cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2, cpFloat restLength, cpFloat stiffness, cpFloat damping);

/// Allocate and initialize a damped spring.
cpConstraint* cpDampedSpringNew(cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2, cpFloat restLength, cpFloat stiffness, cpFloat damping);

mixin CP_DefineConstraintProperty!("cpDampedSpring", cpVect, "anchr1", "Anchr1");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpVect, "anchr2", "Anchr2");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpFloat, "restLength", "RestLength");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpFloat, "stiffness", "Stiffness");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpFloat, "damping", "Damping");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpDampedSpringForceFunc, "springForceFunc", "SpringForceFunc");
