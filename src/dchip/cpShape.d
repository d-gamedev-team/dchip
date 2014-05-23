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
module dchip.cpShape;

import std.string;

import dchip.cpBB;
import dchip.cpBody;
import dchip.chipmunk;
import dchip.chipmunk_private;
import dchip.chipmunk_types;
import dchip.cpSpace;
import dchip.util;
import dchip.cpVect;

/// The cpShape struct defines the shape of a rigid body_.

/// Nearest point query info struct.
struct cpNearestPointQueryInfo
{
    /// The nearest shape, null if no shape was within range.
    cpShape* shape;

    /// The closest point on the shape's surface. (in world space coordinates)
    cpVect p;

    /// The distance to the point. The distance is negative if the point is inside the shape.
    cpFloat d = 0;

    /// The gradient of the signed distance function.
    /// The same as info.p/info.d, but accurate even for very small values of info.d.
    cpVect g;
}

/// Segment query info struct.
struct cpSegmentQueryInfo
{
    /// The shape that was hit, null if no collision occured.
    cpShape* shape;

    /// The normalized distance along the query segment in the range [0, 1].
    cpFloat t = 0;

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
        /* const */ cpShapeClass * klass;
    else
        package /* const */ cpShapeClass * klass;

    /// The rigid body_ this collision shape is attached to.
    cpBody* body_;

    /// The current bounding box of the shape.
    cpBB bb;

    /// Sensor flag.
    /// Sensor shapes call collision callbacks but don't produce collisions.
    cpBool sensor;

    /// Coefficient of restitution. (elasticity)
    cpFloat e = 0;

    /// Coefficient of friction.
    cpFloat u = 0;

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
        cpShape * next;
    else
        package cpShape * next;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpShape * prev;
    else
        package cpShape * prev;

    version (CHIP_ALLOW_PRIVATE_ACCESS)
        cpHashValue hashid;
    else
        package cpHashValue hashid;
}

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
        void cpShapeSet%s(cpShape * shape, type value)
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

mixin CP_DefineShapeStructGetter!(cpBB, "bb", "BB");
mixin CP_DefineShapeStructProperty!(cpBool, "sensor", "Sensor", cpTrue);
mixin CP_DefineShapeStructProperty!(cpFloat, "e", "Elasticity", cpFalse);
mixin CP_DefineShapeStructProperty!(cpFloat, "u", "Friction", cpTrue);
mixin CP_DefineShapeStructProperty!(cpVect, "surface_v", "SurfaceVelocity", cpTrue);
mixin CP_DefineShapeStructProperty!(cpDataPointer, "data", "UserData", cpFalse);
mixin CP_DefineShapeStructProperty!(cpCollisionType, "collision_type", "CollisionType", cpTrue);
mixin CP_DefineShapeStructProperty!(cpGroup, "group", "Group", cpTrue);
mixin CP_DefineShapeStructProperty!(cpLayers, "layers", "Layers", cpTrue);

mixin template CP_DeclareShapeGetter(type, string struct_, string member, string name)
{
    mixin(q{
        type %sGet%s(const cpShape * shape)
    }.format(struct_, name, member));
}

/// @private
struct cpCircleShape
{
    cpShape shape;

    cpVect c, tc;
    cpFloat r = 0;
}

/// @private
struct cpSegmentShape
{
    cpShape shape;

    cpVect a, b, n;
    cpVect ta, tb, tn;
    cpFloat r = 0;

    cpVect a_tangent, b_tangent;
}

__gshared cpHashValue cpShapeIDCounter = 0;

void cpResetShapeIdCounter()
{
    cpShapeIDCounter = 0;
}

