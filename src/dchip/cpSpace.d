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
module dchip.cpSpace;

import std.string;

import dchip.cpArray;
import dchip.cpBB;
import dchip.cpBBTree;
import dchip.cpBody;
import dchip.chipmunk;
import dchip.chipmunk_private;
import dchip.chipmunk_types;
import dchip.cpArbiter;
import dchip.cpConstraint;
import dchip.cpHashSet;
import dchip.cpShape;
import dchip.cpSpaceHash;
import dchip.cpSpaceStep;
import dchip.cpSpatialIndex;
import dchip.cpVect;
import dchip.util;

alias cpSpaceArbiterApplyImpulseFunc = void function(cpArbiter* arb);

/// Basic Unit of Simulation in Chipmunk
struct cpSpace
{
    /// Number of iterations to use in the impulse solver to solve contacts.
    int iterations;

    /// Gravity to pass to rigid bodies when integrating velocity.
    cpVect gravity;

    /// Damping rate expressed as the fraction of velocity bodies retain each second.
    /// A value of 0.9 would mean that each body_'s velocity will drop 10% per second.
    /// The default value is 1.0, meaning no damping is applied.
    /// @note This damping value is different than those of cpDampedSpring and cpDampedRotarySpring.
    cpFloat damping = 0;

    /// Speed threshold for a body_ to be considered idle.
    /// The default value of 0 means to let the space guess a good threshold based on gravity.
    cpFloat idleSpeedThreshold = 0;

    /// Time a group of bodies must remain idle in order to fall asleep.
    /// Enabling sleeping also implicitly enables the the contact graph.
    /// The default value of INFINITY disables the sleeping algorithm.
    cpFloat sleepTimeThreshold = 0;

    /// Amount of encouraged penetration between colliding shapes.
    /// Used to reduce oscillating contacts and keep the collision cache warm.
    /// Defaults to 0.1. If you have poor simulation quality,
    /// increase this number as much as possible without allowing visible amounts of overlap.
    cpFloat collisionSlop = 0;

    /// Determines how fast overlapping shapes are pushed apart.
    /// Expressed as a fraction of the error remaining after each second.
    /// Defaults to pow(1.0 - 0.1, 60.0) meaning that Chipmunk fixes 10% of overlap each frame at 60Hz.
    cpFloat collisionBias = 0;

    /// Number of frames that contact information should persist.
    /// Defaults to 3. There is probably never a reason to change this value.
    cpTimestamp collisionPersistence;

    /// Rebuild the contact graph during each step. Must be enabled to use the cpBodyEachArbiter() function.
    /// Disabled by default for a small performance boost. Enabled implicitly when the sleeping feature is enabled.
    cpBool enableContactGraph;

    /// User definable data pointer.
    /// Generally this points to your game's controller or game state
    /// class so you can access it when given a cpSpace reference in a callback.
    cpDataPointer data;

    /// The designated static body_ for this space.
    /// You can modify this body_, or replace it with your own static body_.
    /// By default it points to a statically allocated cpBody in the cpSpace struct.
    cpBody* staticBody;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpTimestamp stamp;
    else
        package cpTimestamp stamp;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpFloat curr_dt = 0;
    else
        package cpFloat curr_dt = 0;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * bodies;
    else
        package cpArray * bodies;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * rousedBodies;
    else
        package cpArray * rousedBodies;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * sleepingComponents;
    else
        package cpArray * sleepingComponents;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpSpatialIndex * staticShapes;
    else
        package cpSpatialIndex * staticShapes;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpSpatialIndex * activeShapes;
    else
        package cpSpatialIndex * activeShapes;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * arbiters;
    else
        package cpArray * arbiters;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpContactBufferHeader * contactBuffersHead;
    else
        package cpContactBufferHeader * contactBuffersHead;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpHashSet * cachedArbiters;
    else
        package cpHashSet * cachedArbiters;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * pooledArbiters;
    else
        package cpArray * pooledArbiters;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * constraints;
    else
        package cpArray * constraints;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * allocatedBuffers;
    else
        package cpArray * allocatedBuffers;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        int locked;
    else
        package int locked;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpHashSet * collisionHandlers;
    else
        package cpHashSet * collisionHandlers;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpCollisionHandler defaultHandler;
    else
        package cpCollisionHandler defaultHandler;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpBool skipPostStep;
    else
        package cpBool skipPostStep;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpArray * postStepCallbacks;
    else
        package cpArray * postStepCallbacks;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpBody _staticBody;
    else
        package cpBody _staticBody;
}

