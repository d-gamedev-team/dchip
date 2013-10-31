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
module dchip.cpGearJoint;

import std.string;

import dchip.chipmunk;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.chipmunk_types;

const cpConstraintClass* cpGearJointGetClass();

/// @private
struct cpGearJoint
{
    cpConstraint constraint;
    cpFloat phase, ratio;
    cpFloat ratio_inv;

    cpFloat iSum;

    cpFloat bias;
    cpFloat jAcc;
}

/// Allocate a gear joint.
cpGearJoint* cpGearJointAlloc();

/// Initialize a gear joint.
cpGearJoint* cpGearJointInit(cpGearJoint* joint, cpBody* a, cpBody* b, cpFloat phase, cpFloat ratio);

/// Allocate and initialize a gear joint.
cpConstraint* cpGearJointNew(cpBody* a, cpBody* b, cpFloat phase, cpFloat ratio);

mixin CP_DefineConstraintProperty!("cpGearJoint", cpFloat, "phase", "Phase");
mixin CP_DefineConstraintGetter!("cpGearJoint", cpFloat, "ratio", "Ratio");

/// Set the ratio of a gear joint.
void cpGearJointSetRatio(cpConstraint* constraint, cpFloat value);
