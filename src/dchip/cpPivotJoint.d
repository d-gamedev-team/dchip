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
module dchip.cpPivotJoint;

import std.string;

import dchip.constraints_util;
import dchip.chipmunk;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.chipmunk_types;
import dchip.cpVect;

//~ const cpConstraintClass* cpPivotJointGetClass();

/// @private
struct cpPivotJoint
{
    cpConstraint constraint;
    cpVect anchr1, anchr2;

    cpVect r1, r2;
    cpMat2x2 k;

    cpVect jAcc;
    cpVect bias;
}

mixin CP_DefineConstraintProperty!("cpPivotJoint", cpVect, "anchr1", "Anchr1");
mixin CP_DefineConstraintProperty!("cpPivotJoint", cpVect, "anchr2", "Anchr2");

void preStep(cpPivotJoint* joint, cpFloat dt)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    joint.r1 = cpvrotate(joint.anchr1, a.rot);
    joint.r2 = cpvrotate(joint.anchr2, b.rot);

    // Calculate mass tensor
    joint.k = k_tensor(a, b, joint.r1, joint.r2);

    // calculate bias velocity
    cpVect delta = cpvsub(cpvadd(b.p, joint.r2), cpvadd(a.p, joint.r1));
    joint.bias = cpvclamp(cpvmult(delta, -bias_coef(joint.constraint.errorBias, dt) / dt), joint.constraint.maxBias);
}

void applyCachedImpulse(cpPivotJoint* joint, cpFloat dt_coef)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    apply_impulses(a, b, joint.r1, joint.r2, cpvmult(joint.jAcc, dt_coef));
}

void applyImpulse(cpPivotJoint* joint, cpFloat dt)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    cpVect r1 = joint.r1;
    cpVect r2 = joint.r2;

    // compute relative velocity
    cpVect vr = relative_velocity(a, b, r1, r2);

    // compute normal impulse
    cpVect j    = cpMat2x2Transform(joint.k, cpvsub(joint.bias, vr));
    cpVect jOld = joint.jAcc;
    joint.jAcc = cpvclamp(cpvadd(joint.jAcc, j), joint.constraint.maxForce * dt);
    j = cpvsub(joint.jAcc, jOld);

    // apply impulse
    apply_impulses(a, b, joint.r1, joint.r2, j);
}

cpFloat getImpulse(cpConstraint* joint)
{
    return cpvlength((cast(cpPivotJoint*)joint).jAcc);
}

__gshared cpConstraintClass klass;

void _initModuleCtor_cpPivotJoint()
{
    klass = cpConstraintClass(
        cast(cpConstraintPreStepImpl)&preStep,
        cast(cpConstraintApplyCachedImpulseImpl)&applyCachedImpulse,
        cast(cpConstraintApplyImpulseImpl)&applyImpulse,
        cast(cpConstraintGetImpulseImpl)&getImpulse,
    );
};

const(cpConstraintClass *) cpPivotJointGetClass()
{
    return cast(cpConstraintClass*)&klass;
}

cpPivotJoint *
cpPivotJointAlloc()
{
    return cast(cpPivotJoint*)cpcalloc(1, cpPivotJoint.sizeof);
}

cpPivotJoint* cpPivotJointInit(cpPivotJoint* joint, cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2)
{
    cpConstraintInit(cast(cpConstraint*)joint, &klass, a, b);

    joint.anchr1 = anchr1;
    joint.anchr2 = anchr2;

    joint.jAcc = cpvzero;

    return joint;
}

cpConstraint* cpPivotJointNew2(cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2)
{
    return cast(cpConstraint*)cpPivotJointInit(cpPivotJointAlloc(), a, b, anchr1, anchr2);
}

cpConstraint* cpPivotJointNew(cpBody* a, cpBody* b, cpVect pivot)
{
    cpVect anchr1 = (a ? cpBodyWorld2Local(a, pivot) : pivot);
    cpVect anchr2 = (b ? cpBodyWorld2Local(b, pivot) : pivot);
    return cpPivotJointNew2(a, b, anchr1, anchr2);
}