cpShape* cpShapeInit(cpShape* shape, const cpShapeClass* klass, cpBody* body_)
{
    shape.klass = cast(typeof(shape.klass))klass;

    shape.hashid = cpShapeIDCounter;
    cpShapeIDCounter++;

    shape.body_   = body_;
    shape.sensor = 0;

    shape.e         = 0.0f;
    shape.u         = 0.0f;
    shape.surface_v = cpvzero;

    shape.collision_type = 0;
    shape.group  = CP_NO_GROUP;
    shape.layers = CP_ALL_LAYERS;

    shape.data = null;

    shape.space = null;

    shape.next = null;
    shape.prev = null;

    return shape;
}

void cpShapeDestroy(cpShape* shape)
{
    if (shape.klass && shape.klass.destroy)
        shape.klass.destroy(shape);
}

void cpShapeFree(cpShape* shape)
{
    if (shape)
    {
        cpShapeDestroy(shape);
        cpfree(shape);
    }
}

void cpShapeSetBody(cpShape* shape, cpBody* body_)
{
    cpAssertHard(!cpShapeActive(shape), "You cannot change the body_ on an active shape. You must remove the shape from the space before changing the body_.");
    shape.body_ = body_;
}

cpBB cpShapeCacheBB(cpShape* shape)
{
    cpBody* body_ = shape.body_;
    return cpShapeUpdate(shape, body_.p, body_.rot);
}

cpBB cpShapeUpdate(cpShape* shape, cpVect pos, cpVect rot)
{
    return (shape.bb = shape.klass.cacheData(shape, pos, rot));
}

cpBool cpShapePointQuery(cpShape* shape, cpVect p)
{
    cpNearestPointQueryInfo info = { null, cpvzero, INFINITY, cpvzero };
    cpShapeNearestPointQuery(shape, p, &info);

    return (info.d < 0.0f);
}

cpFloat cpShapeNearestPointQuery(cpShape* shape, cpVect p, cpNearestPointQueryInfo* info)
{
    cpNearestPointQueryInfo blank = { null, cpvzero, INFINITY, cpvzero };

    if (info)
    {
        (*info) = blank;
    }
    else
    {
        info = &blank;
    }

    shape.klass.nearestPointQuery(shape, p, info);
    return info.d;
}

cpBool cpShapeSegmentQuery(cpShape* shape, cpVect a, cpVect b, cpSegmentQueryInfo* info)
{
    cpSegmentQueryInfo blank = { null, 1.0f, cpvzero };

    if (info)
    {
        (*info) = blank;
    }
    else
    {
        info = &blank;
    }

    cpNearestPointQueryInfo nearest;
    shape.klass.nearestPointQuery(shape, a, &nearest);

    if (nearest.d <= 0.0)
    {
        info.shape = shape;
        info.t     = 0.0;
        info.n     = cpvnormalize(cpvsub(a, nearest.p));
    }
    else
    {
        shape.klass.segmentQuery(shape, a, b, info);
    }

    return (info.shape != null);
}

cpCircleShape* cpCircleShapeAlloc()
{
    return cast(cpCircleShape*)cpcalloc(1, cpCircleShape.sizeof);
}

cpBB cpCircleShapeCacheData(cpCircleShape* circle, cpVect p, cpVect rot)
{
    cpVect c = circle.tc = cpvadd(p, cpvrotate(circle.c, rot));
    return cpBBNewForCircle(c, circle.r);
}

void cpCicleShapeNearestPointQuery(cpCircleShape* circle, cpVect p, cpNearestPointQueryInfo* info)
{
    cpVect  delta = cpvsub(p, circle.tc);
    cpFloat d     = cpvlength(delta);
    cpFloat r     = circle.r;

    info.shape = cast(cpShape*)circle;
    info.p     = cpvadd(circle.tc, cpvmult(delta, r / d)); // TODO div/0
    info.d     = d - r;

    // Use up for the gradient if the distance is very small.
    info.g = (d > MAGIC_EPSILON ? cpvmult(delta, 1.0f / d) : cpv(0.0f, 1.0f));
}