mixin template CP_DefineSpaceStructGetter(type, string member, string name)
{
    mixin(q{
        type cpSpaceGet%s(const cpSpace * space) { return cast(typeof(return))space.%s; }
    }.format(name, member));
}

mixin template CP_DefineSpaceStructSetter(type, string member, string name)
{
    mixin(q{
        void cpSpaceSet%s(cpSpace * space, type value) { space.%s = value; }
    }.format(name, member));
}

mixin template CP_DefineSpaceStructProperty(type, string member, string name)
{
    mixin CP_DefineSpaceStructGetter!(type, member, name);
    mixin CP_DefineSpaceStructSetter!(type, member, name);
}

mixin CP_DefineSpaceStructProperty!(int, "iterations", "Iterations");
mixin CP_DefineSpaceStructProperty!(cpVect, "gravity", "Gravity");
mixin CP_DefineSpaceStructProperty!(cpFloat, "damping", "Damping");
mixin CP_DefineSpaceStructProperty!(cpFloat, "idleSpeedThreshold", "IdleSpeedThreshold");
mixin CP_DefineSpaceStructProperty!(cpFloat, "sleepTimeThreshold", "SleepTimeThreshold");
mixin CP_DefineSpaceStructProperty!(cpFloat, "collisionSlop", "CollisionSlop");
mixin CP_DefineSpaceStructProperty!(cpFloat, "collisionBias", "CollisionBias");
mixin CP_DefineSpaceStructProperty!(cpTimestamp, "collisionPersistence", "CollisionPersistence");
mixin CP_DefineSpaceStructProperty!(cpBool, "enableContactGraph", "EnableContactGraph");
mixin CP_DefineSpaceStructProperty!(cpDataPointer, "data", "UserData");
mixin CP_DefineSpaceStructGetter!(cpBody*, "staticBody", "StaticBody");
mixin CP_DefineSpaceStructGetter!(cpFloat, "curr_dt", "CurrentTimeStep");

/// returns true from inside a callback and objects cannot be added/removed.
cpBool cpSpaceIsLocked(cpSpace* space)
{
    return cast(bool)space.locked;
}

/// Post Step callback function type.
alias cpPostStepFunc = void function(cpSpace* space, void* key, void* data);

/// Point query callback function type.
alias cpSpacePointQueryFunc = void function(cpShape* shape, void* data);

/// Nearest point query callback function type.
alias cpSpaceNearestPointQueryFunc = void function(cpShape* shape, cpFloat distance, cpVect point, void* data);

/// Segment query callback function type.
alias cpSpaceSegmentQueryFunc = void function(cpShape* shape, cpFloat t, cpVect n, void* data);

/// Rectangle Query callback function type.
alias cpSpaceBBQueryFunc = void function(cpShape* shape, void* data);

/// Shape query callback function type.
alias cpSpaceShapeQueryFunc = void function(cpShape* shape, cpContactPointSet* points, void* data);

/// Space/body_ iterator callback function type.
alias cpSpaceBodyIteratorFunc = void function(cpBody* bdy, void* data);

/// Space/body_ iterator callback function type.
alias cpSpaceShapeIteratorFunc = void function(cpShape* shape, void* data);

/// Space/constraint iterator callback function type.
alias cpSpaceConstraintIteratorFunc = void function(cpConstraint* constraint, void* data);

// Equal function for arbiterSet.
cpBool arbiterSetEql(cpShape** shapes, cpArbiter* arb)
{
    cpShape* a = shapes[0];
    cpShape* b = shapes[1];

    return ((a == arb.a && b == arb.b) || (b == arb.a && a == arb.b));
}

//MARK: Collision Handler Set HelperFunctions

// Equals function for collisionHandlers.
cpBool handlerSetEql(cpCollisionHandler* check, cpCollisionHandler* pair)
{
    return ((check.a == pair.a && check.b == pair.b) || (check.b == pair.a && check.a == pair.b));
}

