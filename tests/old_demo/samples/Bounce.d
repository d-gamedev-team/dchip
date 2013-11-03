
// written in the D programming language

module samples.Bounce;

import dchip.all;

import samples.ChipmunkDemo;

static cpSpace *space;

static void
update(int ticks)
{
    enum int steps = 3;
    enum cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        cpSpaceStep(space, dt);
    }
}

static void
add_box()
{
    enum cpFloat size = 10.0f;
    enum cpFloat mass = 1.0f;

    cpVect verts[] = [
        cpv(-size,-size),
        cpv(-size, size),
        cpv( size, size),
        cpv( size,-size),
    ];

    cpFloat radius = cpvlength(cpv(size, size));

    cpBody *_body = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForPoly(mass, 4, verts.ptr, cpvzero)));
    _body.p = cpv(frand()*(640 - 2*radius) - (320 - radius), frand()*(480 - 2*radius) - (240 - radius));
    _body.v = cpvmult(cpv(2*frand() - 1, 2*frand() - 1), 200);

    cpShape *shape = cpSpaceAddShape(space, cpPolyShapeNew(_body, 4, verts.ptr, cpvzero));
    shape.e = 1.0f; shape.u = 0.0f;
}

static cpSpace *
init()
{
    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 10;

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

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-320,240), cpv(320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    for(int i=0; i<10; i++)
        add_box();

    _body = cpSpaceAddBody(space, cpBodyNew(100.0f, 10000.0f));

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(_body, cpv(-75,0), cpv(75,0), 5.0f));
    shape.e = 1.0f; shape.u = 1.0f;

    cpSpaceAddConstraint(space, cpPivotJointNew2(_body, staticBody, cpvzero, cpvzero));

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Bounce = {
    "Bounce",
    null,
    &init,
    &update,
    &destroy,
};
