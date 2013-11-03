
// written in the D programming language

module samples.ChipmunkDemo;

import dchip.all;

import drawSpace;

import core.stdc.stdlib;

alias cpSpace *function() demoInitFunc;
alias void function(int ticks) demoUpdateFunc;
alias void function()demoDestroyFunc;

struct chipmunkDemo {
    string name;

    const drawSpaceOptions *drawOptions;

    demoInitFunc	initFunc;
    demoUpdateFunc	updateFunc;
    demoDestroyFunc destroyFunc;
}

void
ChipmunkDemoFreeSpaceChildren(cpSpace *space)
{
    cpArray *components = space.sleepingComponents;
    while(components.num) cpBodyActivate(cast(cpBody *)components.arr[0]);

    cpSpatialIndexEach(space.staticShapes, &shapeFreeWrap, null);
    cpSpatialIndexEach(space.activeShapes, &shapeFreeWrap, null);

    cpArrayFreeEach(space.bodies, &cpBodyFreeVoid);
    cpArrayFreeEach(space.constraints, &cpConstraintFreeWrap);
}

// special hack for OSX
version(Posix) import std.random:uniform;

static cpFloat
frand()
{
version(Posix){
    return std.random.uniform(0.0f,1.0f);
}else{
    return cast(cpFloat)rand()/cast(cpFloat)RAND_MAX;
}
}

enum GRABABLE_MASK_BIT = (1<<31);
enum NOT_GRABABLE_MASK = (~GRABABLE_MASK_BIT);
