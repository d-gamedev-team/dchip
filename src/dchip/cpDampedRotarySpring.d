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
module dchip.cpDampedRotarySpring;

import std.string;

import dchip.constraints_util;
import dchip.chipmunk;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.chipmunk_types;

alias cpDampedRotarySpringTorqueFunc = cpFloat function(cpConstraint* spring, cpFloat relativeAngle);

//~ const cpConstraintClass* cpDampedRotarySpringGetClass();

/// @private
struct cpDampedRotarySpring
{
    cpConstraint constraint;
    cpFloat restAngle = 0;
    cpFloat stiffness = 0;
    cpFloat damping = 0;
    cpDampedRotarySpringTorqueFunc springTorqueFunc;

    cpFloat target_wrn = 0;
    cpFloat w_coef = 0;

    cpFloat iSum = 0;
    cpFloat jAcc = 0;
}

/// Allocate a damped rotary spring.
cpDampedRotarySpring* cpDampedRotarySpringAlloc();

/// Initialize a damped rotary spring.
cpDampedRotarySpring* cpDampedRotarySpringInit(cpDampedRotarySpring* joint, cpBody* a, cpBody* b, cpFloat restAngle, cpFloat stiffness, cpFloat damping);

/// Allocate and initialize a damped rotary spring.
cpConstraint* cpDampedRotarySpringNew(cpBody* a, cpBody* b, cpFloat restAngle, cpFloat stiffness, cpFloat damping);

mixin CP_DefineConstraintProperty!("cpDampedRotarySpring", cpFloat, "restAngle", "RestAngle");
mixin CP_DefineConstraintProperty!("cpDampedRotarySpring", cpFloat, "stiffness", "Stiffness");
mixin CP_DefineConstraintProperty!("cpDampedRotarySpring", cpFloat, "damping", "Damping");
mixin CP_DefineConstraintProperty!("cpDampedRotarySpring", cpDampedRotarySpringTorqueFunc, "springTorqueFunc", "SpringTorqueFunc");

cpFloat defaultSpringTorque(cpDampedRotarySpring* spring, cpFloat relativeAngle)
{
    return (relativeAngle - spring.restAngle) * spring.stiffness;
}

void preStep(cpDampedRotarySpring* spring, cpFloat dt)
{
    cpBody* a = spring.constraint.a;
    cpBody* b = spring.constraint.b;

    cpFloat moment = a.i_inv + b.i_inv;
    cpAssertSoft(moment != 0.0, "Unsolvable spring.");
    spring.iSum = 1.0f / moment;

    spring.w_coef     = 1.0f - cpfexp(-spring.damping * dt * moment);
    spring.target_wrn = 0.0f;

    // apply spring torque
    cpFloat j_spring = spring.springTorqueFunc(cast(cpConstraint*)spring, a.a - b.a) * dt;
    spring.jAcc = j_spring;

    a.w -= j_spring * a.i_inv;
    b.w += j_spring * b.i_inv;
}

void applyCachedImpulse(cpDampedRotarySpring* spring, cpFloat dt_coef)
{
}

void applyImpulse(cpDampedRotarySpring* spring, cpFloat dt)
{
    cpBody* a = spring.constraint.a;
    cpBody* b = spring.constraint.b;

    // compute relative velocity
    cpFloat wrn = a.w - b.w;    //normal_relative_velocity(a, b, r1, r2, n) - spring.target_vrn;

    // compute velocity loss from drag
    // not 100% certain this is derived correctly, though it makes sense
    cpFloat w_damp = (spring.target_wrn - wrn) * spring.w_coef;
    spring.target_wrn = wrn + w_damp;

    //apply_impulses(a, b, spring.r1, spring.r2, cpvmult(spring.n, v_damp*spring.nMass));
    cpFloat j_damp = w_damp * spring.iSum;
    spring.jAcc += j_damp;

    a.w += j_damp * a.i_inv;
    b.w -= j_damp * b.i_inv;
}

cpFloat getImpulse(cpDampedRotarySpring* spring)
{
    return spring.jAcc;
}

__gshared cpConstraintClass klass;

void _initModuleCtor_cpDampedRotarySpring()
{
    klass = cpConstraintClass(
        cast(cpConstraintPreStepImpl)&preStep,
        cast(cpConstraintApplyCachedImpulseImpl)&applyCachedImpulse,
        cast(cpConstraintApplyImpulseImpl)&applyImpulse,
        cast(cpConstraintGetImpulseImpl)&getImpulse,
    );
};

const(cpConstraintClass *) cpDampedRotarySpringGetClass()
{
    return cast(cpConstraintClass*)&klass;
}

cpDampedRotarySpring *
cpDampedRotarySpringAlloc()
{
    return cast(cpDampedRotarySpring*)cpcalloc(1, cpDampedRotarySpring.sizeof);
}

cpDampedRotarySpring* cpDampedRotarySpringInit(cpDampedRotarySpring* spring, cpBody* a, cpBody* b, cpFloat restAngle, cpFloat stiffness, cpFloat damping)
{
    cpConstraintInit(cast(cpConstraint*)spring, &klass, a, b);

    spring.restAngle        = restAngle;
    spring.stiffness        = stiffness;
    spring.damping          = damping;
    spring.springTorqueFunc = cast(cpDampedRotarySpringTorqueFunc)&defaultSpringTorque;

    spring.jAcc = 0.0f;

    return spring;
}

cpConstraint* cpDampedRotarySpringNew(cpBody* a, cpBody* b, cpFloat restAngle, cpFloat stiffness, cpFloat damping)
{
    return cast(cpConstraint*)cpDampedRotarySpringInit(cpDampedRotarySpringAlloc(), a, b, restAngle, stiffness, damping);
}
