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
module demo.Shatter;

import core.stdc.stdint : uintptr_t, uint32_t;
import core.stdc.stdlib;
import core.stdc.string;

import std.math;

alias M_PI_2 = PI_2;

import demo.dchip;

import demo.ChipmunkDebugDraw;
import demo.ChipmunkDemo;
import demo.types;

enum DENSITY = (1.0 / 10000.0);
enum MAX_VERTEXES_PER_VORONOI = 16;

struct WorleyContex
{
    uint32_t seed;
    cpFloat cellSize;
    int width, height;
    cpBB bb;
    cpVect focus;
};

static cpVect HashVect(uint32_t x, uint32_t y, uint32_t seed)
{
    //	cpFloat border = 0.21f;
    cpFloat  border = 0.05f;
    uint32_t h      = cast(uint32_t)(x * 1640531513 ^ y * 2654435789) + seed;

    return cpv(
        cpflerp(border, 1.0f - border, cast(cpFloat)(      h & 0xFFFF) / cast(cpFloat)0xFFFF),
        cpflerp(border, 1.0f - border, cast(cpFloat)((h >> 16) & 0xFFFF) / cast(cpFloat)0xFFFF)
        );
}

static cpVect WorleyPoint(int i, int j, WorleyContex* context)
{
    cpFloat size = context.cellSize;
    int  width   = context.width;
    int  height  = context.height;
    cpBB bb      = context.bb;

    //	cpVect fv = cpv(0.5, 0.5);
    cpVect fv = HashVect(i, j, context.seed);

    return cpv(
        cpflerp(bb.l, bb.r, 0.5f) + size * (i + fv.x - width * 0.5f),
        cpflerp(bb.b, bb.t, 0.5f) + size * (j + fv.y - height * 0.5f)
        );
}

static int ClipCell(cpShape* shape, cpVect center, int in_i, int in_j, WorleyContex* context, cpVect* verts, cpVect* clipped, int count)
{
    cpVect other = WorleyPoint(in_i, in_j, context);

    //	printf("  other %dx%d: (% 5.2f, % 5.2f) ", in_i, in_j, other.x, other.y);
    if (cpShapeNearestPointQuery(shape, other, null) > 0.0f)
    {
        //		printf("excluded\n");
        memcpy(clipped, verts, count * cpVect.sizeof);
        return count;
    }
    else
    {
        //		printf("clipped\n");
    }

    cpVect  n    = cpvsub(other, center);
    cpFloat dist = cpvdot(n, cpvlerp(center, other, 0.5f));

    int clipped_count = 0;

    for (int j = 0, i = count - 1; j < count; i = j, j++)
    {
        cpVect  a      = verts[i];
        cpFloat a_dist = cpvdot(a, n) - dist;

        if (a_dist <= 0.0)
        {
            clipped[clipped_count] = a;
            clipped_count++;
        }

        cpVect  b      = verts[j];
        cpFloat b_dist = cpvdot(b, n) - dist;

        if (a_dist * b_dist < 0.0f)
        {
            cpFloat t = cpfabs(a_dist) / (cpfabs(a_dist) + cpfabs(b_dist));

            clipped[clipped_count] = cpvlerp(a, b, t);
            clipped_count++;
        }
    }

    return clipped_count;
}

static void ShatterCell(cpSpace* space, cpShape* shape, cpVect cell, int cell_i, int cell_j, WorleyContex* context)
{
    //	printf("cell %dx%d: (% 5.2f, % 5.2f)\n", cell_i, cell_j, cell.x, cell.y);

    cpBody* body_ = cpShapeGetBody(shape);

    cpVect* ping = cast(cpVect*)alloca(MAX_VERTEXES_PER_VORONOI * cpVect.sizeof);
    cpVect* pong = cast(cpVect*)alloca(MAX_VERTEXES_PER_VORONOI * cpVect.sizeof);

    int count = cpPolyShapeGetNumVerts(shape);
    count = (count > MAX_VERTEXES_PER_VORONOI ? MAX_VERTEXES_PER_VORONOI : count);

    for (int i = 0; i < count; i++)
    {
        ping[i] = cpBodyLocal2World(body_, cpPolyShapeGetVert(shape, i));
    }

    for (int i = 0; i < context.width; i++)
    {
        for (int j = 0; j < context.height; j++)
        {
            if (
                !(i == cell_i && j == cell_j) &&
                cpShapeNearestPointQuery(shape, cell, null) < 0.0f
                )
            {
                count = ClipCell(shape, cell, i, j, context, ping, pong, count);
                memcpy(ping, pong, count * cpVect.sizeof);
            }
        }
    }

    cpVect  centroid = cpCentroidForPoly(count, ping);
    cpFloat mass     = cpAreaForPoly(count, ping) * DENSITY;
    cpFloat moment   = cpMomentForPoly(mass, count, ping, cpvneg(centroid));

    cpBody* new_body = cpSpaceAddBody(space, cpBodyNew(mass, moment));
    cpBodySetPos(new_body, centroid);
    cpBodySetVel(new_body, cpBodyGetVelAtWorldPoint(body_, centroid));
    cpBodySetAngVel(new_body, cpBodyGetAngVel(body_));

    cpShape* new_shape = cpSpaceAddShape(space, cpPolyShapeNew(new_body, count, ping, cpvneg(centroid)));

    // Copy whatever properties you have set on the original shape that are important
    cpShapeSetFriction(new_shape, cpShapeGetFriction(shape));
}

static void ShatterShape(cpSpace* space, cpShape* shape, cpFloat cellSize, cpVect focus)
{
    cpSpaceRemoveShape(space, shape);
    cpSpaceRemoveBody(space, shape.body_);

    cpBB bb     = cpShapeGetBB(shape);
    int  width  = cast(int)((bb.r - bb.l) / cellSize) + 1;
    int  height = cast(int)((bb.t - bb.b) / cellSize) + 1;

    //	printf("Splitting as %dx%d\n", width, height);
    WorleyContex context = { rand(), cellSize, width, height, bb, focus };

    for (int i = 0; i < context.width; i++)
    {
        for (int j = 0; j < context.height; j++)
        {
            cpVect cell = WorleyPoint(i, j, &context);

            if (cpShapeNearestPointQuery(shape, cell, null) < 0.0f)
            {
                ShatterCell(space, shape, cell, i, j, &context);
            }
        }
    }

    cpBodyFree(shape.body_);
    cpShapeFree(shape);
}

static void update(cpSpace* space, double dt)
{
    cpSpaceStep(space, dt);

    if (ChipmunkDemoRightDown)
    {
        cpNearestPointQueryInfo info;

        if (cpSpaceNearestPointQueryNearest(space, ChipmunkDemoMouse, 0, GRABABLE_MASK_BIT, CP_NO_GROUP, &info))
        {
            cpBB bb = cpShapeGetBB(info.shape);
            cpFloat cell_size = cpfmax(bb.r - bb.l, bb.t - bb.b) / 5.0f;

            if (cell_size > 5.0f)
            {
                ShatterShape(space, info.shape, cell_size, ChipmunkDemoMouse);
            }
            else
            {
                //				printf("Too small to splinter %f\n", cell_size);
            }
        }
    }
}

static cpSpace* init()
{
    ChipmunkDemoMessageString = "Right click something to shatter it.".dup;

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
    cpFloat height = 200.0f;
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

ChipmunkDemo Shatter = {
    "Shatter.",
    1.0f / 60.0f,
    &init,
    &update,
    &ChipmunkDemoDefaultDrawImpl,
    &destroy,
};
