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
module dchip.body_;

import std.string;

import dchip.arbiter;
import dchip.constraint;
import dchip.shape;
import dchip.space;
import dchip.types;
import dchip.vector;

/// Chipmunk's rigid body type. Rigid bodies hold the physical properties of an object like
/// it's mass, and position and velocity of it's center of gravity. They don't have an shape on their own.
/// They are given a shape by creating collision shapes (cpShape) that point to the body.

/// Rigid body velocity update function type.
alias cpBodyVelocityFunc = void function(cpBody* bdy, cpVect gravity, cpFloat damping, cpFloat dt);

/// Rigid body position update function type.
alias cpBodyPositionFunc = void function(cpBody* bdy, cpFloat dt);

/// Used internally to track information on the collision graph.
/// @private
struct cpComponentNode
{
    cpBody* root;
    cpBody* next;
    cpFloat idleTime;
}

/// Chipmunk's rigid body struct.
struct cpBody
{
    /// Function that is called to integrate the body's velocity. (Defaults to cpBodyUpdateVelocity)
    cpBodyVelocityFunc velocity_func;

    /// Function that is called to integrate the body's position. (Defaults to cpBodyUpdatePosition)
    cpBodyPositionFunc position_func;

    /// Mass of the body.
    /// Must agree with cpBody.m_inv! Use cpBodySetMass() when changing the mass for this reason.
    cpFloat m;

    /// Mass inverse.
    cpFloat m_inv;

    /// Moment of inertia of the body.
    /// Must agree with cpBody.i_inv! Use cpBodySetMoment() when changing the moment for this reason.
    cpFloat i;

    /// Moment of inertia inverse.
    cpFloat i_inv;

    /// Position of the rigid body's center of gravity.
    cpVect p;

    /// Velocity of the rigid body's center of gravity.
    cpVect v;

    /// Force acting on the rigid body's center of gravity.
    cpVect f;

    /// Rotation of the body around it's center of gravity in radians.
    /// Must agree with cpBody.rot! Use cpBodySetAngle() when changing the angle for this reason.
    cpFloat a;

    /// Angular velocity of the body around it's center of gravity in radians/second.
    cpFloat w;

    /// Torque applied to the body around it's center of gravity.
    cpFloat t;

    /// Cached unit length vector representing the angle of the body.
    /// Used for fast rotations using cpvrotate().
    cpVect rot;

    /// User definable data pointer.
    /// Generally this points to your the game object class so you can access it
    /// when given a cpBody reference in a callback.
    cpDataPointer data;

    /// Maximum velocity allowed when updating the velocity.
    cpFloat v_limit;

    /// Maximum rotational rate (in radians/second) allowed when updating the angular velocity.
    cpFloat w_limit;

    //~ version (CHIP_ALLOW_PRIVATE_ACCESS)
        //~ cpVect v_bias;
    //~ else
        //~ package cpVect v_bias;

    //~ version (CHIP_ALLOW_PRIVATE_ACCESS)
        //~ cpFloat w_bias;
    //~ else
        //~ package cpFloat w_bias;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpSpace * space;
    else
        package cpSpace * space;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpShape * shapeList;
    else
        package cpShape * shapeList;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArbiter * arbiterList;
    else
        package cpArbiter *arbiterList;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpConstraint * constraintList;
    else
        package cpConstraint * constraintList;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpComponentNode node;
    else
        package cpComponentNode node;
}

/// Allocate a cpBody.
cpBody* cpBodyAlloc();

/// Initialize a cpBody.
cpBody* cpBodyInit(cpBody* bdy, cpFloat m, cpFloat i);

/// Allocate and initialize a cpBody.
cpBody* cpBodyNew(cpFloat m, cpFloat i);

/// Initialize a static cpBody.
cpBody* cpBodyInitStatic(cpBody* bdy);

/// Allocate and initialize a static cpBody.
cpBody* cpBodyNewStatic();

/// Destroy a cpBody.
void cpBodyDestroy(cpBody* bdy);

/// Destroy and free a cpBody.
void cpBodyFree(cpBody* bdy);

/// Check that the properties of a body is sane.
version (CHIP_ENABLE_CHECKS)
{
    void cpBodyAssertSane(T)(T bdy)
    {
        cpBodySanityCheck(bdy);
    }
}
else
{
    void cpBodyAssertSane(T)(T bdy) { }
}

// Defined in cpSpace.c
/// Wake up a sleeping or idle body.
void cpBodyActivate(cpBody* bdy);

/// Wake up any sleeping or idle bodies touching a static body.
void cpBodyActivateStatic(cpBody* bdy, cpShape* filter);

/// Force a body to fall asleep immediately.
void cpBodySleep(cpBody* bdy);

/// Force a body to fall asleep immediately along with other bodies in a group.
void cpBodySleepWithGroup(cpBody* bdy, cpBody* group);

/// Returns true if the body is sleeping.
cpBool cpBodyIsSleeping(const cpBody* bdy)
{
    return (bdy.node.root != (cast(cpBody*)null));
}

/// Returns true if the body is static.
cpBool cpBodyIsStatic(const cpBody* bdy)
{
    return bdy.node.idleTime == INFINITY;
}

/// Returns true if the body has not been added to a space.
/// Note: Static bodies are a subtype of rogue bodies.
cpBool cpBodyIsRogue(const cpBody* bdy)
{
    return (bdy.space == (cast(cpSpace*)null));
}

