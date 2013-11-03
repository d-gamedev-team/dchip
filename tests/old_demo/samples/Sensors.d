
// written in the D programming language

module samples.Sensors;

import dchip;

import samples.ChipmunkDemo;

static cpSpace *space;

enum CollisionTypes {
    BALL_TYPE,
    BLOCKING_SENSOR_TYPE,
    CATCH_SENSOR_TYPE,
};

struct Emitter {
    int queue;
    int blocked;
    cpVect position;
}

static Emitter emitterInstance;

static cpBool
blockerBegin(cpArbiter *arb, cpSpace *space, void *unused)
{
    mixin(CP_ARBITER_GET_SHAPES!("arb", "a", "b"));
    Emitter *emitter = cast(Emitter *) a.data;

    emitter.blocked++;

    return cpFalse; // Return values from sensors callbacks are ignored,
}

static void
blockerSeparate(cpArbiter *arb, cpSpace *space, void *unused)
{
    mixin(CP_ARBITER_GET_SHAPES!("arb", "a", "b"));
    Emitter *emitter = cast(Emitter *)a.data;

    emitter.blocked--;
}

static void
postStepRemove(cpSpace *space, cpShape *shape, void *unused)
{
    cpSpaceRemoveBody(space, shape.body_);
    cpSpaceRemoveShape(space, shape);

    cpBodyFree(shape.body_);
    cpShapeFree(shape);
}

static cpBool
catcherBarBegin(cpArbiter *arb, cpSpace *space, void *unused)
{
    mixin(CP_ARBITER_GET_SHAPES!("arb", "a", "b"));
    Emitter *emitter = cast(Emitter *) a.data;

    emitter.queue++;
    cpSpaceAddPostStepCallback(space, cast(cpPostStepFunc)&postStepRemove, b, null);

    return cpFalse;
}

static cpFloat frand_unit(){return 2.0f*(frand()) - 1.0f;}

static void
update(int ticks)
{
    int steps = 1;
    cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    if(!emitterInstance.blocked && emitterInstance.queue){
        emitterInstance.queue--;

        cpBody *body_ = cpSpaceAddBody(space, cpBodyNew(1.0f, cpMomentForCircle(1.0f, 15.0f, 0.0f, cpvzero)));
        body_.p = emitterInstance.position;
        body_.v = cpvmult(cpv(frand_unit(), frand_unit()), 100.0f);

        cpShape *shape = cpSpaceAddShape(space, cpCircleShapeNew(body_, 15.0f, cpvzero));
        shape.collision_type = CollisionTypes.BALL_TYPE;
    }

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

    cpBody *staticBody = space.staticBody;
    cpShape *shape;

    // Data structure for our ball emitter
    // We'll use two sensors for it, one to see if the emitter is blocked
    // a second to catch the balls and add them back to the emitter
    emitterInstance.queue = 5;
    emitterInstance.blocked = 0;
    emitterInstance.position = cpv(0, 150);

    // Create our blocking sensor, so we know when the emitter is clear to emit another ball
    shape = cpSpaceAddShape(space, cpCircleShapeNew(staticBody, 15.0f, emitterInstance.position));
    shape.sensor = 1;
    shape.collision_type = CollisionTypes.BLOCKING_SENSOR_TYPE;
    shape.data = &emitterInstance;

    // Create our catch sensor to requeue the balls when they reach the bottom of the screen
    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-2000, -200), cpv(2000, -200), 15.0f));
    shape.sensor = 1;
    shape.collision_type = CollisionTypes.CATCH_SENSOR_TYPE;
    shape.data = &emitterInstance;

    cpSpaceAddCollisionHandler(space, CollisionTypes.BLOCKING_SENSOR_TYPE, CollisionTypes.BALL_TYPE, &blockerBegin, null, null, &blockerSeparate, null);
    cpSpaceAddCollisionHandler(space, CollisionTypes.CATCH_SENSOR_TYPE, CollisionTypes.BALL_TYPE, &catcherBarBegin, null, null, null, null);

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Sensors = {
    "Sensors",
    null,
    &init,
    &update,
    &destroy,
};