// Transformation function for collisionHandlers.
void* handlerSetTrans(cpCollisionHandler* handler, void* unused)
{
    cpCollisionHandler* copy = cast(cpCollisionHandler*)cpcalloc(1, cpCollisionHandler.sizeof);
    (*copy) = (*handler);

    return copy;
}

//MARK: Misc Helper Funcs

// Default collision functions.
cpBool alwaysCollide(cpArbiter* arb, cpSpace* space, void* data)
{
    return 1;
}

void nothing(cpArbiter* arb, cpSpace* space, void* data)
{
}

// function to get the estimated velocity of a shape for the cpBBTree.
cpVect shapeVelocityFunc(cpShape* shape)
{
    return shape.body_.v;
}

//MARK: Memory Management Functions

cpSpace* cpSpaceAlloc()
{
    return cast(cpSpace*)cpcalloc(1, cpSpace.sizeof);
}

__gshared cpCollisionHandler cpDefaultCollisionHandler = { 0, 0, &alwaysCollide, &alwaysCollide, &nothing, &nothing, null };

cpSpace* cpSpaceInit(cpSpace* space)
{
    version (CHIP_ENABLE_WARNINGS)
    {
        static cpBool done = cpFalse;

        if (!done)
        {
            import std.stdio;
            stderr.writefln("Initializing cpSpace - Chipmunk v%s (Debug Enabled)", cpVersionString);
            stderr.writefln("Compile without the CHIP_ENABLE_WARNINGS to disable debug mode and runtime assertion checks");
            done = cpTrue;
        }
    }

    space.iterations = 10;

    space.gravity = cpvzero;
    space.damping = 1.0f;

    space.collisionSlop        = 0.1f;
    space.collisionBias        = cpfpow(1.0f - 0.1f, 60.0f);
    space.collisionPersistence = 3;

    space.locked = 0;
    space.stamp  = 0;

    space.staticShapes = cpBBTreeNew(cast(cpSpatialIndexBBFunc)&cpShapeGetBB, null);
    space.activeShapes = cpBBTreeNew(cast(cpSpatialIndexBBFunc)&cpShapeGetBB, space.staticShapes);
    cpBBTreeSetVelocityFunc(space.activeShapes, cast(cpBBTreeVelocityFunc)&shapeVelocityFunc);

    space.allocatedBuffers = cpArrayNew(0);

    space.bodies = cpArrayNew(0);
    space.sleepingComponents = cpArrayNew(0);
    space.rousedBodies       = cpArrayNew(0);

    space.sleepTimeThreshold = INFINITY;
    space.idleSpeedThreshold = 0.0f;
    space.enableContactGraph = cpFalse;

    space.arbiters       = cpArrayNew(0);
    space.pooledArbiters = cpArrayNew(0);

    space.contactBuffersHead = null;
    space.cachedArbiters     = cpHashSetNew(0, cast(cpHashSetEqlFunc)&arbiterSetEql);

    space.constraints = cpArrayNew(0);

    space.defaultHandler    = cpDefaultCollisionHandler;
    space.collisionHandlers = cpHashSetNew(0, cast(cpHashSetEqlFunc)&handlerSetEql);
    cpHashSetSetDefaultValue(space.collisionHandlers, &cpDefaultCollisionHandler);

    space.postStepCallbacks = cpArrayNew(0);
    space.skipPostStep      = cpFalse;

    cpBodyInitStatic(&space._staticBody);
    space.staticBody = &space._staticBody;

    return space;
}

cpSpace* cpSpaceNew()
{
    return cpSpaceInit(cpSpaceAlloc());
}

extern(C) void cpConstraintFreeWrap(void* constraint)
{
    cpConstraintFree(cast(cpConstraint*)constraint);
}

/** Workarounds for https://github.com/slembcke/Chipmunk2D/issues/56. */
void freeWrap(void *ptr, void *unused) { cpfree(ptr); }
void shapeFreeWrap(void *ptr, void *unused) { cpShapeFree(cast(cpShape*)ptr); }
void bodyFreeWrap(void* ptr, void *unused) { cpBodyFree(cast(cpBody*)ptr); }
void constraintFreeWrap(void* ptr, void *unused) { cpConstraintFree(cast(cpConstraint*)ptr); }

