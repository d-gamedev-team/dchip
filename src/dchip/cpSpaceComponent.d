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
module dchip.cpSpaceComponent;

import core.stdc.string;

import dchip.chipmunk;
import dchip.chipmunk_types;
import dchip.chipmunk_private;
import dchip.cpArray;
import dchip.cpArbiter;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.cpHashSet;
import dchip.cpShape;
import dchip.cpSpace;
import dchip.cpSpaceStep;
import dchip.cpSpaceQuery;
import dchip.cpSpatialIndex;
import dchip.cpVect;
import dchip.util;

void cpSpaceActivateBody(cpSpace* space, cpBody* body_)
{
    cpAssertHard(!cpBodyIsRogue(body_), "Internal error: Attempting to activate a rogue body_.");

    if (space.locked)
    {
        // cpSpaceActivateBody() is called again once the space is unlocked
        if (!cpArrayContains(space.rousedBodies, body_))
            cpArrayPush(space.rousedBodies, body_);
    }
    else
    {
        cpAssertSoft(body_.node.root == null && body_.node.next == null, "Internal error: Activating body_ non-null node pointers.");
        cpArrayPush(space.bodies, body_);

        mixin(CP_BODY_FOREACH_SHAPE!("body_", "shape", q{
            cpSpatialIndexRemove(space.staticShapes, shape, shape.hashid);
            cpSpatialIndexInsert(space.activeShapes, shape, shape.hashid);
        }));

        mixin(CP_BODY_FOREACH_ARBITER!("body_", "arb", q{
            cpBody* bodyA = arb.body_a;

            // Arbiters are shared between two bodies that are always woken up together.
            // You only want to restore the arbiter once, so bodyA is arbitrarily chosen to own the arbiter.
            // The edge case is when static bodies are involved as the static bodies never actually sleep.
            // If the static body_ is bodyB then all is good. If the static body_ is bodyA, that can easily be checked.
            if (body_ == bodyA || cpBodyIsStatic(bodyA))
            {
                int numContacts     = arb.numContacts;
                cpContact* contacts = arb.contacts;

                // Restore contact values back to the space's contact buffer memory
                arb.contacts = cpContactBufferGetArray(space);
                memcpy(arb.contacts, contacts, numContacts * cpContact.sizeof);
                cpSpacePushContacts(space, numContacts);

                // Reinsert the arbiter into the arbiter cache
                cpShape* a = arb.a;
                cpShape* b = arb.b;
                cpShape*[2] shape_pair;
                shape_pair[0] = a;
                shape_pair[1] = b;
                cpHashValue arbHashID = CP_HASH_PAIR(cast(cpHashValue)a, cast(cpHashValue)b);
                cpHashSetInsert(space.cachedArbiters, arbHashID, shape_pair.ptr, arb, null);

                // Update the arbiter's state
                arb.stamp   = space.stamp;
                arb.handler = cpSpaceLookupHandler(space, a.collision_type, b.collision_type);
                cpArrayPush(space.arbiters, arb);

                cpfree(contacts);
            }
        }));

        mixin(CP_BODY_FOREACH_CONSTRAINT!("body_", "constraint", q{
            cpBody* bodyA = constraint.a;

            if (body_ == bodyA || cpBodyIsStatic(bodyA))
                cpArrayPush(space.constraints, constraint);
        }));
    }
}

void cpSpaceDeactivateBody(cpSpace* space, cpBody* body_)
{
    cpAssertHard(!cpBodyIsRogue(body_), "Internal error: Attempting to deactivate a rouge body_.");

    cpArrayDeleteObj(space.bodies, body_);

    mixin(CP_BODY_FOREACH_SHAPE!("body_", "shape", q{
        cpSpatialIndexRemove(space.activeShapes, shape, shape.hashid);
        cpSpatialIndexInsert(space.staticShapes, shape, shape.hashid);
    }));

    mixin(CP_BODY_FOREACH_ARBITER!("body_", "arb", q{
        cpBody* bodyA = arb.body_a;

        if (body_ == bodyA || cpBodyIsStatic(bodyA))
        {
            cpSpaceUncacheArbiter(space, arb);

            // Save contact values to a new block of memory so they won't time out
            size_t bytes        = arb.numContacts * cpContact.sizeof;
            cpContact* contacts = cast(cpContact*)cpcalloc(1, bytes);
            memcpy(contacts, arb.contacts, bytes);
            arb.contacts = contacts;
        }
    }));

    mixin(CP_BODY_FOREACH_CONSTRAINT!("body_", "constraint", q{
        cpBody* bodyA = constraint.a;

        if (body_ == bodyA || cpBodyIsStatic(bodyA))
            cpArrayDeleteObj(space.constraints, constraint);
    }));
}

cpBody* ComponentRoot(cpBody* body_)
{
    return (body_ ? body_.node.root : null);
}

void ComponentActivate(cpBody* root)
{
    if (!root || !cpBodyIsSleeping(root))
        return;
    cpAssertHard(!cpBodyIsRogue(root), "Internal Error: ComponentActivate() called on a rogue body_.");

    cpSpace* space = root.space;
    cpBody * body_  = root;

    while (body_)
    {
        cpBody* next = body_.node.next;

        body_.node.idleTime = 0.0f;
        body_.node.root     = null;
        body_.node.next     = null;
        cpSpaceActivateBody(space, body_);

        body_ = next;
    }

    cpArrayDeleteObj(space.sleepingComponents, root);
}

