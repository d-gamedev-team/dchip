import dchip;

import std.stdio;

void main()
{
    cpSpace* space = cpSpaceNew();

    space.gravity = cpv(0, -1);

    // simulate a step
    cpSpaceStep(space, 1.0f/60.0f);

    // cheer
    writefln("Hello chipmunkd");

    // cleanup
    cpSpaceFree(space);
}