void cpSpaceDestroy(cpSpace* space)
{
    cpSpaceEachBody(space, &cpBodyActivateWrap, null);

    cpSpatialIndexFree(space.staticShapes);
    cpSpatialIndexFree(space.activeShapes);

    cpArrayFree(space.bodies);
    cpArrayFree(space.sleepingComponents);
    cpArrayFree(space.rousedBodies);

    cpArrayFree(space.constraints);

    cpHashSetFree(space.cachedArbiters);

    cpArrayFree(space.arbiters);
    cpArrayFree(space.pooledArbiters);

    if (space.allocatedBuffers)
    {
        cpArrayFreeEach(space.allocatedBuffers, &cpfree);
        cpArrayFree(space.allocatedBuffers);
    }

    if (space.postStepCallbacks)
    {
        cpArrayFreeEach(space.postStepCallbacks, &cpfree);
        cpArrayFree(space.postStepCallbacks);
    }

    if (space.collisionHandlers)
        cpHashSetEach(space.collisionHandlers, &freeWrap, null);
    cpHashSetFree(space.collisionHandlers);
}

void cpSpaceFree(cpSpace* space)
{
    if (space)
    {
        cpSpaceDestroy(space);
        cpfree(space);
    }
}

void cpAssertSpaceUnlocked(S)(S space)
{
    cpAssertHard(!space.locked,
                 "This operation cannot be done safely during a call to cpSpaceStep() or during a query. "~
                 "Put these calls into a post-step callback."
                 );
}

//MARK: Collision Handler Function Management

void cpSpaceAddCollisionHandler(
    cpSpace* space,
    cpCollisionType a, cpCollisionType b,
    cpCollisionBeginFunc begin,
    cpCollisionPreSolveFunc preSolve,
    cpCollisionPostSolveFunc postSolve,
    cpCollisionSeparateFunc separate,
    void* data
    )
{
    cpAssertSpaceUnlocked(space);

    // Remove any old function so the new one will get added.
    cpSpaceRemoveCollisionHandler(space, a, b);

    cpCollisionHandler handler = {
        a, b,
        begin ? begin : &alwaysCollide,
        preSolve ? preSolve : &alwaysCollide,
        postSolve ? postSolve : &nothing,
        separate ? separate : &nothing,
        data
    };

    cpHashSetInsert(space.collisionHandlers, CP_HASH_PAIR(a, b), &handler, null, cast(cpHashSetTransFunc)&handlerSetTrans);
}

void cpSpaceRemoveCollisionHandler(cpSpace* space, cpCollisionType a, cpCollisionType b)
{
    cpAssertSpaceUnlocked(space);

    struct IDS
    {
        cpCollisionType a, b;
    }
    IDS ids = { a, b };
    cpCollisionHandler* old_handler = cast(cpCollisionHandler*)cpHashSetRemove(space.collisionHandlers, CP_HASH_PAIR(a, b), &ids);
    cpfree(old_handler);
}

void cpSpaceSetDefaultCollisionHandler(
    cpSpace* space,
    cpCollisionBeginFunc begin,
    cpCollisionPreSolveFunc preSolve,
    cpCollisionPostSolveFunc postSolve,
    cpCollisionSeparateFunc separate,
    void* data
    )
{
    cpAssertSpaceUnlocked(space);

    cpCollisionHandler handler = {
        0, 0,
        begin ? begin : &alwaysCollide,
        preSolve ? preSolve : &alwaysCollide,
        postSolve ? postSolve : &nothing,
        separate ? separate : &nothing,
        data
    };

    space.defaultHandler = handler;
    cpHashSetSetDefaultValue(space.collisionHandlers, &space.defaultHandler);
}

//MARK: Body, Shape, and Joint Management
cpShape* cpSpaceAddShape(cpSpace* space, cpShape* shape)
{
    cpBody* body_ = shape.body_;

    if (cpBodyIsStatic(body_))
        return cpSpaceAddStaticShape(space, shape);

    cpAssertHard(shape.space != space, "You have already added this shape to this space. You must not add it a second time.");
    cpAssertHard(!shape.space, "You have already added this shape to another space. You cannot add it to a second.");
    cpAssertSpaceUnlocked(space);

    cpBodyActivate(body_);
    cpBodyAddShape(body_, shape);

    cpShapeUpdate(shape, body_.p, body_.rot);
    cpSpatialIndexInsert(space.activeShapes, shape, shape.hashid);
    shape.space = space;

    return shape;
}

