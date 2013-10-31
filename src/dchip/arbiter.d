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
module dchip.arbiter;

import std.string;

import dchip.body_;
import dchip.chipmunk_private;
import dchip.chipmunk_types;
import dchip.space;
import dchip.spatial_index;
import dchip.shape;
import dchip.util;

/// The cpArbiter struct controls pairs of colliding shapes.
/// They are also used in conjuction with collision handler callbacks
/// allowing you to retrieve information on the collision and control it.

/// Collision begin event function callback type.
/// Returning false from a begin callback causes the collision to be ignored until
/// the the separate callback is called when the objects stop colliding.
alias cpCollisionBeginFunc = cpBool function(cpArbiter* arb, cpSpace* space, void* data);

/// Collision pre-solve event function callback type.
/// Returning false from a pre-step callback causes the collision to be ignored until the next step.
alias cpCollisionPreSolveFunc = cpBool function(cpArbiter* arb, cpSpace* space, void* data);

/// Collision post-solve event function callback type.
alias cpCollisionPostSolveFunc = void function(cpArbiter* arb, cpSpace* space, void* data);

/// Collision separate event function callback type.
alias cpCollisionSeparateFunc = void function(cpArbiter* arb, cpSpace* space, void* data);

/// @private
struct cpCollisionHandler
{
    cpCollisionType a;
    cpCollisionType b;
    cpCollisionBeginFunc begin;
    cpCollisionPreSolveFunc preSolve;
    cpCollisionPostSolveFunc postSolve;
    cpCollisionSeparateFunc separate;
    void* data;
}

enum CP_MAX_CONTACTS_PER_ARBITER = 2;

/// @private
enum cpArbiterState
{
    // Arbiter is active and its the first collision.
    cpArbiterStateFirstColl,

    // Arbiter is active and its not the first collision.
    cpArbiterStateNormal,

    // Collision has been explicitly ignored.
    // Either by returning false from a begin collision handler or calling cpArbiterIgnore().
    cpArbiterStateIgnore,

    // Collison is no longer active. A space will cache an arbiter for up to cpSpace.collisionPersistence more steps.
    cpArbiterStateCached,
}

///
mixin _ExportEnumMembers!cpArbiterState;

/// @private
struct cpArbiterThread
{
    // Links to next and previous arbiters in the contact graph.
    cpArbiter* next;
    cpArbiter* prev;
}

/// A colliding pair of shapes.
struct cpArbiter
{
    /// Calculated value to use for the elasticity coefficient.
    /// Override in a pre-solve collision handler for custom behavior.
    cpFloat e;

    /// Calculated value to use for the friction coefficient.
    /// Override in a pre-solve collision handler for custom behavior.
    cpFloat u;

    /// Calculated value to use for applying surface velocities.
    /// Override in a pre-solve collision handler for custom behavior.
    cpVect surface_vr;

    /// User definable data pointer.
    /// The value will persist for the pair of shapes until the separate() callback is called.
    /// NOTE: If you need to clean up this pointer, you should implement the separate() callback to do it.
    cpDataPointer data;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpShape * a;
    else
        package cpShape * a;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpShape * b;
    else
        package cpShape * b;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpBody * body_a;
    else
        package cpBody * body_a;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpBody * body_b;
    else
        package cpBody * body_b;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArbiterThread thread_a;
    else
        package cpArbiterThread thread_a;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArbiterThread thread_b;
    else
        package cpArbiterThread thread_b;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        int numContacts;
    else
        package int numContacts;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpContact * contacts;
    else
        package cpContact * contacts;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpTimestamp stamp;
    else
        package cpTimestamp stamp;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpCollisionHandler * handler;
    else
        package cpCollisionHandler * handler;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpBool swappedColl;
    else
        package cpBool swappedColl;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArbiterState state;
    else
        package cpArbiterState state;
}

mixin template CP_DefineArbiterStructGetter(type, string member, string name)
{
    mixin(q{
        type cpArbiterGet%s(const cpArbiter * arb) { return cast(typeof(return))arb.%s; }
    }.format(name, member));
}

mixin template CP_DefineArbiterStructSetter(type, string member, string name)
{
    mixin(q{
        void cpArbiterSet%s(cpArbiter * arb, type value) { arb.%s = value; }
    }.format(name, member));
}

mixin template CP_DefineArbiterStructProperty(type, string member, string name)
{
    mixin CP_DefineArbiterStructGetter!(type, member, name);
    mixin CP_DefineArbiterStructSetter!(type, member, name);
}

