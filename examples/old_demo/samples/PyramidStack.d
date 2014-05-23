
// written in the D programming language

module samples.PyramidStack;

import dchip.all;

import samples.ChipmunkDemo;

static cpSpace *space;

static void
update(int ticks)
{
    int steps = 3;
    cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        cpSpaceStep(space, dt);
    }
}

static cpSpace *
init()
{
    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 30;
    space.gravity = cpv(0, -100);
    space.sleepTimeThreshold = 0.5f;
    space.collisionSlop = 0.5f;

    cpBody *_body;
    cpBody *staticBody = space.staticBody;
    cpShape *shape;

    // Create segments around the edge of the screen.
    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(-320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(320,-240), cpv(320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(320,-240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    // Add lots of boxes.
    for(int i=0; i<14; i++){
        for(int j=0; j<=i; j++){
            _body = cpSpaceAddBody(space, cpBodyNew(1.0f, cpMomentForBox(1.0f, 30.0f, 30.0f)));
            _body.p = cpv(j*32 - i*16, 300 - i*32);

            shape = cpSpaceAddShape(space, cpBoxShapeNew(_body, 30.0f, 30.0f));
            shape.e = 0.0f; shape.u = 0.8f;
        }
    }

    // Add a ball to make things more interesting
    cpFloat radius = 15.0f;
    _body = cpSpaceAddBody(space, cpBodyNew(10.0f, cpMomentForCircle(10.0f, 0.0f, radius, cpvzero)));
    _body.p = cpv(0, -240 + radius+5);

    shape = cpSpaceAddShape(space, cpCircleShapeNew(_body, radius, cpvzero));
    shape.e = 0.0f; shape.u = 0.9f;

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo PyramidStack = {
    "Pyramid Stack",
    null,
    &init,
    &update,
    &destroy,
};