cpShape* cpSpaceAddStaticShape(cpSpace* space, cpShape* shape)
{
    cpAssertHard(shape.space != space, "You have already added this shape to this space. You must not add it a second time.");
    cpAssertHard(!shape.space, "You have already added this shape to another space. You cannot add it to a second.");
    cpAssertHard(cpBodyIsRogue(shape.body_), "You are adding a static shape to a dynamic body_. Did you mean to attach it to a static or rogue body_? See the documentation for more information.");
    cpAssertSpaceUnlocked(space);

    cpBody* body_ = shape.body_;
    cpBodyAddShape(body_, shape);
    cpShapeUpdate(shape, body_.p, body_.rot);
    cpSpatialIndexInsert(space.staticShapes, shape, shape.hashid);
    shape.space = space;

    return shape;
}

cpBody* cpSpaceAddBody(cpSpace* space, cpBody* body_)
{
    cpAssertHard(!cpBodyIsStatic(body_), "Do not add static bodies to a space. Static bodies do not move and should not be simulated.");
    cpAssertHard(body_.space != space, "You have already added this body_ to this space. You must not add it a second time.");
    cpAssertHard(!body_.space, "You have already added this body_ to another space. You cannot add it to a second.");
    cpAssertSpaceUnlocked(space);

    cpArrayPush(space.bodies, body_);
    body_.space = space;

    return body_;
}

cpConstraint* cpSpaceAddConstraint(cpSpace* space, cpConstraint* constraint)
{
    cpAssertHard(constraint.space != space, "You have already added this constraint to this space. You must not add it a second time.");
    cpAssertHard(!constraint.space, "You have already added this constraint to another space. You cannot add it to a second.");
    cpAssertHard(constraint.a && constraint.b, "Constraint is attached to a null body_.");
    cpAssertSpaceUnlocked(space);

    cpBodyActivate(constraint.a);
    cpBodyActivate(constraint.b);
    cpArrayPush(space.constraints, constraint);

    // Push onto the heads of the bodies' constraint lists
    cpBody* a = constraint.a;
    cpBody* b = constraint.b;
    constraint.next_a = a.constraintList;
    a.constraintList  = constraint;
    constraint.next_b = b.constraintList;
    b.constraintList  = constraint;
    constraint.space  = space;

    return constraint;
}

struct arbiterFilterContext
{
    cpSpace* space;
    cpBody* body_;
    cpShape* shape;
};

cpBool cachedArbitersFilter(cpArbiter* arb, arbiterFilterContext* context)
{
    cpShape* shape = context.shape;
    cpBody * body_  = context.body_;

    // Match on the filter shape, or if it's null the filter body_
    if (
        (body_ == arb.body_a && (shape == arb.a || shape == null)) ||
        (body_ == arb.body_b && (shape == arb.b || shape == null))
        )
    {
        // Call separate when removing shapes.
        if (shape && arb.state != cpArbiterStateCached)
            cpArbiterCallSeparate(arb, context.space);

        cpArbiterUnthread(arb);
        cpArrayDeleteObj(context.space.arbiters, arb);
        cpArrayPush(context.space.pooledArbiters, arb);

        return cpFalse;
    }

    return cpTrue;
}

void cpSpaceFilterArbiters(cpSpace* space, cpBody* body_, cpShape* filter)
{
    cpSpaceLock(space);
    {
        arbiterFilterContext context = { space, body_, filter };
        cpHashSetFilter(space.cachedArbiters, safeCast!cpHashSetFilterFunc(&cachedArbitersFilter), &context);
    }
    cpSpaceUnlock(space, cpTrue);
}

