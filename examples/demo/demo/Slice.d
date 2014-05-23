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
module demo.Slice;

import core.stdc.stdlib;

import std.math;

alias M_PI_2 = PI_2;

import demo.dchip;

import demo.ChipmunkDebugDraw;
import demo.ChipmunkDemo;
import demo.types;

enum DENSITY = (1.0 / 10000.0);

static void ClipPoly(cpSpace* space, cpShape* shape, cpVect n, cpFloat dist)
{
    cpBody* body_ = cpShapeGetBody(shape);

    int count        = cpPolyShapeGetNumVerts(shape);
    int clippedCount = 0;

    cpVect* clipped = cast(cpVect*)alloca((count + 1) * cpVect.sizeof);

    for (int i = 0, j = count - 1; i < count; j = i, i++)
    {
        cpVect  a      = cpBodyLocal2World(body_, cpPolyShapeGetVert(shape, j));
        cpFloat a_dist = cpvdot(a, n) - dist;

        if (a_dist < 0.0)
        {
            clipped[clippedCount] = a;
            clippedCount++;
        }

        cpVect  b      = cpBodyLocal2World(body_, cpPolyShapeGetVert(shape, i));
        cpFloat b_dist = cpvdot(b, n) - dist;

        if (a_dist * b_dist < 0.0f)
        {
            cpFloat t = cpfabs(a_dist) / (cpfabs(a_dist) + cpfabs(b_dist));

            clipped[clippedCount] = cpvlerp(a, b, t);
            clippedCount++;
        }
    }

    cpVect  centroid = cpCentroidForPoly(clippedCount, clipped);
    cpFloat mass     = cpAreaForPoly(clippedCount, clipped) * DENSITY;
    cpFloat moment   = cpMomentForPoly(mass, clippedCount, clipped, cpvneg(centroid));

    cpBody* new_body = cpSpaceAddBody(space, cpBodyNew(mass, moment));
    cpBodySetPos(new_body, centroid);
    cpBodySetVel(new_body, cpBodyGetVelAtWorldPoint(body_, centroid));
    cpBodySetAngVel(new_body, cpBodyGetAngVel(body_));

    cpShape* new_shape = cpSpaceAddShape(space, cpPolyShapeNew(new_body, clippedCount, clipped, cpvneg(centroid)));

    // Copy whatever properties you have set on the original shape that are important
    cpShapeSetFriction(new_shape, cpShapeGetFriction(shape));
}

// Context structs are annoying, use blocks or closures instead if your compiler supports them.
struct SliceContext
{
    cpVect a, b;
    cpSpace* space;
};

static void SliceShapePostStep(cpSpace* space, cpShape* shape, SliceContext* context)
{
    cpVect a = context.a;
    cpVect b = context.b;

    // Clipping plane normal and distance.
    cpVect  n    = cpvnormalize(cpvperp(cpvsub(b, a)));
    cpFloat dist = cpvdot(a, n);

    ClipPoly(space, shape, n, dist);
    ClipPoly(space, shape, cpvneg(n), -dist);

    cpBody* body_ = cpShapeGetBody(shape);
    cpSpaceRemoveShape(space, shape);
    cpSpaceRemoveBody(space, body_);
    cpShapeFree(shape);
    cpBodyFree(body_);
}

static void SliceQuery(cpShape* shape, cpFloat t, cpVect n, SliceContext* context)
{
    cpVect a = context.a;
    cpVect b = context.b;

    // Check that the slice was complete by checking that the endpoints aren't in the sliced shape.
    if (!cpShapePointQuery(shape, a) && !cpShapePointQuery(shape, b))
    {
        // Can't modify the space during a query.
        // Must make a post-step callback to do the actual slicing.
        cpSpaceAddPostStepCallback(context.space, safeCast!cpPostStepFunc(&SliceShapePostStep), shape, context);
    }
}

static void update(cpSpace* space, double dt)
{
    cpSpaceStep(space, dt);

    static cpBool lastClickState = cpFalse;
    static cpVect sliceStart     = { 0.0, 0.0 };

    // Annoying state tracking code that you wouldn't need
    // in a real event driven system.
    if (ChipmunkDemoRightClick != lastClickState)
    {
        if (ChipmunkDemoRightClick)
        {
            // MouseDown
            sliceStart = ChipmunkDemoMouse;
        }
        else
        {
            // MouseUp
            SliceContext context = { sliceStart, ChipmunkDemoMouse, space };
            cpSpaceSegmentQuery(space, sliceStart, ChipmunkDemoMouse, GRABABLE_MASK_BIT, CP_NO_GROUP, safeCast!cpSpaceSegmentQueryFunc(&SliceQuery), &context);
        }

        lastClickState = ChipmunkDemoRightClick;
    }

    if (ChipmunkDemoRightClick)
    {
        ChipmunkDebugDrawSegment(sliceStart, ChipmunkDemoMouse, RGBAColor(1, 0, 0, 1));
    }
}

static cpSpace* init()
{
    ChipmunkDemoMessageString = "Right click and drag to slice up the block.".dup;

    cpSpace* space = cpSpaceNew();
    cpSpaceSetIterations(space, 30);
    cpSpaceSetGravity(space, cpv(0, -500));
    cpSpaceSetSleepTimeThreshold(space, 0.5f);
    cpSpaceSetCollisionSlop(space, 0.5f);

    cpBody * body_;
    cpBody * staticBody = cpSpaceGetStaticBody(space);
    cpShape* shape;

    // Create segments around the edge of the screen.
    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-1000, -240), cpv(1000, -240), 0.0f));
    cpShapeSetElasticity(shape, 1.0f);
    cpShapeSetFriction(shape, 1.0f);
    cpShapeSetLayers(shape, NOT_GRABABLE_MASK);

    cpFloat width  = 200.0f;
    cpFloat height = 300.0f;
    cpFloat mass   = width * height * DENSITY;
    cpFloat moment = cpMomentForBox(mass, width, height);

    body_ = cpSpaceAddBody(space, cpBodyNew(mass, moment));

    shape = cpSpaceAddShape(space, cpBoxShapeNew(body_, width, height));
    cpShapeSetFriction(shape, 0.6f);

    return space;
}

static void destroy(cpSpace* space)
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

ChipmunkDemo Slice = {
    "Slice.",
    1.0 / 60.0,
    &init,
    &update,
    &ChipmunkDemoDefaultDrawImpl,
    &destroy,
};
