
// written in the D programming language

module samples.PyramidTopple;

import dchip;

import samples.ChipmunkDemo;

import std.math:PI;

static cpSpace *space;

static void
update(int ticks)
{
    int steps = 3;
    cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++)
        cpSpaceStep(space, dt);
}

enum WIDTH = 4.0f;
enum HEIGHT = 30.0f;

static void
add_domino(cpSpace *space, cpVect pos, cpBool flipped)
{
    cpFloat mass = 1.0f;
    cpFloat moment = cpMomentForBox(mass, WIDTH, HEIGHT);

    cpBody *_body = cpSpaceAddBody(space, cpBodyNew(mass, moment));
    _body.p = pos;

    cpShape *shape = (flipped ? cpBoxShapeNew(_body, HEIGHT, WIDTH) : cpBoxShapeNew(_body, WIDTH, HEIGHT));
    cpSpaceAddShape(space, shape);
    shape.e = 0.0f; shape.u = 0.6f;
}

static cpSpace *
init()
{
    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 30;
    space.gravity = cpv(0, -300);
    space.sleepTimeThreshold = 0.5f;
    space.collisionSlop = 0.5f;

    // Add a floor.
    cpShape* shape = cpSpaceAddShape(space, cpSegmentShapeNew(space.staticBody, cpv(-600,-240), cpv(600,-240), 0.0f));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    // Shared friction constant.
    cpFloat u = 0.6f;

    // Add the dominoes.
    int n = 12;
    for(int i=0; i<n; i++){
        for(int j=0; j<(n - i); j++){
            cpVect offset = cpv((j - (n - 1 - i)*0.5f)*1.5f*HEIGHT, (i + 0.5f)*(HEIGHT + 2*WIDTH) - WIDTH - 240);
            add_domino(space, offset, cpFalse);
            add_domino(space, cpvadd(offset, cpv(0, (HEIGHT + WIDTH)/2.0f)), cpTrue);

            if(j == 0){
                add_domino(space, cpvadd(offset, cpv(0.5f*(WIDTH - HEIGHT), HEIGHT + WIDTH)), cpFalse);
            }

            if(j != n - i - 1){
                add_domino(space, cpvadd(offset, cpv(HEIGHT*0.75f, (HEIGHT + 3*WIDTH)/2.0f)), cpTrue);
            } else {
                add_domino(space, cpvadd(offset, cpv(0.5f*(HEIGHT - WIDTH), HEIGHT + WIDTH)), cpFalse);
            }
        }
    }

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo PyramidTopple = {
    "Pyramid Topple",
    null,
    &init,
    &update,
    &destroy,
};