void ComponentAdd(cpBody* root, cpBody* body_)
{
    body_.node.root = root;

    if (body_ != root)
    {
        body_.node.next = root.node.next;
        root.node.next = body_;
    }
}

void FloodFillComponent(cpBody* root, cpBody* body_)
{
    // Rogue bodies cannot be put to sleep and prevent bodies they are touching from sleepining anyway.
    // Static bodies (which are a type of rogue body_) are effectively sleeping all the time.
    if (!cpBodyIsRogue(body_))
    {
        cpBody* other_root = ComponentRoot(body_);

        if (other_root == null)
        {
            ComponentAdd(root, body_);
            mixin(CP_BODY_FOREACH_ARBITER!("body_", "arb", "FloodFillComponent(root, (body_ == arb.body_a ? arb.body_b : arb.body_a));"));
            mixin(CP_BODY_FOREACH_CONSTRAINT!("body_", "constraint", "FloodFillComponent(root, (body_ == constraint.a ? constraint.b : constraint.a));"));
        }
        else
        {
            cpAssertSoft(other_root == root, "Internal Error: Inconsistency dectected in the contact graph.");
        }
    }
}

cpBool ComponentActive(cpBody* root, cpFloat threshold)
{
    mixin(CP_BODY_FOREACH_COMPONENT!("root", "body_", q{
        if (body_.node.idleTime < threshold)
            return cpTrue;
    }));

    return cpFalse;
}

void cpSpaceProcessComponents(cpSpace* space, cpFloat dt)
{
    cpBool sleep    = (space.sleepTimeThreshold != INFINITY);
    cpArray* bodies = space.bodies;

    version (CHIP_ENABLE_WARNINGS)
    {
        for (int i = 0; i < bodies.num; i++)
        {
            cpBody* body_ = cast(cpBody*)bodies.arr[i];

            cpAssertSoft(body_.node.next == null, "Internal Error: Dangling next pointer detected in contact graph.");
            cpAssertSoft(body_.node.root == null, "Internal Error: Dangling root pointer detected in contact graph.");
        }
    }

    // Calculate the kinetic energy of all the bodies.
    if (sleep)
    {
        cpFloat dv   = space.idleSpeedThreshold;
        cpFloat dvsq = (dv ? dv * dv : cpvlengthsq(space.gravity) * dt * dt);

        // update idling and reset component nodes
        for (int i = 0; i < bodies.num; i++)
        {
            cpBody* body_ = cast(cpBody*)bodies.arr[i];

            // Need to deal with infinite mass objects
            cpFloat keThreshold = (dvsq ? body_.m * dvsq : 0.0f);
            body_.node.idleTime = (cpBodyKineticEnergy(body_) > keThreshold ? 0.0f : body_.node.idleTime + dt);
        }
    }

    // Awaken any sleeping bodies found and then push arbiters to the bodies' lists.
    cpArray* arbiters = space.arbiters;

    for (int i = 0, count = arbiters.num; i < count; i++)
    {
        cpArbiter* arb = cast(cpArbiter*)arbiters.arr[i];
        cpBody* a      = arb.body_a;
        cpBody* b      = arb.body_b;

        if (sleep)
        {
            if ((cpBodyIsRogue(b) && !cpBodyIsStatic(b)) || cpBodyIsSleeping(a))
                cpBodyActivate(a);

            if ((cpBodyIsRogue(a) && !cpBodyIsStatic(a)) || cpBodyIsSleeping(b))
                cpBodyActivate(b);
        }

        cpBodyPushArbiter(a, arb);
        cpBodyPushArbiter(b, arb);
    }

    if (sleep)
    {
        // Bodies should be held active if connected by a joint to a non-static rouge body_.
        cpArray* constraints = space.constraints;

        for (int i = 0; i < constraints.num; i++)
        {
            cpConstraint* constraint = cast(cpConstraint*)constraints.arr[i];
            cpBody* a = constraint.a;
            cpBody* b = constraint.b;

            if (cpBodyIsRogue(b) && !cpBodyIsStatic(b))
                cpBodyActivate(a);

            if (cpBodyIsRogue(a) && !cpBodyIsStatic(a))
                cpBodyActivate(b);
        }

        // Generate components and deactivate sleeping ones
        for (int i = 0; i < bodies.num; )
        {
            cpBody* body_ = cast(cpBody*)bodies.arr[i];

            if (ComponentRoot(body_) == null)
            {
                // Body not in a component yet. Perform a DFS to flood fill mark
                // the component in the contact graph using this body_ as the root.
                FloodFillComponent(body_, body_);

                // Check if the component should be put to sleep.
                if (!ComponentActive(body_, space.sleepTimeThreshold))
                {
                    cpArrayPush(space.sleepingComponents, body_);
                    mixin(CP_BODY_FOREACH_COMPONENT!("body_", "other", "cpSpaceDeactivateBody(space, other);"));

                    // cpSpaceDeactivateBody() removed the current body_ from the list.
                    // Skip incrementing the index counter.
                    continue;
                }
            }

            i++;

            // Only sleeping bodies retain their component node pointers.
            body_.node.root = null;
            body_.node.next = null;
        }
    }
}

void activateTouchingHelper(cpShape* shape, cpContactPointSet* points, cpShape* other)
{
    cpBodyActivate(shape.body_);
}

void cpSpaceActivateShapesTouchingShape(cpSpace* space, cpShape* shape)
{
    if (space.sleepTimeThreshold != INFINITY)
    {
        cpSpaceShapeQuery(space, shape, safeCast!cpSpaceShapeQueryFunc(&activateTouchingHelper), shape);
    }
}
