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

import dchip.constraints_util;
import dchip.chipmunk;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.chipmunk_types;
import dchip.cpVect;

alias cpDampedSpringForceFunc = cpFloat function(cpConstraint* spring, cpFloat dist);

//~ const cpConstraintClass* cpDampedSpringGetClass();

/// @private
struct cpDampedSpring
{
    cpConstraint constraint;
    cpVect anchr1, anchr2;
    cpFloat restLength = 0;
    cpFloat stiffness = 0;
    cpFloat damping = 0;
    cpDampedSpringForceFunc springForceFunc;

    cpFloat target_vrn = 0;
    cpFloat v_coef = 0;

    cpVect r1, r2;
    cpFloat nMass = 0;
    cpVect n;

    cpFloat jAcc = 0;
}

mixin CP_DefineConstraintProperty!("cpDampedSpring", cpVect, "anchr1", "Anchr1");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpVect, "anchr2", "Anchr2");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpFloat, "restLength", "RestLength");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpFloat, "stiffness", "Stiffness");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpFloat, "damping", "Damping");
mixin CP_DefineConstraintProperty!("cpDampedSpring", cpDampedSpringForceFunc, "springForceFunc", "SpringForceFunc");


cpFloat defaultSpringForce(cpDampedSpring* spring, cpFloat dist)
{
    return (spring.restLength - dist) * spring.stiffness;
}

void preStep(cpDampedSpring* spring, cpFloat dt)
{
    cpBody* a = spring.constraint.a;
    cpBody* b = spring.constraint.b;

    spring.r1 = cpvrotate(spring.anchr1, a.rot);
    spring.r2 = cpvrotate(spring.anchr2, b.rot);

    cpVect  delta = cpvsub(cpvadd(b.p, spring.r2), cpvadd(a.p, spring.r1));
    cpFloat dist  = cpvlength(delta);
    spring.n = cpvmult(delta, 1.0f / (dist ? dist : INFINITY));

    cpFloat k = k_scalar(a, b, spring.r1, spring.r2, spring.n);
    cpAssertSoft(k != 0.0, "Unsolvable spring.");
    spring.nMass = 1.0f / k;

    spring.target_vrn = 0.0f;
    spring.v_coef     = 1.0f - cpfexp(-spring.damping * dt * k);

    // apply spring force
    cpFloat f_spring = spring.springForceFunc(cast(cpConstraint*)spring, dist);
    cpFloat j_spring = spring.jAcc = f_spring * dt;
    apply_impulses(a, b, spring.r1, spring.r2, cpvmult(spring.n, j_spring));
}

void applyCachedImpulse(cpDampedSpring* spring, cpFloat dt_coef)
{
}

void applyImpulse(cpDampedSpring* spring, cpFloat dt)
{
    cpBody* a = spring.constraint.a;
    cpBody* b = spring.constraint.b;

    cpVect n  = spring.n;
    cpVect r1 = spring.r1;
    cpVect r2 = spring.r2;

    // compute relative velocity
    cpFloat vrn = normal_relative_velocity(a, b, r1, r2, n);

    // compute velocity loss from drag
    cpFloat v_damp = (spring.target_vrn - vrn) * spring.v_coef;
    spring.target_vrn = vrn + v_damp;

    cpFloat j_damp = v_damp * spring.nMass;
    spring.jAcc += j_damp;
    apply_impulses(a, b, spring.r1, spring.r2, cpvmult(spring.n, j_damp));
}

cpFloat getImpulse(cpDampedSpring* spring)
{
    return spring.jAcc;
}

__gshared cpConstraintClass klass;

void _initModuleCtor_cpDampedSpring()
{
    klass = cpConstraintClass(
        cast(cpConstraintPreStepImpl)&preStep,
        cast(cpConstraintApplyCachedImpulseImpl)&applyCachedImpulse,
        cast(cpConstraintApplyImpulseImpl)&applyImpulse,
        cast(cpConstraintGetImpulseImpl)&getImpulse,
    );
};

const(cpConstraintClass *) cpDampedSpringGetClass()
{
    return cast(cpConstraintClass*)&klass;
}

cpDampedSpring *
cpDampedSpringAlloc()
{
    return cast(cpDampedSpring*)cpcalloc(1, cpDampedSpring.sizeof);
}

cpDampedSpring* cpDampedSpringInit(cpDampedSpring* spring, cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2, cpFloat restLength, cpFloat stiffness, cpFloat damping)
{
    cpConstraintInit(cast(cpConstraint*)spring, cpDampedSpringGetClass(), a, b);

    spring.anchr1 = anchr1;
    spring.anchr2 = anchr2;

    spring.restLength      = restLength;
    spring.stiffness       = stiffness;
    spring.damping         = damping;
    spring.springForceFunc = cast(cpDampedSpringForceFunc)&defaultSpringForce;

    spring.jAcc = 0.0f;

    return spring;
}

cpConstraint* cpDampedSpringNew(cpBody* a, cpBody* b, cpVect anchr1, cpVect anchr2, cpFloat restLength, cpFloat stiffness, cpFloat damping)
{
    return cast(cpConstraint*)cpDampedSpringInit(cpDampedSpringAlloc(), a, b, anchr1, anchr2, restLength, stiffness, damping);
}