mixin template CP_DefineBodyStructGetter(type, string member, string name)
{
    mixin(q{
        type cpBodyGet%s(const cpBody * bdy) { return cast(typeof(return))bdy.%s; }
    }.format(name, member));
}

mixin template CP_DefineBodyStructSetter(type, string member, string name)
{
    mixin(q{
        void cpBodySet%s(cpBody * bdy, const type value)
        {
            cpBodyActivate(bdy);
            bdy.%s = cast(typeof(bdy.%s))value;
            cpBodyAssertSane(bdy);
        }
    }.format(name, member, member));
}

mixin template CP_DefineBodyStructProperty(type, string member, string name)
{
    mixin CP_DefineBodyStructGetter!(type, member, name);
    mixin CP_DefineBodyStructSetter!(type, member, name);
}

// TODO add to docs
mixin CP_DefineBodyStructGetter!(cpSpace*, "space", "Space");

mixin CP_DefineBodyStructGetter!(cpFloat, "m", "Mass");

/// Set the mass of a body.
void cpBodySetMass(cpBody* bdy, cpFloat m);

mixin CP_DefineBodyStructGetter!(cpFloat, "i", "Moment");

/// Set the moment of a body.
void cpBodySetMoment(cpBody* bdy, cpFloat i);

mixin CP_DefineBodyStructGetter!(cpVect, "p", "Pos");

/// Set the position of a body.
void cpBodySetPos(cpBody* bdy, cpVect pos);
mixin CP_DefineBodyStructProperty!(cpVect, "v", "Vel");
mixin CP_DefineBodyStructProperty!(cpVect, "f", "Force");
mixin CP_DefineBodyStructGetter!(cpFloat, "a", "Angle");

/// Set the angle of a body.
void cpBodySetAngle(cpBody* bdy, cpFloat a);
mixin CP_DefineBodyStructProperty!(cpFloat, "w", "AngVel");
mixin CP_DefineBodyStructProperty!(cpFloat, "t", "Torque");
mixin CP_DefineBodyStructGetter!(cpVect, "rot", "Rot");
mixin CP_DefineBodyStructProperty!(cpFloat, "v_limit", "VelLimit");
mixin CP_DefineBodyStructProperty!(cpFloat, "w_limit", "AngVelLimit");
mixin CP_DefineBodyStructProperty!(cpDataPointer, "data", "UserData");

/// Default Integration functions.
void cpBodyUpdateVelocity(cpBody* bdy, cpVect gravity, cpFloat damping, cpFloat dt);
void cpBodyUpdatePosition(cpBody* bdy, cpFloat dt);

/// Convert body relative/local coordinates to absolute/world coordinates.
cpVect cpBodyLocal2World(const cpBody* bdy, const cpVect v)
{
    return cpvadd(bdy.p, cpvrotate(v, bdy.rot));
}

/// Convert body absolute/world coordinates to  relative/local coordinates.
cpVect cpBodyWorld2Local(const cpBody* bdy, const cpVect v)
{
    return cpvunrotate(cpvsub(v, bdy.p), bdy.rot);
}

/// Set the forces and torque or a body to zero.
void cpBodyResetForces(cpBody* bdy);

/// Apply an force (in world coordinates) to the body at a point relative to the center of gravity (also in world coordinates).
void cpBodyApplyForce(cpBody* bdy, const cpVect f, const cpVect r);

/// Apply an impulse (in world coordinates) to the body at a point relative to the center of gravity (also in world coordinates).
void cpBodyApplyImpulse(cpBody* bdy, const cpVect j, const cpVect r);

/// Get the velocity on a body (in world units) at a point on the body in world coordinates.
cpVect cpBodyGetVelAtWorldPoint(cpBody* bdy, cpVect point);

/// Get the velocity on a body (in world units) at a point on the body in local coordinates.
cpVect cpBodyGetVelAtLocalPoint(cpBody* bdy, cpVect point);

/// Get the kinetic energy of a body.
cpFloat cpBodyKineticEnergy(const cpBody* bdy)
{
    // Need to do some fudging to avoid NaNs
    cpFloat vsq = cpvdot(bdy.v, bdy.v);
    cpFloat wsq = bdy.w * bdy.w;
    return (vsq ? vsq * bdy.m : 0.0f) + (wsq ? wsq * bdy.i : 0.0f);
}

/// Body/shape iterator callback function type.
alias cpBodyShapeIteratorFunc= void function(cpBody* bdy, cpShape* shape, void* data);

/// Call @c func once for each shape attached to @c body and added to the space.
void cpBodyEachShape(cpBody* bdy, cpBodyShapeIteratorFunc func, void* data);

/// Body/constraint iterator callback function type.
alias cpBodyConstraintIteratorFunc= void function(cpBody* bdy, cpConstraint* constraint, void* data);

/// Call @c func once for each constraint attached to @c body and added to the space.
void cpBodyEachConstraint(cpBody* bdy, cpBodyConstraintIteratorFunc func, void* data);

/// Body/arbiter iterator callback function type.
alias cpBodyArbiterIteratorFunc = void function(cpBody* bdy, cpArbiter* arbiter, void* data);

/// Call @c func once for each arbiter that is currently active on the body.
void cpBodyEachArbiter(cpBody* bdy, cpBodyArbiterIteratorFunc func, void* data);