void cpCircleShapeSegmentQuery(cpCircleShape* circle, cpVect a, cpVect b, cpSegmentQueryInfo* info)
{
    CircleSegmentQuery(cast(cpShape*)circle, circle.tc, circle.r, a, b, info);
}

cpCircleShape* cpCircleShapeInit(cpCircleShape* circle, cpBody* body_, cpFloat radius, cpVect offset)
{
    circle.c = offset;
    circle.r = radius;

    cpShapeInit(cast(cpShape*)circle, &cpCircleShapeClass, body_);

    return circle;
}

cpShape* cpCircleShapeNew(cpBody* body_, cpFloat radius, cpVect offset)
{
    return cast(cpShape*)cpCircleShapeInit(cpCircleShapeAlloc(), body_, radius, offset);
}

cpSegmentShape *
cpSegmentShapeAlloc()
{
    return cast(cpSegmentShape*)cpcalloc(1, cpSegmentShape.sizeof);
}

cpBB cpSegmentShapeCacheData(cpSegmentShape* seg, cpVect p, cpVect rot)
{
    seg.ta = cpvadd(p, cpvrotate(seg.a, rot));
    seg.tb = cpvadd(p, cpvrotate(seg.b, rot));
    seg.tn = cpvrotate(seg.n, rot);

    cpFloat l = 0, r = 0, b = 0, t = 0;

    if (seg.ta.x < seg.tb.x)
    {
        l = seg.ta.x;
        r = seg.tb.x;
    }
    else
    {
        l = seg.tb.x;
        r = seg.ta.x;
    }

    if (seg.ta.y < seg.tb.y)
    {
        b = seg.ta.y;
        t = seg.tb.y;
    }
    else
    {
        b = seg.tb.y;
        t = seg.ta.y;
    }

    cpFloat rad = seg.r;
    return cpBBNew(l - rad, b - rad, r + rad, t + rad);
}

void cpSegmentShapeNearestPointQuery(cpSegmentShape* seg, cpVect p, cpNearestPointQueryInfo* info)
{
    cpVect closest = cpClosetPointOnSegment(p, seg.ta, seg.tb);

    cpVect  delta = cpvsub(p, closest);
    cpFloat d     = cpvlength(delta);
    cpFloat r     = seg.r;
    cpVect  g     = cpvmult(delta, 1.0f / d);

    info.shape = cast(cpShape*)seg;
    info.p     = (d ? cpvadd(closest, cpvmult(g, r)) : closest);
    info.d     = d - r;

    // Use the segment's normal if the distance is very small.
    info.g = (d > MAGIC_EPSILON ? g : seg.n);
}

void cpSegmentShapeSegmentQuery(cpSegmentShape* seg, cpVect a, cpVect b, cpSegmentQueryInfo* info)
{
    cpVect  n = seg.tn;
    cpFloat d = cpvdot(cpvsub(seg.ta, a), n);
    cpFloat r = seg.r;

    cpVect flipped_n  = (d > 0.0f ? cpvneg(n) : n);
    cpVect seg_offset = cpvsub(cpvmult(flipped_n, r), a);

    // Make the endpoints relative to 'a' and move them by the thickness of the segment.
    cpVect seg_a = cpvadd(seg.ta, seg_offset);
    cpVect seg_b = cpvadd(seg.tb, seg_offset);
    cpVect delta = cpvsub(b, a);

    if (cpvcross(delta, seg_a) * cpvcross(delta, seg_b) <= 0.0f)
    {
        cpFloat d_offset = d + (d > 0.0f ? -r : r);
        cpFloat ad       = -d_offset;
        cpFloat bd       = cpvdot(delta, n) - d_offset;

        if (ad * bd < 0.0f)
        {
            info.shape = cast(cpShape*)seg;
            info.t     = ad / (ad - bd);
            info.n     = flipped_n;
        }
    }
    else if (r != 0.0f)
    {
        cpSegmentQueryInfo info1 = { null, 1.0f, cpvzero };
        cpSegmentQueryInfo info2 = { null, 1.0f, cpvzero };
        CircleSegmentQuery(cast(cpShape*)seg, seg.ta, seg.r, a, b, &info1);
        CircleSegmentQuery(cast(cpShape*)seg, seg.tb, seg.r, a, b, &info2);

        if (info1.t < info2.t)
        {
            (*info) = info1;
        }
        else
        {
            (*info) = info2;
        }
    }
}

