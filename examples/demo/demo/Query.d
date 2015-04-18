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
module demo.Query;

import core.stdc.stdlib;

import std.math;

alias M_PI_2 = PI_2;

import demo.dchip;

import demo.ChipmunkDebugDraw;
import demo.ChipmunkDemo;
import demo.types;

cpVect QUERY_START = { 0, 0 };

void update(cpSpace* space, double dt)
{
    cpSpaceStep(space, dt);

    if (ChipmunkDemoRightClick)
    {
        QUERY_START = ChipmunkDemoMouse;
    }

    cpVect start = QUERY_START;
    cpVect end   = ChipmunkDemoMouse;
    ChipmunkDebugDrawSegment(start, end, RGBAColor(0, 1, 0, 1));

    ChipmunkDemoPrintString("Query: Dist(%f) Point%s, ", cpvdist(start, end), cpvstr(end));

    cpSegmentQueryInfo segInfo = {};

    if (cpSpaceSegmentQueryFirst(space, start, end, CP_ALL_LAYERS, CP_NO_GROUP, &segInfo))
    {
        cpVect point = cpSegmentQueryHitPoint(start, end, segInfo);

        // Draw blue over the occluded part of the query
        ChipmunkDebugDrawSegment(point, end, RGBAColor(0, 0, 1, 1));

        // Draw a little red surface normal
        ChipmunkDebugDrawSegment(point, cpvadd(point, cpvmult(segInfo.n, 16)), RGBAColor(1, 0, 0, 1));

        // Draw a little red dot on the hit point.
        ChipmunkDebugDrawDot(3, point, RGBAColor(1, 0, 0, 1));

        ChipmunkDemoPrintString("Segment Query: Dist(%f) Normal%s", cpSegmentQueryHitDist(start, end, segInfo), cpvstr(segInfo.n));
    }
    else
    {
        ChipmunkDemoPrintString("Segment Query (None)");
    }

    cpNearestPointQueryInfo nearestInfo = {};
    cpSpaceNearestPointQueryNearest(space, ChipmunkDemoMouse, 100.0, CP_ALL_LAYERS, CP_NO_GROUP, &nearestInfo);

    if (nearestInfo.shape)
    {
        // Draw a grey line to the closest shape.
        ChipmunkDebugDrawDot(3, ChipmunkDemoMouse, RGBAColor(0.5, 0.5, 0.5, 1.0));
        ChipmunkDebugDrawSegment(ChipmunkDemoMouse, nearestInfo.p, RGBAColor(0.5, 0.5, 0.5, 1.0));

        // Draw a red bounding box around the shape under the mouse.
        if (nearestInfo.d < 0)
            ChipmunkDebugDrawBB(cpShapeGetBB(nearestInfo.shape), RGBAColor(1, 0, 0, 1));
    }
}

cpSpace* init()
{
    QUERY_START = cpvzero;

    cpSpace* space = cpSpaceNew();
    cpSpaceSetIterations(space, 5);

    {
        // add a fat segment
        cpFloat mass   = 1.0f;
        cpFloat length = 100.0f;
        cpVect  a      = cpv(-length / 2.0f, 0.0f), b = cpv(length / 2.0f, 0.0f);

        cpBody* body_ = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForSegment(mass, a, b)));
        cpBodySetPos(body_, cpv(0.0f, 100.0f));

        cpSpaceAddShape(space, cpSegmentShapeNew(body_, a, b, 20.0f));
    }

    {
        // add a static segment
        cpSpaceAddShape(space, cpSegmentShapeNew(cpSpaceGetStaticBody(space), cpv(0, 300), cpv(300, 0), 0.0f));
    }

    {
        // add a pentagon
        cpFloat mass        = 1.0f;
        const int NUM_VERTS = 5;

        cpVect[NUM_VERTS] verts;

        for (int i = 0; i < NUM_VERTS; i++)
        {
            cpFloat angle = -2 * M_PI * i / (cast(cpFloat)NUM_VERTS);
            verts[i] = cpv(30 * cos(angle), 30 * sin(angle));
        }

        cpBody* body_ = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForPoly(mass, NUM_VERTS, verts.ptr, cpvzero)));
        cpBodySetPos(body_, cpv(50.0f, 30.0f));

        cpSpaceAddShape(space, cpPolyShapeNew2(body_, NUM_VERTS, verts.ptr, cpvzero, 10.0f));
    }

    {
        // add a circle
        cpFloat mass = 1.0f;
        cpFloat r    = 20.0f;

        cpBody* body_ = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForCircle(mass, 0.0f, r, cpvzero)));
        cpBodySetPos(body_, cpv(100.0f, 100.0f));

        cpSpaceAddShape(space, cpCircleShapeNew(body_, r, cpvzero));
    }

    return space;
}

void destroy(cpSpace* space)
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

ChipmunkDemo Query = {
    "Segment Query",
    1.0 / 60.0,
    &init,
    &update,
    &ChipmunkDemoDefaultDrawImpl,
    &destroy,
};
