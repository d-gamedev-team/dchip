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
module dchip.space;

import std.string;

import dchip.arbiter;
import dchip.bb;
import dchip.body_;
import dchip.constraint;
import dchip.chipmunk_private;
import dchip.hash_set;
import dchip.shape;
import dchip.space_step;
import dchip.spatial_index;
import dchip.types;
import dchip.vector;

alias cpSpaceArbiterApplyImpulseFunc = void function(cpArbiter* arb);

/// Basic Unit of Simulation in Chipmunk
struct cpSpace
{
    /// Number of iterations to use in the impulse solver to solve contacts.
    int iterations;

    /// Gravity to pass to rigid bodies when integrating velocity.
    cpVect gravity;

    /// Damping rate expressed as the fraction of velocity bodies retain each second.
    /// A value of 0.9 would mean that each body's velocity will drop 10% per second.
    /// The default value is 1.0, meaning no damping is applied.
    /// @note This damping value is different than those of cpDampedSpring and cpDampedRotarySpring.
    cpFloat damping;

    /// Speed threshold for a body to be considered idle.
    /// The default value of 0 means to let the space guess a good threshold based on gravity.
    cpFloat idleSpeedThreshold;

    /// Time a group of bodies must remain idle in order to fall asleep.
    /// Enabling sleeping also implicitly enables the the contact graph.
    /// The default value of INFINITY disables the sleeping algorithm.
    cpFloat sleepTimeThreshold;

    /// Amount of encouraged penetration between colliding shapes.
    /// Used to reduce oscillating contacts and keep the collision cache warm.
    /// Defaults to 0.1. If you have poor simulation quality,
    /// increase this number as much as possible without allowing visible amounts of overlap.
    cpFloat collisionSlop;

    /// Determines how fast overlapping shapes are pushed apart.
    /// Expressed as a fraction of the error remaining after each second.
    /// Defaults to pow(1.0 - 0.1, 60.0) meaning that Chipmunk fixes 10% of overlap each frame at 60Hz.
    cpFloat collisionBias;

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

