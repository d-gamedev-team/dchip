
// written in the D programming language

module samples.Plink;

import dchip.all;

import samples.ChipmunkDemo;

import std.math;

static cpSpace *space;

// Iterate over all of the bodies and reset the ones that have fallen offscreen.
static void
eachBody(cpBody *_body, void *unused)
{
    if(_body.p.y < -260 || cpfabs(_body.p.x) > 340){
        cpFloat x = frand()*640 - 320;
        _body.p = cpv(x, 260);
    }
}

static void
update(int ticks)
{
    int steps = 1;
    cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        cpSpaceStep(space, dt);
        cpSpaceEachBody(space, &eachBody, null);
    }
}

enum NUM_VERTS = 5;

static cpSpace *
init()
{
    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 5;
    space.gravity = cpv(0, -100);

    cpBody *_body;
    cpBody *staticBody = space.staticBody;
    cpShape *shape;

    // Create vertexes for a pentagon shape.
    cpVect verts[NUM_VERTS];
    for(int i=0; i<NUM_VERTS; i++){
        cpFloat angle = -2.0f*PI*i/(cast(cpFloat) NUM_VERTS);
        verts[i] = cpv(10.0f*cos(angle), 10.0f*sin(angle));
    }

    // Vertexes for a triangle shape.
    //port: ?
    enum cpVect tris[] = [
        cpv(-15,-15),
        cpv(  0, 10),
        cpv( 15,-15),
    ];

    // Create the static triangles.
    foreach(i; 0..9){
        foreach(j; 0..6){
            cpFloat stagger = (j%2)*40;
            cpVect offset;
            offset.x = (i*80) - 320 + stagger;
            offset.y = (j*70) - 240;

            shape = cpSpaceAddShape(space, cpPolyShapeNew(staticBody, 3, tris.ptr, offset));
            shape.e = 1.0f; shape.u = 1.0f;
            shape.layers = NOT_GRABABLE_MASK;
        }
    }

    // Add lots of pentagons.
    for(int i=0; i<300; i++){
        _body = cpSpaceAddBody(space, cpBodyNew(1.0f, cpMomentForPoly(1.0f, NUM_VERTS, verts.ptr, cpvzero)));
        cpFloat x = frand()*640 - 320;
        _body.p = cpv(x, 350);

        shape = cpSpaceAddShape(space, cpPolyShapeNew(_body, NUM_VERTS, verts.ptr, cpvzero));
        shape.e = 0.0f; shape.u = 0.4f;
    }

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Plink = {
    "Plink",
    null,
    &init,
    &update,
    &destroy,
};
