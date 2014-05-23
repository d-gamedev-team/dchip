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
module dchip.cpBody;

import std.string;

import dchip.chipmunk;
import dchip.chipmunk_private;
import dchip.chipmunk_types;
import dchip.constraints_util;
import dchip.cpArray;
import dchip.cpArbiter;
import dchip.cpConstraint;
import dchip.cpShape;
import dchip.cpSpace;
import dchip.cpSpaceComponent;
import dchip.cpVect;

/// Chipmunk's rigid body_ type. Rigid bodies hold the physical properties of an object like
/// it's mass, and position and velocity of it's center of gravity. They don't have an shape on their own.
/// They are given a shape by creating collision shapes (cpShape) that point to the body_.

/// Rigid body_ velocity update function type.
alias cpBodyVelocityFunc = void function(cpBody* bdy, cpVect gravity, cpFloat damping, cpFloat dt);

/// Rigid body_ position update function type.
alias cpBodyPositionFunc = void function(cpBody* bdy, cpFloat dt);

/// Used internally to track information on the collision graph.
/// @private
struct cpComponentNode
{
    cpBody* root;
    cpBody* next;
    cpFloat idleTime = 0;
}

/// Chipmunk's rigid body_ struct.
struct cpBody
{
    /// Function that is called to integrate the body_'s velocity. (Defaults to cpBodyUpdateVelocity)
    cpBodyVelocityFunc velocity_func;

    /// Function that is called to integrate the body_'s position. (Defaults to cpBodyUpdatePosition)
    cpBodyPositionFunc position_func;

    /// Mass of the body_.
    /// Must agree with cpBody.m_inv! Use cpBodySetMass() when changing the mass for this reason.
    cpFloat m = 0;

    /// Mass inverse.
    cpFloat m_inv = 0;

    /// Moment of inertia of the body_.
    /// Must agree with cpBody.i_inv! Use cpBodySetMoment() when changing the moment for this reason.
    cpFloat i = 0;

    /// Moment of inertia inverse.
    cpFloat i_inv = 0;

    /// Position of the rigid body_'s center of gravity.
    cpVect p;

    /// Velocity of the rigid body_'s center of gravity.
    cpVect v;

    /// Force acting on the rigid body_'s center of gravity.
    cpVect f;

    /// Rotation of the body_ around it's center of gravity in radians.
    /// Must agree with cpBody.rot! Use cpBodySetAngle() when changing the angle for this reason.
    cpFloat a = 0;

    /// Angular velocity of the body_ around it's center of gravity in radians/second.
    cpFloat w = 0;

    /// Torque applied to the body_ around it's center of gravity.
    cpFloat t = 0;

    /// Cached unit length vector representing the angle of the body_.
    /// Used for fast rotations using cpvrotate().
    cpVect rot;

    /// User definable data pointer.
    /// Generally this points to your the game object class so you can access it
    /// when given a cpBody reference in a callback.
    cpDataPointer data;

    /// Maximum velocity allowed when updating the velocity.
    cpFloat v_limit = 0;

