
// written in the D programming language

module samples.Player;

import dchip;

import samples.ChipmunkDemo;

import gameApp;

static cpSpace *space;

struct PlayerStruct {
    cpFloat u;
    cpShape *shape;
}

PlayerStruct playerInstance;

static void
playerUpdateVelocity(cpBody *body_, cpVect gravity, cpFloat damping, cpFloat dt)
{
    cpBodyUpdateVelocity(body_, gravity, damping, dt);
    body_.v.y = cpfmax(body_.v.y, -700);
    body_.v.x = cpfclamp(body_.v.x, -400, 400);
}

static void
SelectPlayerGroundNormal(cpBody *body_, cpArbiter *arb, cpVect *groundNormal){
    cpVect n = cpArbiterGetNormal(arb, 0);

    if(n.y > groundNormal.y){
        *groundNormal = n;
    }
}

static void
update(int ticks)
{
    static int lastJumpState = 0;
    int jumpState = (arrowDirection.y > 0.0f);

    cpBody *body_ = playerInstance.shape.body_;

    cpVect groundNormal = cpvzero;
    cpBodyEachArbiter(body_, cast(cpBodyArbiterIteratorFunc)&SelectPlayerGroundNormal, &groundNormal);

    if(groundNormal.y > 0.0f){
        playerInstance.shape.surface_v = cpv(400.0f*arrowDirection.x, 0.0f);//cpvmult(cpvperp(groundNormal), 400.0f*arrowDirection.x);
        if(arrowDirection.x) cpBodyActivate(body_);
    } else {
        playerInstance.shape.surface_v = cpvzero;
    }

    // apply jump
    if(jumpState && !lastJumpState && cpvlengthsq(groundNormal)){
        //		body.v = cpvmult(cpvslerp(groundNormal, cpv(0.0f, 1.0f), 0.5f), 500.0f);
        body_.v = cpvadd(body_.v, cpvmult(cpvslerp(groundNormal, cpv(0.0f, 1.0f), 0.75f), 500.0f));
        cpBodyActivate(body_);
    }

    if(cpvlengthsq(groundNormal)){
        cpFloat air_accel = body_.v.x + arrowDirection.x*(2000.0f);
        body_.f.x = body_.m*air_accel;
        //		body.v.x = cpflerpconst(body.v.x, 400.0f*arrowDirection.x, 2000.0f/60.0f);
    }

    int steps = 3;
    cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        cpSpaceStep(space, dt);
    }

    lastJumpState = jumpState;
}


static cpSpace *
init()
{
    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 10;
    space.gravity = cpv(0, -1500);
    space.sleepTimeThreshold = 9999999;

    cpBody *body_;
    cpBody *staticBody = space.staticBody;
    cpShape *shape;

    // Create segments around the edge of the screen.
    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(-320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(320,-240), cpv(320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(320,-240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-320,240), cpv(320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    // add some other segments to play with
    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-220,-200), cpv(-220,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(0,-240), cpv(320,-200), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(200,-240), cpv(320,-100), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(-220,-80), cpv(200,-80), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    shape.collision_type = 2;

    // Set up the player
    cpFloat radius = 15.0f;
    body_ = cpSpaceAddBody(space, cpBodyNew(10.0f, INFINITY));
    body_.p = cpv(0, -220);
    body_.velocity_func = &playerUpdateVelocity;

    shape = cpSpaceAddShape(space, cpCircleShapeNew(body_, radius, cpvzero));
    shape.e = 0.0f; shape.u = 2.0f;
    shape.collision_type = 1;

    playerInstance.u = shape.u;
    playerInstance.shape = shape;
    shape.data = &playerInstance;

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Player = {
    "Player",
    null,
    &init,
    &update,
    &destroy,
};
