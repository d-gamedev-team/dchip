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
module demo.Tumble;

import core.stdc.stdlib;

import dchip;

import demo.ChipmunkDebugDraw;
import demo.ChipmunkDemo;
import demo.types;

cpBody* rogueBoxBody;

void update(cpSpace* space, double dt)
{
    // Manually update the position of the box body_ so that the box rotates.
    // Normally Chipmunk calls this and cpBodyUpdateVelocity() for you,
    // but we wanted to control the angular velocity explicitly.
    cpBodyUpdatePosition(rogueBoxBody, dt);

    cpSpaceStep(space, dt);
}

void AddBox(cpSpace* space, cpVect pos, cpFloat mass, cpFloat width, cpFloat height)
{
    cpBody* body_ = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForBox(mass, width, height)));
    cpBodySetPos(body_, pos);

    cpShape* shape = cpSpaceAddShape(space, cpBoxShapeNew(body_, width, height));
    cpShapeSetElasticity(shape, 0.0f);
    cpShapeSetFriction(shape, 0.7f);
}

void AddSegment(cpSpace* space, cpVect pos, cpFloat mass, cpFloat width, cpFloat height)
{
    cpBody* body_ = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForBox(mass, width, height)));
    cpBodySetPos(body_, pos);

    cpShape* shape = cpSpaceAddShape(space, cpSegmentShapeNew(body_, cpv(0.0, (height - width) / 2.0), cpv(0.0, (width - height) / 2.0), width / 2.0));
    cpShapeSetElasticity(shape, 0.0f);
    cpShapeSetFriction(shape, 0.7f);
}

void AddCircle(cpSpace* space, cpVect pos, cpFloat mass, cpFloat radius)
{
    cpBody* body_ = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForCircle(mass, 0.0, radius, cpvzero)));
    cpBodySetPos(body_, pos);

    cpShape* shape = cpSpaceAddShape(space, cpCircleShapeNew(body_, radius, cpvzero));
    cpShapeSetElasticity(shape, 0.0f);
    cpShapeSetFriction(shape, 0.7f);
}

cpSpace* init()
{
    cpSpace* space = cpSpaceNew();
    cpSpaceSetGravity(space, cpv(0, -600));

    cpShape* shape;

    // We create an infinite mass rogue body_ to attach the line segments too
    // This way we can control the rotation however we want.
    rogueBoxBody = cpBodyNew(INFINITY, INFINITY);
    cpBodySetAngVel(rogueBoxBody, 0.4f);

    // Set up the static box.
    cpVect a = cpv(-200, -200);
    cpVect b = cpv(-200, 200);
    cpVect c = cpv(200, 200);
    cpVect d = cpv(200, -200);

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(rogueBoxBody, a, b, 0.0f));
    cpShapeSetElasticity(shape, 1.0f);
    cpShapeSetFriction(shape, 1.0f);
    cpShapeSetLayers(shape, NOT_GRABABLE_MASK);

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(rogueBoxBody, b, c, 0.0f));
    cpShapeSetElasticity(shape, 1.0f);
    cpShapeSetFriction(shape, 1.0f);
    cpShapeSetLayers(shape, NOT_GRABABLE_MASK);

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(rogueBoxBody, c, d, 0.0f));
    cpShapeSetElasticity(shape, 1.0f);
    cpShapeSetFriction(shape, 1.0f);
    cpShapeSetLayers(shape, NOT_GRABABLE_MASK);

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(rogueBoxBody, d, a, 0.0f));
    cpShapeSetElasticity(shape, 1.0f);
    cpShapeSetFriction(shape, 1.0f);
    cpShapeSetLayers(shape, NOT_GRABABLE_MASK);

    cpFloat mass   = 1;
    cpFloat width  = 30;
    cpFloat height = width * 2;

    // Add the bricks.
    for (int i = 0; i < 7; i++)
    {
        for (int j = 0; j < 3; j++)
        {
            cpVect pos = cpv(i * width - 150, j * height - 150);

            int type = (rand() % 3000) / 1000;

            if (type == 0)
            {
                AddBox(space, pos, mass, width, height);
            }
            else if (type == 1)
            {
                AddSegment(space, pos, mass, width, height);
            }
            else
            {
                AddCircle(space, cpvadd(pos, cpv(0.0, (height - width) / 2.0)), mass, width / 2.0);
                AddCircle(space, cpvadd(pos, cpv(0.0, (width - height) / 2.0)), mass, width / 2.0);
            }
        }
    }

    return space;
}

void destroy(cpSpace* space)
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpBodyFree(rogueBoxBody);
    cpSpaceFree(space);
}

ChipmunkDemo Tumble = {
    "Tumble",
    1.0 / 180.0,
    &init,
    &update,
    &ChipmunkDemoDefaultDrawImpl,
    &destroy,
};
