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
module dchip.shape;

import std.string;

import dchip.bb;
import dchip.body_;
import dchip.space;
import dchip.types;
import dchip.util;
import dchip.vector;

/// The cpShape struct defines the shape of a rigid body.

/// Nearest point query info struct.
struct cpNearestPointQueryInfo
{
    /// The nearest shape, NULL if no shape was within range.
    cpShape* shape;

    /// The closest point on the shape's surface. (in world space coordinates)
    cpVect p;

    /// The distance to the point. The distance is negative if the point is inside the shape.
    cpFloat d;

    /// The gradient of the signed distance function.
    /// The same as info.p/info.d, but accurate even for very small values of info.d.
    cpVect g;
}

/// Segment query info struct.
struct cpSegmentQueryInfo
{
    /// The shape that was hit, NULL if no collision occured.
    cpShape* shape;

    /// The normalized distance along the query segment in the range [0, 1].
    cpFloat t;

    /// The normal of the surface hit.
    cpVect n;
}

/// @private
enum cpShapeType
{
    CP_CIRCLE_SHAPE,
    CP_SEGMENT_SHAPE,
    CP_POLY_SHAPE,
    CP_NUM_SHAPES
}

///
mixin _ExportEnumMembers!cpShapeType;

alias cpShapeCacheDataImpl = cpBB function(cpShape* shape, cpVect p, cpVect rot);
alias cpShapeDestroyImpl = void function(cpShape* shape);
alias cpShapeNearestPointQueryImpl = void function(cpShape* shape, cpVect p, cpNearestPointQueryInfo* info);
alias cpShapeSegmentQueryImpl = void function(cpShape* shape, cpVect a, cpVect b, cpSegmentQueryInfo* info);

/// @private
struct cpShapeClass
{
    cpShapeType type;

    cpShapeCacheDataImpl cacheData;
    cpShapeDestroyImpl destroy;
    cpShapeNearestPointQueryImpl nearestPointQuery;
    cpShapeSegmentQueryImpl segmentQuery;
}

/// Opaque collision shape struct.
struct cpShape
{
    version (CHIP_ALLOW_PRIVATE_ACCESS)
        const cpShapeClass * klass;
    else
        package const cpShapeClass * klass;

    /// The rigid body this collision shape is attached to.
    cpBody* body_;

    /// The current bounding box of the shape.
    cpBB bb;

    /// Sensor flag.
    /// Sensor shapes call collision callbacks but don't produce collisions.
    cpBool sensor;

    /// Coefficient of restitution. (elasticity)
    cpFloat e;

    /// Coefficient of friction.
    cpFloat u;

    /// Surface velocity used when solving for friction.
    cpVect surface_v;

    /// User definable data pointer.
    /// Generally this points to your the game object class so you can access it
    /// when given a cpShape reference in a callback.
    cpDataPointer data;

    /// Collision type of this shape used when picking collision handlers.
    cpCollisionType collision_type;

    /// Group of this shape. Shapes in the same group don't collide.
    cpGroup group;

    // Layer bitmask for this shape. Shapes only collide if the bitwise and of their layers is non-zero.
    cpLayers layers;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpSpace * space;
    else
        package cpSpace * space;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpSpace * next;
    else
        package cpSpace * next;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpSpace * prev;
    else
        package cpSpace * prev;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpHashValue hashid;
    else
        package cpHashValue hashid;
}

/// Destroy a shape.
void cpShapeDestroy(cpShape* shape);

/// Destroy and Free a shape.
void cpShapeFree(cpShape* shape);

/// Update, cache and return the bounding box of a shape based on the body it's attached to.
cpBB cpShapeCacheBB(cpShape* shape);

/// Update, cache and return the bounding box of a shape with an explicit transformation.
cpBB cpShapeUpdate(cpShape* shape, cpVect pos, cpVect rot);

/// Test if a point lies within a shape.
cpBool cpShapePointQuery(cpShape* shape, cpVect p);

/// Perform a nearest point query. It finds the closest point on the surface of shape to a specific point.
/// The value returned is the distance between the points. A negative distance means the point is inside the shape.
cpFloat cpShapeNearestPointQuery(cpShape* shape, cpVect p, cpNearestPointQueryInfo* out_);

/// Perform a segment query against a shape. @c info must be a pointer to a valid cpSegmentQueryInfo structure.
cpBool cpShapeSegmentQuery(cpShape* shape, cpVect a, cpVect b, cpSegmentQueryInfo* info);

/// Get the hit point for a segment query.
cpVect cpSegmentQueryHitPoint(const cpVect start, const cpVect end, const cpSegmentQueryInfo info)
{
    return cpvlerp(start, end, info.t);
}

