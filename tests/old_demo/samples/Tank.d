
// written in the D programming language

module samples.Tank;

import dchip.all;

import samples.ChipmunkDemo;

import gameApp;

static cpSpace *space;

static cpBody *tankBody;
static cpBody *tankControlBody;

static void
update(int ticks)
{
    enum int steps = 1;
    enum cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        // turn the control _body based on the angle relative to the actual _body
        cpVect mouseDelta = cpvsub(mousePos, tankBody.p);
        cpFloat turn = cpvtoangle(cpvunrotate(tankBody.rot, mouseDelta));
        cpBodySetAngle(tankControlBody, tankBody.a - turn);

        // drive the tank towards the mouse
        if(cpvnear(mousePos, tankBody.p, 30.0)){
            tankControlBody.v = cpvzero; // stop
        } else {
            cpFloat direction = (cpvdot(mouseDelta, tankBody.rot) > 0.0 ? 1.0 : -1.0);
            tankControlBody.v = cpvrotate(tankBody.rot, cpv(30.0f*direction, 0.0f));
        }

        cpSpaceStep(space, dt);
    }
}

static cpBody *
add_box(cpFloat size, cpFloat mass)
{
    cpVect verts[] = [
        cpv(-size,-size),
        cpv(-size, size),
        cpv( size, size),
        cpv( size,-size),
    ];

    cpFloat radius = cpvlength(cpv(size, size));

    cpBody *_body = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForPoly(mass, 4, verts.ptr, cpvzero)));
    _body.p = cpv(frand()*(640 - 2*radius) - (320 - radius), frand()*(480 - 2*radius) - (240 - radius));

    cpShape *shape = cpSpaceAddShape(space, cpPolyShapeNew(_body, 4, verts.ptr, cpvzero));
    shape.e = 0.0f; shape.u = 0.7f;

    return _body;
}

static cpSpace *
init()
{
    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 10;
    space.sleepTimeThreshold = 0.5f;

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

    for(int i=0; i<50; i++){
        cpBody *_body = add_box(10.0, 1.0);

        cpConstraint *pivot = cpSpaceAddConstraint(space, cpPivotJointNew2(staticBody, _body, cpvzero, cpvzero));
        pivot.errorBias = 1.0f; // disable joint correction
        pivot.maxForce = 1000.0f; // emulate linear friction

        cpConstraint *gear = cpSpaceAddConstraint(space, cpGearJointNew(staticBody, _body, 0.0f, 1.0f));
        gear.errorBias = 1.0f; // disable joint correction
        gear.maxForce = 5000.0f; // emulate angular friction
    }

    // We joint the tank to the control _body and control the tank indirectly by modifying the control _body.
    tankControlBody = cpBodyNew(INFINITY, INFINITY);
    tankBody = add_box(15.0, 10.0);

    cpConstraint *pivot = cpSpaceAddConstraint(space, cpPivotJointNew2(tankControlBody, tankBody, cpvzero, cpvzero));
    pivot.errorBias = 1.0f; // disable joint correction
    pivot.maxForce = 10000.0f; // emulate linear friction

    cpConstraint *gear = cpSpaceAddConstraint(space, cpGearJointNew(tankControlBody, tankBody, 0.0f, 1.0f));
    gear.errorBias = 0.0f; // attempt to fully correct the joint each step
    gear.maxBias = 1.0f; // but limit it's angular correction rate
    gear.maxForce = 500000.0f; // emulate angular friction

    return space;
}

static void
destroy()
{
    cpBodyFree(tankControlBody);
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Tank = {
    "Tank",
    null,
    &init,
    &update,
    &destroy,
};