void cpSpaceRemoveShape(cpSpace* space, cpShape* shape)
{
    cpBody* body_ = shape.body_;

    if (cpBodyIsStatic(body_))
    {
        cpSpaceRemoveStaticShape(space, shape);
    }
    else
    {
        cpAssertHard(cpSpaceContainsShape(space, shape), "Cannot remove a shape that was not added to the space. (Removed twice maybe?)");
        cpAssertSpaceUnlocked(space);

        cpBodyActivate(body_);
        cpBodyRemoveShape(body_, shape);
        cpSpaceFilterArbiters(space, body_, shape);
        cpSpatialIndexRemove(space.activeShapes, shape, shape.hashid);
        shape.space = null;
    }
}

void cpSpaceRemoveStaticShape(cpSpace* space, cpShape* shape)
{
    cpAssertHard(cpSpaceContainsShape(space, shape), "Cannot remove a static or sleeping shape that was not added to the space. (Removed twice maybe?)");
    cpAssertSpaceUnlocked(space);

    cpBody* body_ = shape.body_;

    if (cpBodyIsStatic(body_))
        cpBodyActivateStatic(body_, shape);
    cpBodyRemoveShape(body_, shape);
    cpSpaceFilterArbiters(space, body_, shape);
    cpSpatialIndexRemove(space.staticShapes, shape, shape.hashid);
    shape.space = null;
}

void cpSpaceRemoveBody(cpSpace* space, cpBody* body_)
{
    cpAssertHard(cpSpaceContainsBody(space, body_), "Cannot remove a body_ that was not added to the space. (Removed twice maybe?)");
    cpAssertSpaceUnlocked(space);

    cpBodyActivate(body_);

    //	cpSpaceFilterArbiters(space, body_, null);
    cpArrayDeleteObj(space.bodies, body_);
    body_.space = null;
}

void cpSpaceRemoveConstraint(cpSpace* space, cpConstraint* constraint)
{
    cpAssertHard(cpSpaceContainsConstraint(space, constraint), "Cannot remove a constraint that was not added to the space. (Removed twice maybe?)");
    cpAssertSpaceUnlocked(space);

    cpBodyActivate(constraint.a);
    cpBodyActivate(constraint.b);
    cpArrayDeleteObj(space.constraints, constraint);

    cpBodyRemoveConstraint(constraint.a, constraint);
    cpBodyRemoveConstraint(constraint.b, constraint);
    constraint.space = null;
}

cpBool cpSpaceContainsShape(cpSpace* space, cpShape* shape)
{
    return (shape.space == space);
}

cpBool cpSpaceContainsBody(cpSpace* space, cpBody* body_)
{
    return (body_.space == space);
}

cpBool cpSpaceContainsConstraint(cpSpace* space, cpConstraint* constraint)
{
    return (constraint.space == space);
}

//MARK: Static/rogue body_ conversion.

void cpSpaceConvertBodyToStatic(cpSpace* space, cpBody* body_)
{
    cpAssertHard(!cpBodyIsStatic(body_), "Body is already static.");
    cpAssertHard(cpBodyIsRogue(body_), "Remove the body_ from the space before calling this function.");
    cpAssertSpaceUnlocked(space);

    cpBodySetMass(body_, INFINITY);
    cpBodySetMoment(body_, INFINITY);

    cpBodySetVel(body_, cpvzero);
    cpBodySetAngVel(body_, 0.0f);

    body_.node.idleTime = INFINITY;

    mixin(CP_BODY_FOREACH_SHAPE!("body_", "shape", q{
        cpSpatialIndexRemove(space.activeShapes, shape, shape.hashid);
        cpSpatialIndexInsert(space.staticShapes, shape, shape.hashid);
    }));
}

void cpSpaceConvertBodyToDynamic(cpSpace* space, cpBody* body_, cpFloat m, cpFloat i)
{
    cpAssertHard(cpBodyIsStatic(body_), "Body is already dynamic.");
    cpAssertSpaceUnlocked(space);

    cpBodyActivateStatic(body_, null);

    cpBodySetMass(body_, m);
    cpBodySetMoment(body_, i);

    body_.node.idleTime = 0.0f;
    mixin(CP_BODY_FOREACH_SHAPE!("body_", "shape", q{
        cpSpatialIndexRemove(space.staticShapes, shape, shape.hashid);
        cpSpatialIndexInsert(space.activeShapes, shape, shape.hashid);
    }));
}

//MARK: Iteration