__gshared cpShapeClass cpSegmentShapeClass;
__gshared cpShapeClass cpCircleShapeClass;

void _initModuleCtor_cpShape()
{
    cpSegmentShapeClass = cpShapeClass(
        CP_SEGMENT_SHAPE,
        cast(cpShapeCacheDataImpl)&cpSegmentShapeCacheData,
        null,
        cast(cpShapeNearestPointQueryImpl)&cpSegmentShapeNearestPointQuery,
        cast(cpShapeSegmentQueryImpl)&cpSegmentShapeSegmentQuery,
    );

    cpCircleShapeClass = cpShapeClass(
        CP_CIRCLE_SHAPE,
        cast(cpShapeCacheDataImpl)&cpCircleShapeCacheData,
        null,
        cast(cpShapeNearestPointQueryImpl)&cpCicleShapeNearestPointQuery,
        cast(cpShapeSegmentQueryImpl)&cpCircleShapeSegmentQuery,
    );
}

cpSegmentShape* cpSegmentShapeInit(cpSegmentShape* seg, cpBody* body_, cpVect a, cpVect b, cpFloat r)
{
    seg.a = a;
    seg.b = b;
    seg.n = cpvperp(cpvnormalize(cpvsub(b, a)));

    seg.r = r;

    seg.a_tangent = cpvzero;
    seg.b_tangent = cpvzero;

    cpShapeInit(cast(cpShape*)seg, &cpSegmentShapeClass, body_);

    return seg;
}

cpShape* cpSegmentShapeNew(cpBody* body_, cpVect a, cpVect b, cpFloat r)
{
    return cast(cpShape*)cpSegmentShapeInit(cpSegmentShapeAlloc(), body_, a, b, r);
}

void cpSegmentShapeSetNeighbors(cpShape* shape, cpVect prev, cpVect next)
{
    cpAssertHard(shape.klass == &cpSegmentShapeClass, "Shape is not a segment shape.");
    cpSegmentShape* seg = cast(cpSegmentShape*)shape;

    seg.a_tangent = cpvsub(prev, seg.a);
    seg.b_tangent = cpvsub(next, seg.b);
}

// Unsafe API (chipmunk_unsafe.h)

void cpCircleShapeSetRadius(cpShape* shape, cpFloat radius)
{
    cpAssertHard(shape.klass == &cpCircleShapeClass, "Shape is not a circle shape.");
    cpCircleShape* circle = cast(cpCircleShape*)shape;

    circle.r = radius;
}

void cpCircleShapeSetOffset(cpShape* shape, cpVect offset)
{
    cpAssertHard(shape.klass == &cpCircleShapeClass, "Shape is not a circle shape.");
    cpCircleShape* circle = cast(cpCircleShape*)shape;

    circle.c = offset;
}

void cpSegmentShapeSetEndpoints(cpShape* shape, cpVect a, cpVect b)
{
    cpAssertHard(shape.klass == &cpSegmentShapeClass, "Shape is not a segment shape.");
    cpSegmentShape* seg = cast(cpSegmentShape*)shape;

    seg.a = a;
    seg.b = b;
    seg.n = cpvperp(cpvnormalize(cpvsub(b, a)));
}

void cpSegmentShapeSetRadius(cpShape* shape, cpFloat radius)
{
    cpAssertHard(shape.klass == &cpSegmentShapeClass, "Shape is not a segment shape.");
    cpSegmentShape* seg = cast(cpSegmentShape*)shape;

    seg.r = radius;
}
