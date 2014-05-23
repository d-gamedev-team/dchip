
// written in the D programming language

module samples.Query;

import dchip.all;

import samples.ChipmunkDemo;
import gameApp;

import std.math;

static cpSpace *space;

static cpShape *querySeg = null;


static void
update(int ticks)
{
    //messageString[0] = '\0';

    cpVect start = cpvzero;
    cpVect end = /*cpv(0, 85);//*/mousePos;
    cpVect lineEnd = end;

    //{
    //	char infoString[1024];
    //	sprintf(infoString, "Query: Dist(%f) Point%s, ", cpvdist(start, end), cpvstr(end));
    //	strcat(messageString, infoString);
    //}

    cpSegmentQueryInfo info = {};
    if(cpSpaceSegmentQueryFirst(space, start, end, CP_ALL_LAYERS, CP_NO_GROUP, &info)){
        cpVect point = cpSegmentQueryHitPoint(start, end, info);
        lineEnd = cpvadd(point, cpvzero);//cpvmult(info.n, 4.0f));

        //char infoString[1024];
        //sprintf(infoString, "Segment Query: Dist(%f) Normal%s", cpSegmentQueryHitDist(start, end, info), cpvstr(info.n));
        //strcat(messageString, infoString);
    } else {
        //strcat(messageString, "Segment Query (None)");
    }

    cpSegmentShapeSetEndpoints(querySeg, start, lineEnd);
    // force it to update it's collision detection data so it will draw
    cpShapeUpdate(querySeg, cpvzero, cpv(1.0f, 0.0f));

    // normal other stuff.
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

    cpBody *staticBody = space.staticBody;
    cpShape *shape;

    // add a non-collidable segment as a quick and dirty way to draw the query line
    shape = cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpvzero, cpv(100.0f, 0.0f), 4.0f));
    shape.layers = 0;
    querySeg = shape;

    { // add a fat segment
        cpFloat mass = 1.0f;
        cpFloat length = 100.0f;
        cpVect a = cpv(-length/2.0f, 0.0f), b = cpv(length/2.0f, 0.0f);

        cpBody *_body = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForSegment(mass, a, b)));
        _body.p = cpv(0.0f, 100.0f);

        cpSpaceAddShape(space, cpSegmentShapeNew(_body, a, b, 20.0f));
    }

    { // add a static segment
        cpSpaceAddShape(space, cpSegmentShapeNew(staticBody, cpv(0, 300), cpv(300, 0), 0.0f));
    }

    { // add a pentagon
        cpFloat mass = 1.0f;
        const int NUM_VERTS = 5;

        cpVect verts[NUM_VERTS];
        for(int i=0; i<NUM_VERTS; i++){
            cpFloat angle = -2*PI*i/(cast(cpFloat) NUM_VERTS);
            verts[i] = cpv(30*cos(angle), 30*sin(angle));
        }

        cpBody *_body = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForPoly(mass, NUM_VERTS, verts.ptr, cpvzero)));
        _body.p = cpv(50.0f, 50.0f);

        cpSpaceAddShape(space, cpPolyShapeNew(_body, NUM_VERTS, verts.ptr, cpvzero));
    }

    { // add a circle
        cpFloat mass = 1.0f;
        cpFloat r = 20.0f;

        cpBody *_body = cpSpaceAddBody(space, cpBodyNew(mass, cpMomentForCircle(mass, 0.0f, r, cpvzero)));
        _body.p = cpv(100.0f, 100.0f);

        cpSpaceAddShape(space, cpCircleShapeNew(_body, r, cpvzero));
    }

    return space;
}

static void
destroy()
{
    ChipmunkDemoFreeSpaceChildren(space);
    cpSpaceFree(space);
}

chipmunkDemo Query = {
    "Segment Query",
    null,
    &init,
    &update,
    &destroy,
};
