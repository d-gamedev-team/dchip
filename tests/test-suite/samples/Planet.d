
// written in the D programming language

module samples.Planet;

import dchip;

import samples.ChipmunkDemo;

static cpSpace *space;
static cpBody *planetBody;

static cpFloat gravityStrength = 5.0e6f;

static void
update(int ticks)
{
    int steps = 1;
    cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        cpSpaceStep(space, dt);

        // Update the static body spin so that it looks like it's rotating.
        cpBodyUpdatePosition(planetBody, dt);
    }
}

static void
planetGravityVelocityFunc(cpBody *_body, cpVect gravity, cpFloat damping, cpFloat dt)
{
    // Gravitational acceleration is proportional to the inverse square of
    // distance, and directed toward the origin. The central planet is assumed
    // to be massive enough that it affects the satellites but not vice versa.
    cpVect p = _body.p;
    cpFloat sqdist = cpvlengthsq(p);
    cpVect g = cpvmult(p, -gravityStrength / (sqdist * cpfsqrt(sqdist)));

    cpBodyUpdateVelocity(_body, g, damping, dt);
}

static cpVect
rand_pos(cpFloat radius)
{
    cpVect v;
    do {
        v = cpv(frand()*(640 - 2*radius) - (320 - radius), frand()*(480 - 2*radius) - (240 - radius));
    } while(cpvlength(v) < 85.0f);

    return v;
}

static void
add_box()
{
    const cpFloat size = 10.0f;
    const cpFloat mass = 1.0f;

    cpVect verts[] = [
        cpv(-size,-size),
        cpv(-size, size),
        cpv( size, size),
        cpv( size,-size),
    ];

    cpFloat radius = cpvlength(cpv(size, size));

    cpBody *_body = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForPoly(mass, 4, verts.ptr, cpvzero)));
    _body.velocity_func = &planetGravityVelocityFunc;
    _body.p = rand_pos(radius);

    // Set the box's velocity to put it into a circular orbit from its
    // starting position.
    cpFloat r = cpvlength(_body.p);
    cpFloat v = cpfsqrt(gravityStrength / r) / r;
    _body.v = cpvmult(cpvperp(_body.p), v);

    // Set the box's angular velocity to match its orbital period and
    // align its initial angle with its position.
    _body.w = v;
    cpBodySetAngle(_body, cpfatan2(_body.p.y, _body.p.x));

    cpShape *shape = cpSpaceAddShape(space, cpPolyShapeNew(_body, 4, verts.ptr, cpvzero));
    shape.e = 0.0f; shape.u = 0.7f;
}

static cpSpace *
init()
{
    planetBody = cpBodyNew(INFINITY, INFINITY);
    planetBody.w = 0.2f;

    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 20;

    for(int i=0; i<30; i++)
        add_box();

    cpShape *shape = cpSpaceAddShape(space, cpCircleShapeNew(planetBody, 70.0f, cpvzero));
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;

    return space;
}

static void
destroy()
{
    cpBodyFree(planetBody);
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Planet = {
    "Planet",
    null,
    &init,
    &update,
    &destroy,
};