/// Get the hit distance for a segment query.
cpFloat cpSegmentQueryHitDist(const cpVect start, const cpVect end, const cpSegmentQueryInfo info)
{
    return cpvdist(start, end) * info.t;
}

mixin template CP_DefineShapeStructGetter(type, string member, string name)
{
    mixin(q{
        type cpShapeGet%s(const cpShape * shape) { return cast(typeof(return))shape.%s; }
    }.format(name, member));
}

mixin template CP_DefineShapeStructSetter(type, string member, string name, bool activates)
{
    mixin(q{
        void cpArbiterSet%s(cpShape * shape, type value)
        {
            %s

            shape.%s = value;
        }
    }.format(name, activates ? "if (shape.body_) cpBodyActivate(shape.body_);" : "", member));
}

mixin template CP_DefineShapeStructProperty(type, string member, string name, bool activates)
{
    mixin CP_DefineShapeStructGetter!(type, member, name);
    mixin CP_DefineShapeStructSetter!(type, member, name, activates);
}

mixin CP_DefineShapeStructGetter!(cpSpace*, "space", "Space");

mixin CP_DefineShapeStructGetter!(cpBody*, "body_", "Body");
void cpShapeSetBody(cpShape* shape, cpBody* body_);

mixin CP_DefineShapeStructGetter!(cpBB, "bb", "BB");
mixin CP_DefineShapeStructProperty!(cpBool, "sensor", "Sensor", cpTrue);
mixin CP_DefineShapeStructProperty!(cpFloat, "e", "Elasticity", cpFalse);
mixin CP_DefineShapeStructProperty!(cpFloat, "u", "Friction", cpTrue);
mixin CP_DefineShapeStructProperty!(cpVect, "surface_v", "SurfaceVelocity", cpTrue);
mixin CP_DefineShapeStructProperty!(cpDataPointer, "data", "UserData", cpFalse);
mixin CP_DefineShapeStructProperty!(cpCollisionType, "collision_type", "CollisionType", cpTrue);
mixin CP_DefineShapeStructProperty!(cpGroup, "group", "Group", cpTrue);
mixin CP_DefineShapeStructProperty!(cpLayers, "layers", "Layers", cpTrue);

/// When initializing a shape, it's hash value comes from a counter.
/// Because the hash value may affect iteration order, you can reset the shape ID counter
/// when recreating a space. This will make the simulation be deterministic.
void cpResetShapeIdCounter();

mixin template CP_DeclareShapeGetter(type, string struct_, string member, string name)
{
    mixin(q{
        type %sGet%s(const cpShape * shape)
    }.format(struct_, name, member));
}

//~ #define CP_DeclareShapeGetter(struct, type, name) type struct ## Get ## name(const cpShape * shape)

/// @private
struct cpCircleShape
{
    cpShape shape;

    cpVect c, tc;
    cpFloat r;
}

/// Allocate a circle shape.
cpCircleShape* cpCircleShapeAlloc();

/// Initialize a circle shape.
cpCircleShape* cpCircleShapeInit(cpCircleShape* circle, cpBody* body_, cpFloat radius, cpVect offset);

/// Allocate and initialize a circle shape.
cpShape* cpCircleShapeNew(cpBody* body_, cpFloat radius, cpVect offset);

//~ CP_DeclareShapeGetter(cpCircleShape, cpVect, Offset);
//~ CP_DeclareShapeGetter(cpCircleShape, cpFloat, Radius);

/// @private
struct cpSegmentShape
{
    cpShape shape;

    cpVect a, b, n;
    cpVect ta, tb, tn;
    cpFloat r;

    cpVect a_tangent, b_tangent;
}

/// Allocate a segment shape.
cpSegmentShape* cpSegmentShapeAlloc();

/// Initialize a segment shape.
cpSegmentShape* cpSegmentShapeInit(cpSegmentShape* seg, cpBody* body_, cpVect a, cpVect b, cpFloat radius);

/// Allocate and initialize a segment shape.
cpShape* cpSegmentShapeNew(cpBody* body_, cpVect a, cpVect b, cpFloat radius);

/// Let Chipmunk know about the geometry of adjacent segments to avoid colliding with endcaps.
void cpSegmentShapeSetNeighbors(cpShape* shape, cpVect prev, cpVect next);

//~ CP_DeclareShapeGetter(cpSegmentShape, cpVect, A);
//~ CP_DeclareShapeGetter(cpSegmentShape, cpVect, B);
//~ CP_DeclareShapeGetter(cpSegmentShape, cpVect, Normal);
//~ CP_DeclareShapeGetter(cpSegmentShape, cpFloat, Radius);
