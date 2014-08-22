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
module dchip.cpSlideJoint;

import std.string;

import dchip.constraints_util;
import dchip.chipmunk;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.chipmunk_types;
import dchip.cpVect;

//~ const cpConstraintClass* cpSlideJointGetClass();

/// @private
struct cpSlideJoint
{
    cpConstraint constraint;
    cpVect anchr1, anchr2;
    cpFloat min = 0, max = 0;

    cpVect r1, r2;
    cpVect n;
    cpFloat nMass = 0;

    cpFloat jnAcc = 0;
    cpFloat bias = 0;
}

mixin CP_DefineConstraintProperty!("cpSlideJoint", cpVect, "anchr1", "Anchr1");
mixin CP_DefineConstraintProperty!("cpSlideJoint", cpVect, "anchr2", "Anchr2");
mixin CP_DefineConstraintProperty!("cpSlideJoint", cpFloat, "min", "Min");
mixin CP_DefineConstraintProperty!("cpSlideJoint", cpFloat, "max", "Max");

void preStep(cpSlideJoint* joint, cpFloat dt)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    joint.r1 = cpvrotate(joint.anchr1, a.rot);
    joint.r2 = cpvrotate(joint.anchr2, b.rot);

    cpVect  delta = cpvsub(cpvadd(b.p, joint.r2), cpvadd(a.p, joint.r1));
    cpFloat dist  = cpvlength(delta);
    cpFloat pdist = 0.0f;

    if (dist > joint.max)
    {
        pdist    = dist - joint.max;
        joint.n = cpvnormalize_safe(delta);
    }
    else if (dist < joint.min)
    {
        pdist    = joint.min - dist;
        joint.n = cpvneg(cpvnormalize_safe(delta));
    }
    else
    {
        joint.n     = cpvzero;
        joint.jnAcc = 0.0f;
    }

    // calculate mass normal
    joint.nMass = 1.0f / k_scalar(a, b, joint.r1, joint.r2, joint.n);

    // calculate bias velocity
    cpFloat maxBias = joint.constraint.maxBias;
    joint.bias = cpfclamp(-bias_coef(joint.constraint.errorBias, dt) * pdist / dt, -maxBias, maxBias);
}

void applyCachedImpulse(cpSlideJoint* joint, cpFloat dt_coef)
{
    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    cpVect j = cpvmult(joint.n, joint.jnAcc * dt_coef);
    apply_impulses(a, b, joint.r1, joint.r2, j);
}

void applyImpulse(cpSlideJoint* joint, cpFloat dt)
{
    if (cpveql(joint.n, cpvzero))
        return;                                // early exit

    cpBody* a = joint.constraint.a;
    cpBody* b = joint.constraint.b;

    cpVect n  = joint.n;
    cpVect r1 = joint.r1;
    cpVect r2 = joint.r2;

    // compute relative velocity
    cpVect  vr  = relative_velocity(a, b, r1, r2);
    cpFloat vrn = cpvdot(vr, n);

    // compute normal impulse
    cpFloat jn    = (joint.bias - vrn) * joint.nMass;
    cpFloat jnOld = joint.jnAcc;
    joint.jnAcc = cpfclamp(jnOld + jn, -joint.constraint.maxForce * dt, 0.0f);
    jn = joint.jnAcc - jnOld;

    // apply impulse
    apply_impulses(a, b, joint.r1, joint.r2, cpvmult(n, jn));
}

cpFloat getImpulse(cpConstraint* joint)
{
    return cpfabs((cast(cpSlideJoint*)joint).jnAcc);
}

__gshared cpConstraintClass klass;

void _initModuleCtor_cpSlideJoint()
{
    klass = cpConstraintClass(
        cast(cpConstraintPreStepImpl)&preStep,
        cast(cpConstraintApplyCachedImpulseImpl)&applyCachedImpulse,
        cast(cpConstraintApplyImpulseImpl)&applyImpulse,
        cast(cpConstraintGetImpulseImpl)&getImpulse,
    );
}

const(cpConstraintClass *) cpSlideJointGetClass()
{
    return cast(cpConstraintClass*)&klass;
}

cpSlideJoint *
cpSlideJointAlloc()
{
    return cast(cpSlideJoint*)cpcalloc(1, cpSlideJoint.sizeof);
}

cpSlideJoint* cpSlideJointInit(cpSlideJoint* joint, cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2, cpFloat min, cpFloat max)
{
    cpConstraintInit(cast(cpConstraint*)joint, &klass, a, b);

    joint.anchr1 = anchr1;
    joint.anchr2 = anchr2;
    joint.min    = min;
    joint.max    = max;

    joint.jnAcc = 0.0f;

    return joint;
}

cpConstraint* cpSlideJointNew(cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2, cpFloat min, cpFloat max)
{
    return cast(cpConstraint*)cpSlideJointInit(cpSlideJointAlloc(), a, b, anchr1, anchr2, min, max);
}
