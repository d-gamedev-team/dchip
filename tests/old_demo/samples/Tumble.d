
// written in the D programming language

module samples.Tumble;

import dchip.all;

import samples.ChipmunkDemo;

static cpSpace *space;
static cpBody *staticBody;

static void
update(int ticks)
{
    enum int steps = 3;
    enum cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        cpSpaceStep(space, dt);

        // Manually update the position of the static shape so that
        // the box rotates.
        cpBodyUpdatePosition(staticBody, dt);

        // Because the box was added as a static shape and we moved it
        // we need to manually rehash the static spatial hash.
        cpSpaceReindexStatic(space);
    }
}

static cpSpace *
init()
{
    staticBody = cpBodyNew(INFINITY, INFINITY);

    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.gravity = cpv(0, -600);

    cpBody *_body;
    cpShape *shape;

    // Vertexes for the bricks
    int num = 4;
    cpVect verts[] = [
        cpv(-30,-15),
        cpv(-30, 15),
        cpv( 30, 15),
        cpv( 30,-15),
    ];

    // Set up the static box.
    cpVect a = cpv(-200, -200);
    cpVect b = cpv(-200,  200);
    cpVect c = cpv( 200,  200);
    cpVect d = cpv( 200, -200);

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, a, b, 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, b, c, 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, c, d, 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, d, a, 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    // Give the box a little spin.
    // Because staticBody is never added to the space, we will need to
    // update it ourselves. (see above).
    // NOTE: Normally you would want to add the segments as normal and not static shapes.
    // I'm just doing it to demonstrate the cpSpaceReindexStatic() function.
    staticBody.w = 0.4f;

    // Add the bricks.
    for(int i=0; i<3; i++){
        for(int j=0; j<7; j++){
            _body = cpSpaceAddBody(space, cpBodyNew(1.0f, cpMomentForPoly(1.0f, num, verts.ptr, cpvzero)));
            _body.p = cpv(i*60 - 150, j*30 - 150);

            shape = cpSpaceAddShape(space, cpPolyShapeNew(_body, num, verts.ptr, cpvzero));
            shape.e = 0.0f; shape.u = 0.7f;
        }
    }

    return space;
}

static void
destroy()
{
    cpBodyFree(staticBody);
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Tumble = {
    "Tumble",
    null,
    &init,
    &update,
    &destroy,
};
