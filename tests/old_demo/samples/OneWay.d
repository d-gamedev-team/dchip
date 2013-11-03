
// written in the D programming language

module samples.OneWay;

import dchip.all;

import samples.ChipmunkDemo;

static cpSpace *space;

struct OneWayPlatform {
    cpVect n; // direction objects may pass through
}

static OneWayPlatform platformInstance;

static cpBool
preSolve(cpArbiter *arb, cpSpace *space, void *ignore)
{
    mixin(CP_ARBITER_GET_SHAPES!("arb", "a", "b"));
    OneWayPlatform *platform = cast(OneWayPlatform *)a.data;

    if(cpvdot(cpArbiterGetNormal(arb, 0), platform.n) < 0){
        cpArbiterIgnore(arb);
        return cpFalse;
    }

    return cpTrue;
}

static void
update(int ticks)
{
    int steps = 1;
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
    space.iterations = 10;
    space.gravity = cpv(0, -100);

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

    // Add our one way segment
    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-160,-100), cpv(160,-100), 10.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.collision_type = 1;
    shape.layers = NOT_GRABABLE_MASK;

    // We'll use the data pointer for the OneWayPlatform struct
    platformInstance.n = cpv(0, 1); // let objects pass upwards
    shape.data = &platformInstance;


    // Add a ball to make things more interesting
    cpFloat radius = 15.0f;
    _body = cpSpaceAddBody(space, cpBodyNew(10.0f, cpMomentForCircle(10.0f, 0.0f, radius, cpvzero)));
    _body.p = cpv(0, -200);
    _body.v = cpv(0, 170);

    shape = cpSpaceAddShape(space, cpCircleShapeNew(_body, radius, cpvzero));
    shape.e = 0.0f; shape.u = 0.9f;
    shape.collision_type = 2;

    cpSpaceAddCollisionHandler(space, 1, 2, null, &preSolve, null, null, null);

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo OneWay = {
    "One Way Platforms",
    null,
    &init,
    &update,
    &destroy,
};
