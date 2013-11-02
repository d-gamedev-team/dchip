/*
 * Copyright (c) 2007-2013 Scott Lembcke and Howling Moon Software
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
module demo.ChipmunkDemo;

import dchip;

import core.stdc.stdlib;

import demo.ChipmunkDebugDraw;
import demo.ChipmunkDemoTextSupport;

alias ChipmunkDemoInitFunc = cpSpace* function();
alias ChipmunkDemoUpdateFunc = void function(cpSpace* space, double dt);
alias ChipmunkDemoDrawFunc = void function(cpSpace* space);
alias ChipmunkDemoDestroyFunc = void function(cpSpace* space);

struct ChipmunkDemo
{
    string name;
    double timestep;

    ChipmunkDemoInitFunc initFunc;
    ChipmunkDemoUpdateFunc updateFunc;
    ChipmunkDemoDrawFunc drawFunc;

    ChipmunkDemoDestroyFunc destroyFunc;
}

cpFloat frand()
{
    return cast(cpFloat)rand() / cast(cpFloat)RAND_MAX;
}

cpVect frand_unit_circle()
{
    cpVect v = cpv(frand() * 2.0f - 1.0f, frand() * 2.0f - 1.0f);
    return (cpvlengthsq(v) < 1.0f ? v : frand_unit_circle());
}

void ChipmunkDemoPrintString(Args...)(Args args);

enum GRABABLE_MASK_BIT = (1 << 31);
enum NOT_GRABABLE_MASK = (~GRABABLE_MASK_BIT);

void ChipmunkDemoDefaultDrawImpl(cpSpace* space);
void ChipmunkDemoFreeSpaceChildren(cpSpace* space);

ChipmunkDemo* demos;
int demo_count = 0;
int demo_index = 'a' - 'a';

cpBool paused = cpFalse;
cpBool step   = cpFalse;

cpSpace* space;

double Accumulator = 0.0;
double LastTime    = 0.0;
int ChipmunkDemoTicks     = 0;
double ChipmunkDemoTime;

cpVect ChipmunkDemoMouse;
cpBool ChipmunkDemoRightClick = cpFalse;
cpBool ChipmunkDemoRightDown  = cpFalse;
cpVect ChipmunkDemoKeyboard   = {};

cpBody* mouse_body        = null;
cpConstraint* mouse_joint = null;

string ChipmunkDemoMessageString = null;

cpVect  translate = { 0, 0 };
cpFloat scale = 1.0;

void ShapeFreeWrap(cpSpace* space, cpShape* shape, void* unused)
{
    cpSpaceRemoveShape(space, shape);
    cpShapeFree(shape);
}

void PostShapeFree(cpShape* shape, cpSpace* space)
{
    cpSpaceAddPostStepCallback(space, safeCast!cpPostStepFunc(&ShapeFreeWrap), shape, null);
}

void ConstraintFreeWrap(cpSpace* space, cpConstraint* constraint, void* unused)
{
    cpSpaceRemoveConstraint(space, constraint);
    cpConstraintFree(constraint);
}

void PostConstraintFree(cpConstraint* constraint, cpSpace* space)
{
    cpSpaceAddPostStepCallback(space, safeCast!cpPostStepFunc(&ConstraintFreeWrap), constraint, null);
}

void BodyFreeWrap(cpSpace* space, cpBody* body_, void* unused)
{
    cpSpaceRemoveBody(space, body_);
    cpBodyFree(body_);
}

void PostBodyFree(cpBody* body_, cpSpace* space)
{
    cpSpaceAddPostStepCallback(space, safeCast!cpPostStepFunc(&BodyFreeWrap), body_, null);
}

// Safe and future proof way to remove and free all objects that have been added to the space.
void ChipmunkDemoFreeSpaceChildren(cpSpace* space)
{
    // Must remove these BEFORE freeing the body or you will access dangling pointers.
    cpSpaceEachShape(space, safeCast!cpSpaceShapeIteratorFunc(&PostShapeFree), space);
    cpSpaceEachConstraint(space, safeCast!cpSpaceConstraintIteratorFunc(&PostConstraintFree), space);

    cpSpaceEachBody(space, safeCast!cpSpaceBodyIteratorFunc(&PostBodyFree), space);
}

void ChipmunkDemoDefaultDrawImpl(cpSpace* space)
{
    ChipmunkDebugDrawShapes(space);
    ChipmunkDebugDrawConstraints(space);

    ChipmunkDebugDrawCollisionPoints(space);
}

//~ void DrawInstructions()
//~ {
    //~ ChipmunkDemoTextDrawString(cpv(-300, 220),
                               //~ "Controls:\n"
                               //~ "A - * Switch demos. (return restarts)\n"
                               //~ "Use the mouse to grab objects.\n"
                               //~ );
//~ }

int max_arbiters    = 0;
int max_points      = 0;
int max_constraints = 0;