void cpSpaceEachBody(cpSpace* space, cpSpaceBodyIteratorFunc func, void* data)
{
    cpSpaceLock(space);
    {
        cpArray* bodies = space.bodies;

        for (int i = 0; i < bodies.num; i++)
        {
            func(cast(cpBody*)bodies.arr[i], data);
        }

        cpArray* components = space.sleepingComponents;

        for (int i = 0; i < components.num; i++)
        {
            cpBody* root = cast(cpBody*)components.arr[i];

            cpBody* body_ = root;

            while (body_)
            {
                cpBody* next = body_.node.next;
                func(body_, data);
                body_ = next;
            }
        }
    }
    cpSpaceUnlock(space, cpTrue);
}

struct spaceShapeContext
{
    cpSpaceShapeIteratorFunc func;
    void* data;
}

void spaceEachShapeIterator(cpShape* shape, spaceShapeContext* context)
{
    context.func(shape, context.data);
}

void cpSpaceEachShape(cpSpace* space, cpSpaceShapeIteratorFunc func, void* data)
{
    cpSpaceLock(space);
    {
        spaceShapeContext context = { func, data };
        cpSpatialIndexEach(space.activeShapes, safeCast!cpSpatialIndexIteratorFunc(&spaceEachShapeIterator), &context);
        cpSpatialIndexEach(space.staticShapes, safeCast!cpSpatialIndexIteratorFunc(&spaceEachShapeIterator), &context);
    }
    cpSpaceUnlock(space, cpTrue);
}

void cpSpaceEachConstraint(cpSpace* space, cpSpaceConstraintIteratorFunc func, void* data)
{
    cpSpaceLock(space);
    {
        cpArray* constraints = space.constraints;

        for (int i = 0; i < constraints.num; i++)
        {
            func(cast(cpConstraint*)constraints.arr[i], data);
        }
    }
    cpSpaceUnlock(space, cpTrue);
}

//MARK: Spatial Index Management

void updateBBCache(cpShape* shape, void* unused)
{
    cpBody* body_ = shape.body_;
    cpShapeUpdate(shape, body_.p, body_.rot);
}

void cpSpaceReindexStatic(cpSpace* space)
{
    cpAssertHard(!space.locked, "You cannot manually reindex objects while the space is locked. Wait until the current query or step is complete.");

    cpSpatialIndexEach(space.staticShapes, safeCast!cpSpatialIndexIteratorFunc(&updateBBCache), null);
    cpSpatialIndexReindex(space.staticShapes);
}

void cpSpaceReindexShape(cpSpace* space, cpShape* shape)
{
    cpAssertHard(!space.locked, "You cannot manually reindex objects while the space is locked. Wait until the current query or step is complete.");

    cpBody* body_ = shape.body_;
    cpShapeUpdate(shape, body_.p, body_.rot);

    // attempt to rehash the shape in both hashes
    cpSpatialIndexReindexObject(space.activeShapes, shape, shape.hashid);
    cpSpatialIndexReindexObject(space.staticShapes, shape, shape.hashid);
}

void cpSpaceReindexShapesForBody(cpSpace* space, cpBody* body_)
{
    mixin(CP_BODY_FOREACH_SHAPE!("body_", "shape", "cpSpaceReindexShape(space, shape);"));
}

void copyShapes(cpShape* shape, cpSpatialIndex* index)
{
    cpSpatialIndexInsert(index, shape, shape.hashid);
}

void cpSpaceUseSpatialHash(cpSpace* space, cpFloat dim, int count)
{
    cpSpatialIndex* staticShapes = cpSpaceHashNew(dim, count, safeCast!cpSpatialIndexBBFunc(&cpShapeGetBB), null);
    cpSpatialIndex* activeShapes = cpSpaceHashNew(dim, count, safeCast!cpSpatialIndexBBFunc(&cpShapeGetBB), staticShapes);

    cpSpatialIndexEach(space.staticShapes, safeCast!cpSpatialIndexIteratorFunc(&copyShapes), staticShapes);
    cpSpatialIndexEach(space.activeShapes, safeCast!cpSpatialIndexIteratorFunc(&copyShapes), activeShapes);

    cpSpatialIndexFree(space.staticShapes);
    cpSpatialIndexFree(space.activeShapes);

    space.staticShapes = staticShapes;
    space.activeShapes = activeShapes;
}
