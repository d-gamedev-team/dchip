
// written in the D programming language

module samples.UnsafeOps;

import dchip;

import samples.ChipmunkDemo;

import gameApp;

import std.math;

static cpSpace *space;

enum M_PI = PI;
enum M_PI_2 = PI*0.5f;

enum NUM_CIRCLES = 30;

static cpShape *circles[NUM_CIRCLES];
static cpFloat circleRadius = 30.0f;

static void
update(int ticks)
{
    if(arrowDirection.y){
        circleRadius = cpfmax(10.0f, circleRadius + arrowDirection.y);

        for(int i=0; i<NUM_CIRCLES; i++){
            circles[i].body_.m = cpMomentForCircle(1.0f, 0.0f, circleRadius, cpvzero);
            cpCircleShapeSetRadius(circles[i], circleRadius);
        }
    }

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
    space.iterations = 5;
    space.gravity = cpv(0, -100);

    cpBody *body_, staticBody = space.staticBody;
    cpShape *shape;

    shape = cpSpaceAddStaticShape(space, cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(-320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    shape = cpSpaceAddStaticShape(space, cpSegmentShapeNew(staticBody, cpv(320,-240), cpv(320,240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    shape = cpSpaceAddStaticShape(space, cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(320,-240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    for(int i=0; i<NUM_CIRCLES; i++){
        body_ = cpSpaceAddBody(space, cpBodyNew(1.0f, cpMomentForCircle(1.0f, 0.0f, circleRadius, cpvzero)));
        body_.p = cpvmult(cpv(frand()*2.0f - 1.0f, frand()*2.0f - 1.0f), circleRadius*5.0f);

        circles[i] = shape = cpSpaceAddShape(space, cpCircleShapeNew(body_, circleRadius, cpvzero));
        shape.e = 0.0f; shape.u = 1.0f;
    }

    //strcat(messageString,
    //	"chipmunk_unsafe.h Contains functions for changing shapes, but they can cause severe stability problems if used incorrectly.\n"
    //	"Shape changes occur as instantaneous changes to position without an accompanying velocity change. USE WITH CAUTION!");
    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo UnsafeOps = {
    "Unsafe Operations",
    null,
    &init,
    &update,
    &destroy,
};