    /// Maximum rotational rate (in radians/second) allowed when updating the angular velocity.
    cpFloat w_limit = 0;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpVect v_bias;
    else
        package cpVect v_bias;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpFloat w_bias = 0;
    else
        package cpFloat w_bias = 0;

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

/// Check that the properties of a body_ is sane.
version (CHIP_ENABLE_WARNINGS)
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
/// Wake up a sleeping or idle body_.
void cpBodyActivate(cpBody* body_)
{
    if (!cpBodyIsRogue(body_))
    {
        body_.node.idleTime = 0.0f;
        ComponentActivate(ComponentRoot(body_));
    }

    mixin(CP_BODY_FOREACH_ARBITER!("body_", "arb", q{
        // Reset the idle timer of things the body_ is touching as well.
        // That way things don't get left hanging in the air.
        cpBody* other = (arb.body_a == body_ ? arb.body_b : arb.body_a);

        if (!cpBodyIsStatic(other))
            other.node.idleTime = 0.0f;
    }));
}

/// Wake up any sleeping or idle bodies touching a static body_.
void cpBodyActivateStatic(cpBody* body_, cpShape* filter)
{
    cpAssertHard(cpBodyIsStatic(body_), "cpBodyActivateStatic() called on a non-static body_.");

    mixin(CP_BODY_FOREACH_ARBITER!("body_", "arb", q{
        if (!filter || filter == arb.a || filter == arb.b)
        {
            cpBodyActivate(arb.body_a == body_ ? arb.body_b : arb.body_a);
        }
    }));

    // TODO should also activate joints?
}

/// Force a body_ to fall asleep immediately.
void cpBodySleep(cpBody* body_)
{
    cpBodySleepWithGroup(body_, null);
}

/// Force a body_ to fall asleep immediately along with other bodies in a group.
void cpBodySleepWithGroup(cpBody* body_, cpBody* group)
{
    cpAssertHard(!cpBodyIsRogue(body_), "Rogue (and static) bodies cannot be put to sleep.");

    cpSpace* space = body_.space;
    cpAssertHard(!space.locked, "Bodies cannot be put to sleep during a query or a call to cpSpaceStep(). Put these calls into a post-step callback.");
    cpAssertHard(group == null || cpBodyIsSleeping(group), "Cannot use a non-sleeping body_ as a group identifier.");

    if (cpBodyIsSleeping(body_))
    {
        cpAssertHard(ComponentRoot(body_) == ComponentRoot(group), "The body_ is already sleeping and it's group cannot be reassigned.");
        return;
    }

    mixin(CP_BODY_FOREACH_SHAPE!("body_", "shape", "cpShapeUpdate(shape, body_.p, body_.rot);"));
    cpSpaceDeactivateBody(space, body_);

    if (group)
    {
        cpBody* root = ComponentRoot(group);

        cpComponentNode node = { root, root.node.next, 0.0f };
        body_.node = node;

        root.node.next = body_;
    }
    else
    {
        cpComponentNode node = { body_, null, 0.0f };
        body_.node = node;

        cpArrayPush(space.sleepingComponents, body_);
    }

    cpArrayDeleteObj(space.bodies, body_);
}

/// Returns true if the body_ is sleeping.
cpBool cpBodyIsSleeping(const cpBody* bdy)
{
    return (bdy.node.root != (cast(cpBody*)null));
}

/// Returns true if the body_ is static.
cpBool cpBodyIsStatic(const cpBody* bdy)
{
    return bdy.node.idleTime == INFINITY;
}

/// Returns true if the body_ has not been added to a space.
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

mixin CP_DefineBodyStructGetter!(cpFloat, "i", "Moment");

mixin CP_DefineBodyStructGetter!(cpVect, "p", "Pos");

mixin CP_DefineBodyStructProperty!(cpVect, "v", "Vel");
mixin CP_DefineBodyStructProperty!(cpVect, "f", "Force");
mixin CP_DefineBodyStructGetter!(cpFloat, "a", "Angle");

mixin CP_DefineBodyStructProperty!(cpFloat, "w", "AngVel");
mixin CP_DefineBodyStructProperty!(cpFloat, "t", "Torque");
mixin CP_DefineBodyStructGetter!(cpVect, "rot", "Rot");
mixin CP_DefineBodyStructProperty!(cpFloat, "v_limit", "VelLimit");
mixin CP_DefineBodyStructProperty!(cpFloat, "w_limit", "AngVelLimit");
mixin CP_DefineBodyStructProperty!(cpDataPointer, "data", "UserData");

/// Convert body_ relative/local coordinates to absolute/world coordinates.
cpVect cpBodyLocal2World(const cpBody* bdy, const cpVect v)
{
    return cpvadd(bdy.p, cpvrotate(v, bdy.rot));
}

/// Convert body_ absolute/world coordinates to  relative/local coordinates.
cpVect cpBodyWorld2Local(const cpBody* bdy, const cpVect v)
{
    return cpvunrotate(cpvsub(v, bdy.p), bdy.rot);
}

/// Get the kinetic energy of a body_.
cpFloat cpBodyKineticEnergy(const cpBody* bdy)
{
    // Need to do some fudging to avoid NaNs
    cpFloat vsq = cpvdot(bdy.v, bdy.v);
    cpFloat wsq = bdy.w * bdy.w;
    return (vsq ? vsq * bdy.m : 0.0f) + (wsq ? wsq * bdy.i : 0.0f);
}

/// Body/shape iterator callback function type.
alias cpBodyShapeIteratorFunc= void function(cpBody* bdy, cpShape* shape, void* data);

/// Body/constraint iterator callback function type.
alias cpBodyConstraintIteratorFunc= void function(cpBody* bdy, cpConstraint* constraint, void* data);

/// Body/arbiter iterator callback function type.
alias cpBodyArbiterIteratorFunc = void function(cpBody* bdy, cpArbiter* arbiter, void* data);

// initialized in cpInitChipmunk()
__gshared cpBody cpStaticBodySingleton;

cpBody* cpBodyAlloc()
{
    return cast(cpBody*)cpcalloc(1, cpBody.sizeof);
}

cpBody* cpBodyInit(cpBody* body_, cpFloat m, cpFloat i)
{
    body_.space          = null;
    body_.shapeList      = null;
    body_.arbiterList    = null;
    body_.constraintList = null;

    body_.velocity_func = &cpBodyUpdateVelocity;
    body_.position_func = &cpBodyUpdatePosition;

    cpComponentNode node = { null, null, 0.0f };
    body_.node = node;

    body_.p = cpvzero;
    body_.v = cpvzero;
    body_.f = cpvzero;

    body_.w = 0.0f;
    body_.t = 0.0f;

    body_.v_bias = cpvzero;
    body_.w_bias = 0.0f;

    body_.v_limit = cast(cpFloat)INFINITY;
    body_.w_limit = cast(cpFloat)INFINITY;

    body_.data = null;

    // Setters must be called after full initialization so the sanity checks don't assert on garbage data.
    cpBodySetMass(body_, m);
    cpBodySetMoment(body_, i);
    cpBodySetAngle(body_, 0.0f);

    return body_;
}

cpBody* cpBodyNew(cpFloat m, cpFloat i)
{
    return cpBodyInit(cpBodyAlloc(), m, i);
}

cpBody* cpBodyInitStatic(cpBody* body_)
{
    cpBodyInit(body_, cast(cpFloat)INFINITY, cast(cpFloat)INFINITY);
    body_.node.idleTime = cast(cpFloat)INFINITY;

    return body_;
}

cpBody* cpBodyNewStatic()
{
    return cpBodyInitStatic(cpBodyAlloc());
}

void cpBodyDestroy(cpBody* body_)
{
}

extern(C) void cpBodyFreeVoid(void* body_)
{
    cpBodyFree(cast(cpBody*)body_);
}

void cpBodyFree(cpBody* body_)
{
    if (body_)
    {
        cpBodyDestroy(body_);
        cpfree(body_);
    }
}

void cpv_assert_nan(cpVect v, string message)
{
    cpAssertSoft(v.x == v.x && v.y == v.y, message);
}

void cpv_assert_infinite(cpVect v, string message)
{
    cpAssertSoft(cpfabs(v.x) != INFINITY && cpfabs(v.y) != INFINITY, message);
}

void cpv_assert_sane(cpVect v, string message)
{
    cpv_assert_nan(v, message);
    cpv_assert_infinite(v, message);
}

void cpBodySanityCheck(cpBody* body_)
{
    cpAssertSoft(body_.m == body_.m && body_.m_inv == body_.m_inv, "Body's mass is invalid.");
    cpAssertSoft(body_.i == body_.i && body_.i_inv == body_.i_inv, "Body's moment is invalid.");

    cpv_assert_sane(body_.p, "Body's position is invalid.");
    cpv_assert_sane(body_.v, "Body's velocity is invalid.");
    cpv_assert_sane(body_.f, "Body's force is invalid.");

    cpAssertSoft(body_.a == body_.a && cpfabs(body_.a) != INFINITY, "Body's angle is invalid.");
    cpAssertSoft(body_.w == body_.w && cpfabs(body_.w) != INFINITY, "Body's angular velocity is invalid.");
    cpAssertSoft(body_.t == body_.t && cpfabs(body_.t) != INFINITY, "Body's torque is invalid.");

    cpv_assert_sane(body_.rot, "Body's rotation vector is invalid.");

    cpAssertSoft(body_.v_limit == body_.v_limit, "Body's velocity limit is invalid.");
    cpAssertSoft(body_.w_limit == body_.w_limit, "Body's angular velocity limit is invalid.");
}

void cpBodySetMass(cpBody* body_, cpFloat mass)
{
    cpAssertHard(mass > 0.0f, "Mass must be positive and non-zero.");

    cpBodyActivate(body_);
    body_.m     = mass;
    body_.m_inv = 1.0f / mass;
    cpBodyAssertSane(body_);
}

void cpBodySetMoment(cpBody* body_, cpFloat moment)
{
    cpAssertHard(moment > 0.0f, "Moment of Inertia must be positive and non-zero.");

    cpBodyActivate(body_);
    body_.i     = moment;
    body_.i_inv = 1.0f / moment;
    cpBodyAssertSane(body_);
}

void cpBodyAddShape(cpBody* body_, cpShape* shape)
{
    cpShape* next = body_.shapeList;

    if (next)
        next.prev = shape;

    shape.next     = next;
    body_.shapeList = shape;
}

void cpBodyRemoveShape(cpBody* body_, cpShape* shape)
{
    cpShape* prev = shape.prev;
    cpShape* next = shape.next;

    if (prev)
    {
        prev.next = next;
    }
    else
    {
        body_.shapeList = next;
    }

    if (next)
    {
        next.prev = prev;
    }

    shape.prev = null;
    shape.next = null;
}

cpConstraint* filterConstraints(cpConstraint* node, cpBody* body_, cpConstraint* filter)
{
    if (node == filter)
    {
        return cpConstraintNext(node, body_);
    }
    else if (node.a == body_)
    {
        node.next_a = filterConstraints(node.next_a, body_, filter);
    }
    else
    {
        node.next_b = filterConstraints(node.next_b, body_, filter);
    }

    return node;
}

void cpBodyRemoveConstraint(cpBody* body_, cpConstraint* constraint)
{
    body_.constraintList = filterConstraints(body_.constraintList, body_, constraint);
}

void cpBodySetPos(cpBody* body_, cpVect pos)
{
    cpBodyActivate(body_);
    body_.p = pos;
    cpBodyAssertSane(body_);
}

void setAngle(cpBody* body_, cpFloat angle)
{
    body_.a   = angle;  //fmod(a, (cpFloat)M_PI*2.0f);
    body_.rot = cpvforangle(angle);
    cpBodyAssertSane(body_);
}

void cpBodySetAngle(cpBody* body_, cpFloat angle)
{
    cpBodyActivate(body_);
    setAngle(body_, angle);
}

void cpBodyUpdateVelocity(cpBody* body_, cpVect gravity, cpFloat damping, cpFloat dt)
{
    body_.v = cpvclamp(cpvadd(cpvmult(body_.v, damping), cpvmult(cpvadd(gravity, cpvmult(body_.f, body_.m_inv)), dt)), body_.v_limit);

    cpFloat w_limit = body_.w_limit;
    body_.w = cpfclamp(body_.w * damping + body_.t * body_.i_inv * dt, -w_limit, w_limit);

    cpBodySanityCheck(body_);
}

void cpBodyUpdatePosition(cpBody* body_, cpFloat dt)
{
    body_.p = cpvadd(body_.p, cpvmult(cpvadd(body_.v, body_.v_bias), dt));
    setAngle(body_, body_.a + (body_.w + body_.w_bias) * dt);

    body_.v_bias = cpvzero;
    body_.w_bias = 0.0f;

    cpBodySanityCheck(body_);
}

void cpBodyResetForces(cpBody* body_)
{
    cpBodyActivate(body_);
    body_.f = cpvzero;
    body_.t = 0.0f;
}

void cpBodyApplyForce(cpBody* body_, cpVect force, cpVect r)
{
    cpBodyActivate(body_);
    body_.f  = cpvadd(body_.f, force);
    body_.t += cpvcross(r, force);
}

void cpBodyApplyImpulse(cpBody* body_, const cpVect j, const cpVect r)
{
    cpBodyActivate(body_);
    apply_impulse(body_, j, r);
}

cpVect cpBodyGetVelAtPoint(cpBody* body_, cpVect r)
{
    return cpvadd(body_.v, cpvmult(cpvperp(r), body_.w));
}

cpVect cpBodyGetVelAtWorldPoint(cpBody* body_, cpVect point)
{
    return cpBodyGetVelAtPoint(body_, cpvsub(point, body_.p));
}

cpVect cpBodyGetVelAtLocalPoint(cpBody* body_, cpVect point)
{
    return cpBodyGetVelAtPoint(body_, cpvrotate(point, body_.rot));
}

void cpBodyEachShape(cpBody* body_, cpBodyShapeIteratorFunc func, void* data)
{
    cpShape* shape = body_.shapeList;

    while (shape)
    {
        cpShape* next = shape.next;
        func(body_, shape, data);
        shape = next;
    }
}

void cpBodyEachConstraint(cpBody* body_, cpBodyConstraintIteratorFunc func, void* data)
{
    cpConstraint* constraint = body_.constraintList;

    while (constraint)
    {
        cpConstraint* next = cpConstraintNext(constraint, body_);
        func(body_, constraint, data);
        constraint = next;
    }
}

void cpBodyEachArbiter(cpBody* body_, cpBodyArbiterIteratorFunc func, void* data)
{
    cpArbiter* arb = body_.arbiterList;

    while (arb)
    {
        cpArbiter* next = cpArbiterNext(arb, body_);

        arb.swappedColl = (body_ == arb.body_b);
        func(body_, arb, data);

        arb = next;
    }
}

void cpBodyPushArbiter(cpBody* body_, cpArbiter* arb)
{
    cpAssertSoft(cpArbiterThreadForBody(arb, body_).next == null, "Internal Error: Dangling contact graph pointers detected. (A)");
    cpAssertSoft(cpArbiterThreadForBody(arb, body_).prev == null, "Internal Error: Dangling contact graph pointers detected. (B)");

    cpArbiter* next = body_.arbiterList;
    cpAssertSoft(next == null || cpArbiterThreadForBody(next, body_).prev == null, "Internal Error: Dangling contact graph pointers detected. (C)");
    cpArbiterThreadForBody(arb, body_).next = next;

    if (next)
        cpArbiterThreadForBody(next, body_).prev = arb;
    body_.arbiterList = arb;
}

/** Workaround for https://github.com/slembcke/Chipmunk2D/issues/56. */
void cpBodyActivateWrap(cpBody* body_, void* data)
{
    cpBodyActivate(body_);
}