mixin CP_DefineArbiterStructProperty!(cpFloat, "e", "Elasticity");
mixin CP_DefineArbiterStructProperty!(cpFloat, "u", "Friction");

// Get the relative surface velocity of the two shapes in contact.
cpVect cpArbiterGetSurfaceVelocity(cpArbiter* arb);

// Override the relative surface velocity of the two shapes in contact.
// By default this is calculated to be the difference of the two
// surface velocities clamped to the tangent plane.
void cpArbiterSetSurfaceVelocity(cpArbiter* arb, cpVect vr);

mixin CP_DefineArbiterStructProperty!(cpDataPointer, "data", "UserData");

/// Calculate the total impulse that was applied by this arbiter.
/// This function should only be called from a post-solve, post-step or cpBodyEachArbiter callback.
cpVect cpArbiterTotalImpulse(const cpArbiter* arb);

/// Calculate the total impulse including the friction that was applied by this arbiter.
/// This function should only be called from a post-solve, post-step or cpBodyEachArbiter callback.
cpVect cpArbiterTotalImpulseWithFriction(const cpArbiter* arb);

/// Calculate the amount of energy lost in a collision including static, but not dynamic friction.
/// This function should only be called from a post-solve, post-step or cpBodyEachArbiter callback.
cpFloat cpArbiterTotalKE(const cpArbiter* arb);

/// Causes a collision pair to be ignored as if you returned false from a begin callback.
/// If called from a pre-step callback, you will still need to return false
/// if you want it to be ignored in the current step.
void cpArbiterIgnore(cpArbiter* arb);

/// Return the colliding shapes involved for this arbiter.
/// The order of their cpSpace.collision_type values will match
/// the order set when the collision handler was registered.
void cpArbiterGetShapes(const cpArbiter* arb, cpShape** a, cpShape** b)
{
    if (arb.swappedColl)
    {
        (*a) = cast(typeof(*a))arb.b;
        (*b) = cast(typeof(*a))arb.a;
    }
    else
    {
        (*a) = cast(typeof(*a))arb.a;
        (*b) = cast(typeof(*b))arb.b;
    }
}

/// A macro shortcut for defining and retrieving the shapes from an arbiter.
string CP_ARBITER_GET_SHAPES(string arb, string a, string b)
{
    return q{
        cpShape * %2$s;
        cpShape * %3$s;
        cpArbiterGetShapes(%1$s, &%2$s, &%3$s);
    }.format(arb, a, b);
}

/// Return the colliding bodies involved for this arbiter.
/// The order of the cpSpace.collision_type the bodies are associated with values will match
/// the order set when the collision handler was registered.
void cpArbiterGetBodies(const cpArbiter* arb, cpBody** a, cpBody** b)
{
    mixin(CP_ARBITER_GET_SHAPES("arb", "shape_a", "shape_b"));
    (*a) = shape_a.body_;
    (*b) = shape_b.body_;
}

/// A macro shortcut for defining and retrieving the bodies from an arbiter.
// #define CP_ARBITER_GET_BODIES(__arb__, __a__, __b__) cpBody * __a__, *__b__; cpArbiterGetBodies(__arb__, &__a__, &__b__);

/// A struct that wraps up the important collision data for an arbiter.
struct cpContactPointSet
{
    /// The number of contact points in the set.
    int count;

    /// The array of contact points.
    struct Point
    {
        /// The position of the contact point.
        cpVect point;

        /// The normal of the contact point.
        cpVect normal;

        /// The depth of the contact point.
        cpFloat dist;
    }

    Point[CP_MAX_CONTACTS_PER_ARBITER] points;
}

/// Return a contact set from an arbiter.
cpContactPointSet cpArbiterGetContactPointSet(const cpArbiter* arb);

/// Replace the contact point set for an arbiter.
/// This can be a very powerful feature, but use it with caution!
void cpArbiterSetContactPointSet(cpArbiter* arb, cpContactPointSet* set);

/// Returns true if this is the first step a pair of objects started colliding.
cpBool cpArbiterIsFirstContact(const cpArbiter* arb);

/// Get the number of contact points for this arbiter.
int cpArbiterGetCount(const cpArbiter* arb);

/// Get the normal of the @c ith contact point.
cpVect cpArbiterGetNormal(const cpArbiter* arb, int i);

/// Get the position of the @c ith contact point.
cpVect cpArbiterGetPoint(const cpArbiter* arb, int i);

/// Get the depth of the @c ith contact point.
cpFloat cpArbiterGetDepth(const cpArbiter* arb, int i);
