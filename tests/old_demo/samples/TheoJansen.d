
// written in the D programming language

module samples.TheoJansen;

import dchip.all;

import samples.ChipmunkDemo;

import gameApp;

import std.math;

enum M_PI = PI;
enum M_PI_2 = PI*0.5f;

static cpSpace *space;

static cpConstraint *motor;

static void
update(int ticks)
{
    cpFloat coef = (2.0f + arrowDirection.y)/3.0f;
    cpFloat rate = arrowDirection.x*10.0f*coef;
    cpSimpleMotorSetRate(motor, rate);
    motor.maxForce = (rate) ? 100000.0f : 0.0f;

    enum int steps = 3;
    enum cpFloat dt = 1.0f/60.0f/cast(cpFloat)steps;

    for(int i=0; i<steps; i++){
        cpSpaceStep(space, dt);
    }
}

static cpFloat seg_radius = 3.0f;

static void
make_leg(cpFloat side, cpFloat offset, cpBody *chassis, cpBody *crank, cpVect anchor)
{
    cpVect a, b;
    cpShape *shape;

    cpFloat leg_mass = 1.0f;

    // make leg
    a = cpvzero, b = cpv(0.0f, side);
    cpBody *upper_leg = cpBodyNew(leg_mass, cpMomentForSegment(leg_mass, a, b));
    upper_leg.p = cpv(offset, 0.0f);
    cpSpaceAddBody(space, upper_leg);
    cpSpaceAddShape(space, cpSegmentShapeNew(upper_leg, a, b, seg_radius));
    cpSpaceAddConstraint(space, cpPivotJointNew2(chassis, upper_leg, cpv(offset, 0.0f), cpvzero));

    // lower leg
    a = cpvzero, b = cpv(0.0f, -1.0f*side);
    cpBody *lower_leg = cpBodyNew(leg_mass, cpMomentForSegment(leg_mass, a, b));
    lower_leg.p = cpv(offset, -side);
    cpSpaceAddBody(space, lower_leg);
    shape = cpSegmentShapeNew(lower_leg, a, b, seg_radius);
    shape.group = 1;
    cpSpaceAddShape(space, shape);
    shape = cpCircleShapeNew(lower_leg, seg_radius*2.0f, b);
    shape.group = 1;
    shape.e = 0.0f; shape.u = 1.0f;
    cpSpaceAddShape(space, shape);
    cpSpaceAddConstraint(space, cpPinJointNew(chassis, lower_leg, cpv(offset, 0.0f), cpvzero));

    cpSpaceAddConstraint(space, cpGearJointNew(upper_leg, lower_leg, 0.0f, 1.0f));

    cpConstraint *constraint;
    cpFloat diag = cpfsqrt(side*side + offset*offset);

    constraint = cpPinJointNew(crank, upper_leg, anchor, cpv(0.0f, side));
    cpPinJointSetDist(constraint, diag);
    cpSpaceAddConstraint(space, constraint);
    constraint = cpPinJointNew(crank, lower_leg, anchor, cpvzero);
    cpPinJointSetDist(constraint, diag);
    cpSpaceAddConstraint(space, constraint);
}

static cpSpace *
init()
{
    space = cpSpaceNew();

    cpResetShapeIdCounter();

    space = cpSpaceNew();
    space.iterations = 20;
    space.gravity = cpv(0,-500);

    cpBody *staticBody = space.staticBody;
    cpShape *shape;
    cpVect a, b;

    // Create segments around the edge of the screen.
    shape = cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(-320,240), 0.0f);
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    cpSpaceAddShape(space, shape);

    shape = cpSegmentShapeNew(staticBody, cpv(320,-240), cpv(320,240), 0.0f);
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    cpSpaceAddShape(space, shape);

    shape = cpSegmentShapeNew(staticBody, cpv(-320,-240), cpv(320,-240), 0.0f);
    shape.e = 1.0f; shape.u = 1.0f;
    shape.layers = NOT_GRABABLE_MASK;
    cpSpaceAddShape(space, shape);

    cpFloat offset = 30.0f;

    // make chassis
    cpFloat chassis_mass = 2.0f;
    a = cpv(-offset, 0.0f), b = cpv(offset, 0.0f);
    cpBody *chassis = cpBodyNew(chassis_mass, cpMomentForSegment(chassis_mass, a, b));
    cpSpaceAddBody(space, chassis);
    shape = cpSegmentShapeNew(chassis, a, b, seg_radius);
    shape.group = 1;
    cpSpaceAddShape(space, shape);

    // make crank
    cpFloat crank_mass = 1.0f;
    cpFloat crank_radius = 13.0f;
    cpBody *crank = cpBodyNew(crank_mass, cpMomentForCircle(crank_mass, crank_radius, 0.0f, cpvzero));
    cpSpaceAddBody(space, crank);
    shape = cpCircleShapeNew(crank, crank_radius, cpvzero);
    shape.group = 1;
    cpSpaceAddShape(space, shape);
    cpSpaceAddConstraint(space, cpPivotJointNew2(chassis, crank, cpvzero, cpvzero));

    cpFloat side = 30.0f;

    int num_legs = 2;
    for(int i=0; i<num_legs; i++){
        make_leg(side,  offset, chassis, crank, cpvmult(cpvforangle(cast(cpFloat)(2*i+0)/cast(cpFloat)num_legs*M_PI), crank_radius));
        make_leg(side, -offset, chassis, crank, cpvmult(cpvforangle(cast(cpFloat)(2*i+1)/cast(cpFloat)num_legs*M_PI), crank_radius));
    }

    motor = cpSimpleMotorNew(chassis, crank, 6.0f);
    cpSpaceAddConstraint(space, motor);

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo TheoJansen = {
    "Theo Jansen Machine",
    null,
    &init,
    &update,
    &destroy,
};
