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
module demo.Plink;

import core.stdc.stdlib;

import dchip;

import demo.ChipmunkDebugDraw;
import demo.ChipmunkDemo;
import demo.types;

cpFloat pentagon_mass   = 0.0f;
cpFloat pentagon_moment = 0.0f;

// Iterate over all of the bodies and reset the ones that have fallen offscreen.
void eachBody(cpBody* body_, void* unused)
{
    cpVect pos = cpBodyGetPos(body_);

    if (pos.y < -260 || cpfabs(pos.x) > 340)
    {
        cpFloat x = rand() / cast(cpFloat)RAND_MAX * 640 - 320;
        cpBodySetPos(body_, cpv(x, 260));
    }
}

void update(cpSpace* space, double dt)
{
    if (ChipmunkDemoRightDown)
    {
        cpShape* nearest = cpSpaceNearestPointQueryNearest(space, ChipmunkDemoMouse, 0.0, GRABABLE_MASK_BIT, CP_NO_GROUP, null);

        if (nearest)
        {
            cpBody* body_ = cpShapeGetBody(nearest);

            if (cpBodyIsStatic(body_))
            {
                cpSpaceConvertBodyToDynamic(space, body_, pentagon_mass, pentagon_moment);
                cpSpaceAddBody(space, body_);
            }
            else
            {
                cpSpaceRemoveBody(space, body_);
                cpSpaceConvertBodyToStatic(space, body_);
            }
        }
    }

    cpSpaceStep(space, dt);
    cpSpaceEachBody(space, &eachBody, null);
}

enum NUM_VERTS = 5;

cpSpace* init()
{
    ChipmunkDemoMessageString = "Right click to make pentagons static/dynamic.\0".dup;

    cpSpace* space = cpSpaceNew();
    cpSpaceSetIterations(space, 5);
    cpSpaceSetGravity(space, cpv(0, -100));

    cpBody * body_;
    cpBody * staticBody = cpSpaceGetStaticBody(space);
    cpShape* shape;

    // Vertexes for a triangle shape.
    cpVect tris[3] = [
        cpv(-15, -15),
        cpv(0, 10),
        cpv(15, -15),
    ];

    // Create the static triangles.
    for (int i = 0; i < 9; i++)
    {
        for (int j = 0; j < 6; j++)
        {
            cpFloat stagger = (j % 2) * 40;
            cpVect  offset  = cpv(i * 80 - 320 + stagger, j * 70 - 240);
            shape = cpSpaceAddShape(space, cpPolyShapeNew(staticBody, 3, tris.ptr, offset));
            cpShapeSetElasticity(shape, 1.0f);
            cpShapeSetFriction(shape, 1.0f);
            cpShapeSetLayers(shape, NOT_GRABABLE_MASK);
        }
    }

    // Create vertexes for a pentagon shape.
    cpVect verts[NUM_VERTS];

    for (int i = 0; i < NUM_VERTS; i++)
    {
        cpFloat angle = -2 * M_PI * i / (cast(cpFloat)NUM_VERTS);
        verts[i] = cpv(10 * cos(angle), 10 * sin(angle));
    }

    pentagon_mass   = 1.0;
    pentagon_moment = cpMomentForPoly(1.0f, NUM_VERTS, verts.ptr, cpvzero);

    // Add lots of pentagons.
    for (int i = 0; i < 300; i++)
    {
        body_ = cpSpaceAddBody(space, cpBodyNew(pentagon_mass, pentagon_moment));
        cpFloat x = rand() / cast(cpFloat)RAND_MAX * 640 - 320;
        cpBodySetPos(body_, cpv(x, 350));

        shape = cpSpaceAddShape(space, cpPolyShapeNew(body_, NUM_VERTS, verts.ptr, cpvzero));
        cpShapeSetElasticity(shape, 0.0f);
        cpShapeSetFriction(shape, 0.4f);
    }

    return space;
}

void destroy(cpSpace* space)
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

ChipmunkDemo Plink = {
    "Plink",
    1.0 / 60.0,
    &init,
    &update,
    &ChipmunkDemoDefaultDrawImpl,
    &destroy,
};
