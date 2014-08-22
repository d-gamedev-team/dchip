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
module dchip.cpPinJoint;

import std.string;

import dchip.constraints_util;
import dchip.chipmunk;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.chipmunk_types;
import dchip.cpVect;

//~ const cpConstraintClass* cpPinJointGetClass();

/// @private
struct cpPinJoint
{
    cpConstraint constraint;
    cpVect anchr1, anchr2;
    cpFloat dist = 0;

    cpVect r1, r2;
    cpVect n;
    cpFloat nMass = 0;

    cpFloat jnAcc = 0;
    cpFloat bias = 0;
}

mixin CP_DefineConstraintProperty!("cpPinJoint", cpVect, "anchr1", "Anchr1");
mixin CP_DefineConstraintProperty!("cpPinJoint", cpVect, "anchr2", "Anchr2");
mixin CP_DefineConstraintProperty!("cpPinJoint", cpFloat, "dist", "Dist");

void preStep(cpPinJoint* joint, cpFloat dt)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    joint.r1 = cpvrotate(joint.anchr1, a.rot);
    joint.r2 = cpvrotate(joint.anchr2, b.rot);

    cpVect  delta = cpvsub(cpvadd(b.p, joint.r2), cpvadd(a.p, joint.r1));
    cpFloat dist  = cpvlength(delta);
    joint.n = cpvmult(delta, 1.0f / (dist ? dist : cast(cpFloat)INFINITY));

    // calculate mass normal
    joint.nMass = 1.0f / k_scalar(a, b, joint.r1, joint.r2, joint.n);

    // calculate bias velocity
    cpFloat maxBias = joint.constraint.maxBias;
    joint.bias = cpfclamp(-bias_coef(joint.constraint.errorBias, dt) * (dist - joint.dist) / dt, -maxBias, maxBias);
}

void applyCachedImpulse(cpPinJoint* joint, cpFloat dt_coef)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    cpVect j = cpvmult(joint.n, joint.jnAcc * dt_coef);
    apply_impulses(a, b, joint.r1, joint.r2, j);
}

void applyImpulse(cpPinJoint* joint, cpFloat dt)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;
    cpVect  n = joint.n;

    // compute relative velocity
    cpFloat vrn = normal_relative_velocity(a, b, joint.r1, joint.r2, n);

    cpFloat jnMax = joint.constraint.maxForce * dt;

    // compute normal impulse
    cpFloat jn    = (joint.bias - vrn) * joint.nMass;
    cpFloat jnOld = joint.jnAcc;
    joint.jnAcc = cpfclamp(jnOld + jn, -jnMax, jnMax);
    jn = joint.jnAcc - jnOld;

    // apply impulse
    apply_impulses(a, b, joint.r1, joint.r2, cpvmult(n, jn));
}

cpFloat getImpulse(cpPinJoint* joint)
{
    return cpfabs(joint.jnAcc);
}


__gshared cpConstraintClass klass;

void _initModuleCtor_cpPinJoint()
{
    klass = cpConstraintClass(
        cast(cpConstraintPreStepImpl)&preStep,
        cast(cpConstraintApplyCachedImpulseImpl)&applyCachedImpulse,
        cast(cpConstraintApplyImpulseImpl)&applyImpulse,
        cast(cpConstraintGetImpulseImpl)&getImpulse,
    );
}

const(cpConstraintClass *) cpPinJointGetClass()
{
    return cast(cpConstraintClass*)&klass;
}

cpPinJoint *
cpPinJointAlloc()
{
    return cast(cpPinJoint*)cpcalloc(1, cpPinJoint.sizeof);
}

cpPinJoint* cpPinJointInit(cpPinJoint* joint, cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2)
{
    cpConstraintInit(cast(cpConstraint*)joint, &klass, a, b);

    joint.anchr1 = anchr1;
    joint.anchr2 = anchr2;

    // STATIC_BODY_CHECK
    cpVect p1 = (a ? cpvadd(a.p, cpvrotate(anchr1, a.rot)) : anchr1);
    cpVect p2 = (b ? cpvadd(b.p, cpvrotate(anchr2, b.rot)) : anchr2);
    joint.dist = cpvlength(cpvsub(p2, p1));

    cpAssertWarn(joint.dist > 0.0, "You created a 0 length pin joint. A pivot joint will be much more stable.");

    joint.jnAcc = 0.0f;

    return joint;
}

cpConstraint* cpPinJointNew(cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2)
{
    return cast(cpConstraint*)cpPinJointInit(cpPinJointAlloc(), a, b, anchr1, anchr2);
}