    /// The designated static body for this space.
    /// You can modify this body, or replace it with your own static body.
    /// By default it points to a statically allocated cpBody in the cpSpace struct.
    cpBody* staticBody;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpTimestamp stamp;
    else
        package cpTimestamp stamp;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpFloat curr_dt;
    else
        package cpFloat curr_dt;

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

/// Allocate a cpSpace.
cpSpace* cpSpaceAlloc();

/// Initialize a cpSpace.
cpSpace* cpSpaceInit(cpSpace* space);

/// Allocate and initialize a cpSpace.
cpSpace* cpSpaceNew();

/// Destroy a cpSpace.
void cpSpaceDestroy(cpSpace* space);

/// Destroy and free a cpSpace.
void cpSpaceFree(cpSpace* space);

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

/// Set a default collision handler for this space.
/// The default collision handler is invoked for each colliding pair of shapes
/// that isn't explicitly handled by a specific collision handler.
/// You can pass NULL for any function you don't want to implement.
void cpSpaceSetDefaultCollisionHandler(
    cpSpace* space,
    cpCollisionBeginFunc begin,
    cpCollisionPreSolveFunc preSolve,
    cpCollisionPostSolveFunc postSolve,
    cpCollisionSeparateFunc separate,
    void* data
    );

/// Set a collision handler to be used whenever the two shapes with the given collision types collide.
/// You can pass NULL for any function you don't want to implement.
void cpSpaceAddCollisionHandler(
    cpSpace* space,
    cpCollisionType a, cpCollisionType b,
    cpCollisionBeginFunc begin,
    cpCollisionPreSolveFunc preSolve,
    cpCollisionPostSolveFunc postSolve,
    cpCollisionSeparateFunc separate,
    void* data
    );

/// Unset a collision handler.
void cpSpaceRemoveCollisionHandler(cpSpace* space, cpCollisionType a, cpCollisionType b);

/// Add a collision shape to the simulation.
/// If the shape is attached to a static body, it will be added as a static shape.
cpShape* cpSpaceAddShape(cpSpace* space, cpShape* shape);

/// Explicity add a shape as a static shape to the simulation.
cpShape* cpSpaceAddStaticShape(cpSpace* space, cpShape* shape);

/// Add a rigid body to the simulation.
cpBody* cpSpaceAddBody(cpSpace* space, cpBody* bdy);

/// Add a constraint to the simulation.
cpConstraint* cpSpaceAddConstraint(cpSpace* space, cpConstraint* constraint);

/// Remove a collision shape from the simulation.
void cpSpaceRemoveShape(cpSpace* space, cpShape* shape);

/// Remove a collision shape added using cpSpaceAddStaticShape() from the simulation.
void cpSpaceRemoveStaticShape(cpSpace* space, cpShape* shape);

/// Remove a rigid body from the simulation.
void cpSpaceRemoveBody(cpSpace* space, cpBody* bdy);

/// Remove a constraint from the simulation.
void cpSpaceRemoveConstraint(cpSpace* space, cpConstraint* constraint);

/// Test if a collision shape has been added to the space.
cpBool cpSpaceContainsShape(cpSpace* space, cpShape* shape);

/// Test if a rigid body has been added to the space.
cpBool cpSpaceContainsBody(cpSpace* space, cpBody* bdy);

/// Test if a constraint has been added to the space.
cpBool cpSpaceContainsConstraint(cpSpace* space, cpConstraint* constraint);

/// Convert a dynamic rogue body to a static one.
/// If the body is active, you must remove it from the space first.
void cpSpaceConvertBodyToStatic(cpSpace* space, cpBody* bdy);

/// Convert a body to a dynamic rogue body.
/// If you want the body to be active after the transition, you must add it to the space also.
void cpSpaceConvertBodyToDynamic(cpSpace* space, cpBody* bdy, cpFloat mass, cpFloat moment);

/// Post Step callback function type.
alias cpPostStepFunc = void function(cpSpace* space, void* key, void* data);

/// Schedule a post-step callback to be called when cpSpaceStep() finishes.
/// You can only register one callback per unique value for @c key.
/// Returns true only if @c key has never been scheduled before.
/// It's possible to pass @c NULL for @c func if you only want to mark @c key as being used.
cpBool cpSpaceAddPostStepCallback(cpSpace* space, cpPostStepFunc func, void* key, void* data);

/// Point query callback function type.
alias cpSpacePointQueryFunc = void function(cpShape* shape, void* data);

/// Query the space at a point and call @c func for each shape found.
void cpSpacePointQuery(cpSpace* space, cpVect point, cpLayers layers, cpGroup group, cpSpacePointQueryFunc func, void* data);

/// Query the space at a point and return the first shape found. Returns NULL if no shapes were found.
cpShape* cpSpacePointQueryFirst(cpSpace* space, cpVect point, cpLayers layers, cpGroup group);

/// Nearest point query callback function type.
alias cpSpaceNearestPointQueryFunc = void function(cpShape* shape, cpFloat distance, cpVect point, void* data);

/// Query the space at a point and call @c func for each shape found.
void cpSpaceNearestPointQuery(cpSpace* space, cpVect point, cpFloat maxDistance, cpLayers layers, cpGroup group, cpSpaceNearestPointQueryFunc func, void* data);

/// Query the space at a point and return the nearest shape found. Returns NULL if no shapes were found.
cpShape* cpSpaceNearestPointQueryNearest(cpSpace* space, cpVect point, cpFloat maxDistance, cpLayers layers, cpGroup group, cpNearestPointQueryInfo* out_);

/// Segment query callback function type.
alias cpSpaceSegmentQueryFunc = void function(cpShape* shape, cpFloat t, cpVect n, void* data);

/// Perform a directed line segment query (like a raycast) against the space calling @c func for each shape intersected.
void cpSpaceSegmentQuery(cpSpace* space, cpVect start, cpVect end, cpLayers layers, cpGroup group, cpSpaceSegmentQueryFunc func, void* data);

/// Perform a directed line segment query (like a raycast) against the space and return the first shape hit. Returns NULL if no shapes were hit.
cpShape* cpSpaceSegmentQueryFirst(cpSpace* space, cpVect start, cpVect end, cpLayers layers, cpGroup group, cpSegmentQueryInfo* out_);

/// Rectangle Query callback function type.
alias cpSpaceBBQueryFunc= void function(cpShape* shape, void* data);

/// Perform a fast rectangle query on the space calling @c func for each shape found.
/// Only the shape's bounding boxes are checked for overlap, not their full shape.
void cpSpaceBBQuery(cpSpace* space, cpBB bb, cpLayers layers, cpGroup group, cpSpaceBBQueryFunc func, void* data);

/// Shape query callback function type.
alias cpSpaceShapeQueryFunc = void function(cpShape* shape, cpContactPointSet* points, void* data);

/// Query a space for any shapes overlapping the given shape and call @c func for each shape found.
cpBool cpSpaceShapeQuery(cpSpace* space, cpShape* shape, cpSpaceShapeQueryFunc func, void* data);

/// Call cpBodyActivate() for any shape that is overlaps the given shape.
void cpSpaceActivateShapesTouchingShape(cpSpace* space, cpShape* shape);

/// Space/body iterator callback function type.
alias cpSpaceBodyIteratorFunc= void function(cpBody* bdy, void* data);

/// Call @c func for each body in the space.
void cpSpaceEachBody(cpSpace* space, cpSpaceBodyIteratorFunc func, void* data);

/// Space/body iterator callback function type.
alias cpSpaceShapeIteratorFunc = void function(cpShape* shape, void* data);

/// Call @c func for each shape in the space.
void cpSpaceEachShape(cpSpace* space, cpSpaceShapeIteratorFunc func, void* data);

/// Space/constraint iterator callback function type.
alias cpSpaceConstraintIteratorFunc = void function(cpConstraint* constraint, void* data);

/// Call @c func for each shape in the space.
void cpSpaceEachConstraint(cpSpace* space, cpSpaceConstraintIteratorFunc func, void* data);

/// Update the collision detection info for the static shapes in the space.
void cpSpaceReindexStatic(cpSpace* space);

/// Update the collision detection data for a specific shape in the space.
void cpSpaceReindexShape(cpSpace* space, cpShape* shape);

/// Update the collision detection data for all shapes attached to a body.
void cpSpaceReindexShapesForBody(cpSpace* space, cpBody* bdy);

/// Switch the space to use a spatial has as it's spatial index.
void cpSpaceUseSpatialHash(cpSpace* space, cpFloat dim, int count);

/// Step the space forward in time by @c dt.
void cpSpaceStep(cpSpace* space, cpFloat dt);
