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
module dchip.cpSpaceQuery;

import dchip.chipmunk_private;
import dchip.chipmunk_types;
import dchip.cpArbiter;
import dchip.cpBB;
import dchip.cpCollision;
import dchip.cpBody;
import dchip.cpSpace;
import dchip.cpSpaceStep;
import dchip.cpSpatialIndex;
import dchip.cpShape;
import dchip.cpVect;
import dchip.util;

struct PointQueryContext
{
    cpVect point;
    cpLayers layers;
    cpGroup group;
    cpSpacePointQueryFunc func;
    void* data;
}

cpCollisionID PointQuery(PointQueryContext* context, cpShape* shape, cpCollisionID id, void* data)
{
    if (
        !(shape.group && context.group == shape.group) && (context.layers & shape.layers) &&
        cpShapePointQuery(shape, context.point)
        )
    {
        context.func(shape, context.data);
    }

    return id;
}

void cpSpacePointQuery(cpSpace* space, cpVect point, cpLayers layers, cpGroup group, cpSpacePointQueryFunc func, void* data)
{
    PointQueryContext context = { point, layers, group, func, data };
    cpBB bb = cpBBNewForCircle(point, 0.0f);

    cpSpaceLock(space);
    {
        cpSpatialIndexQuery(space.activeShapes, &context, bb, safeCast!cpSpatialIndexQueryFunc(&PointQuery), data);
        cpSpatialIndexQuery(space.staticShapes, &context, bb, safeCast!cpSpatialIndexQueryFunc(&PointQuery), data);
    }
    cpSpaceUnlock(space, cpTrue);
}

void PointQueryFirst(cpShape* shape, cpShape** outShape)
{
    if (!shape.sensor)
        *outShape = shape;
}

cpShape* cpSpacePointQueryFirst(cpSpace* space, cpVect point, cpLayers layers, cpGroup group)
{
    cpShape* shape = null;
    cpSpacePointQuery(space, point, layers, group, safeCast!cpSpacePointQueryFunc(&PointQueryFirst), &shape);

    return shape;
}

//MARK: Nearest Point Query Functions

struct NearestPointQueryContext
{
    cpVect point;
    cpFloat maxDistance = 0;
    cpLayers layers;
    cpGroup group;
    cpSpaceNearestPointQueryFunc func;
}

cpCollisionID NearestPointQuery(NearestPointQueryContext* context, cpShape* shape, cpCollisionID id, void* data)
{
    if (
        !(shape.group && context.group == shape.group) && (context.layers & shape.layers)
        )
    {
        cpNearestPointQueryInfo info;
        cpShapeNearestPointQuery(shape, context.point, &info);

        if (info.shape && info.d < context.maxDistance)
            context.func(shape, info.d, info.p, data);
    }

    return id;
}

void cpSpaceNearestPointQuery(cpSpace* space, cpVect point, cpFloat maxDistance, cpLayers layers, cpGroup group, cpSpaceNearestPointQueryFunc func, void* data)
{
    NearestPointQueryContext context = { point, maxDistance, layers, group, func };
    cpBB bb = cpBBNewForCircle(point, cpfmax(maxDistance, 0.0f));

    cpSpaceLock(space);
    {
        cpSpatialIndexQuery(space.activeShapes, &context, bb, cast(cpSpatialIndexQueryFunc)&NearestPointQuery, data);
        cpSpatialIndexQuery(space.staticShapes, &context, bb, cast(cpSpatialIndexQueryFunc)&NearestPointQuery, data);
    }
    cpSpaceUnlock(space, cpTrue);
}

cpCollisionID NearestPointQueryNearest(NearestPointQueryContext* context, cpShape* shape, cpCollisionID id, cpNearestPointQueryInfo* out_)
{
    if (
        !(shape.group && context.group == shape.group) && (context.layers & shape.layers) && !shape.sensor
        )
    {
        cpNearestPointQueryInfo info;
        cpShapeNearestPointQuery(shape, context.point, &info);

        if (info.d < out_.d)
            (*out_) = info;
    }

    return id;
}

cpShape* cpSpaceNearestPointQueryNearest(cpSpace* space, cpVect point, cpFloat maxDistance, cpLayers layers, cpGroup group, cpNearestPointQueryInfo* out_)
{
    cpNearestPointQueryInfo info = { null, cpvzero, maxDistance, cpvzero };

    if (out_)
    {
        (*out_) = info;
    }
    else
    {
        out_ = &info;
    }

    NearestPointQueryContext context = {
        point, maxDistance,
        layers, group,
        null
    };

    cpBB bb = cpBBNewForCircle(point, cpfmax(maxDistance, 0.0f));
    cpSpatialIndexQuery(space.activeShapes, &context, bb, safeCast!cpSpatialIndexQueryFunc(&NearestPointQueryNearest), out_);
    cpSpatialIndexQuery(space.staticShapes, &context, bb, safeCast!cpSpatialIndexQueryFunc(&NearestPointQueryNearest), out_);

    return out_.shape;
}

//MARK: Segment Query Functions

struct SegmentQueryContext
{
    cpVect start, end;
    cpLayers layers;
    cpGroup group;
    cpSpaceSegmentQueryFunc func;
}

cpFloat SegmentQuery(SegmentQueryContext* context, cpShape* shape, void* data)
{
    cpSegmentQueryInfo info;

    if (
        !(shape.group && context.group == shape.group) && (context.layers & shape.layers) &&
        cpShapeSegmentQuery(shape, context.start, context.end, &info)
        )
    {
        context.func(shape, info.t, info.n, data);
    }

    return 1.0f;
}

void cpSpaceSegmentQuery(cpSpace* space, cpVect start, cpVect end, cpLayers layers, cpGroup group, cpSpaceSegmentQueryFunc func, void* data)
{
    SegmentQueryContext context = {
        start, end,
        layers, group,
        func,
    };

    cpSpaceLock(space);
    {
        cpSpatialIndexSegmentQuery(space.staticShapes, &context, start, end, 1.0f, safeCast!cpSpatialIndexSegmentQueryFunc(&SegmentQuery), data);
        cpSpatialIndexSegmentQuery(space.activeShapes, &context, start, end, 1.0f, safeCast!cpSpatialIndexSegmentQueryFunc(&SegmentQuery), data);
    }
    cpSpaceUnlock(space, cpTrue);
}

cpFloat SegmentQueryFirst(SegmentQueryContext* context, cpShape* shape, cpSegmentQueryInfo* out_)
{
    cpSegmentQueryInfo info;

    if (
        !(shape.group && context.group == shape.group) && (context.layers & shape.layers) &&
        !shape.sensor &&
        cpShapeSegmentQuery(shape, context.start, context.end, &info) &&
        info.t < out_.t
        )
    {
        (*out_) = info;
    }

    return out_.t;
}

cpShape* cpSpaceSegmentQueryFirst(cpSpace* space, cpVect start, cpVect end, cpLayers layers, cpGroup group, cpSegmentQueryInfo* out_)
{
    cpSegmentQueryInfo info = { null, 1.0f, cpvzero };

    if (out_)
    {
        (*out_) = info;
    }
    else
    {
        out_ = &info;
    }

    SegmentQueryContext context = {
        start, end,
        layers, group,
        null
    };

    cpSpatialIndexSegmentQuery(space.staticShapes, &context, start, end, 1.0f, safeCast!cpSpatialIndexSegmentQueryFunc(&SegmentQueryFirst), out_);
    cpSpatialIndexSegmentQuery(space.activeShapes, &context, start, end, out_.t, safeCast!cpSpatialIndexSegmentQueryFunc(&SegmentQueryFirst), out_);

    return out_.shape;
}

//MARK: BB Query Functions

struct BBQueryContext
{
    cpBB bb;
    cpLayers layers;
    cpGroup group;
    cpSpaceBBQueryFunc func;
}

cpCollisionID BBQuery(BBQueryContext* context, cpShape* shape, cpCollisionID id, void* data)
{
    if (
        !(shape.group && context.group == shape.group) && (context.layers & shape.layers) &&
        cpBBIntersects(context.bb, shape.bb)
        )
    {
        context.func(shape, data);
    }

    return id;
}

void cpSpaceBBQuery(cpSpace* space, cpBB bb, cpLayers layers, cpGroup group, cpSpaceBBQueryFunc func, void* data)
{
    BBQueryContext context = { bb, layers, group, func };

    cpSpaceLock(space);
    {
        cpSpatialIndexQuery(space.activeShapes, &context, bb, safeCast!cpSpatialIndexQueryFunc(&BBQuery), data);
        cpSpatialIndexQuery(space.staticShapes, &context, bb, safeCast!cpSpatialIndexQueryFunc(&BBQuery), data);
    }
    cpSpaceUnlock(space, cpTrue);
}

//MARK: Shape Query Functions

struct ShapeQueryContext
{
    cpSpaceShapeQueryFunc func;
    void* data;
    cpBool anyCollision;
}

// Callback from the spatial hash.
cpCollisionID ShapeQuery(cpShape* a, cpShape* b, cpCollisionID id, ShapeQueryContext* context)
{
    // Reject any of the simple cases
    if (
        (a.group && a.group == b.group) ||
        !(a.layers & b.layers) ||
        a == b
        )
        return id;

    cpContact[CP_MAX_CONTACTS_PER_ARBITER] contacts;
    int numContacts = 0;

    // Shape 'a' should have the lower shape type. (required by cpCollideShapes() )
    if (a.klass.type <= b.klass.type)
    {
        numContacts = cpCollideShapes(a, b, &id, contacts.ptr);
    }
    else
    {
        numContacts = cpCollideShapes(b, a, &id, contacts.ptr);

        for (int i = 0; i < numContacts; i++)
            contacts[i].n = cpvneg(contacts[i].n);
    }

    if (numContacts)
    {
        context.anyCollision = !(a.sensor || b.sensor);

        if (context.func)
        {
            cpContactPointSet set;
            set.count = numContacts;

            for (int i = 0; i < set.count; i++)
            {
                set.points[i].point  = contacts[i].p;
                set.points[i].normal = contacts[i].n;
                set.points[i].dist   = contacts[i].dist;
            }

            context.func(b, &set, context.data);
        }
    }

    return id;
}

cpBool cpSpaceShapeQuery(cpSpace* space, cpShape* shape, cpSpaceShapeQueryFunc func, void* data)
{
    cpBody* body_ = shape.body_;
    cpBB bb      = (body_ ? cpShapeUpdate(shape, body_.p, body_.rot) : shape.bb);
    ShapeQueryContext context = { func, data, cpFalse };

    cpSpaceLock(space);
    {
        cpSpatialIndexQuery(space.activeShapes, shape, bb, safeCast!cpSpatialIndexQueryFunc(&ShapeQuery), &context);
        cpSpatialIndexQuery(space.staticShapes, shape, bb, safeCast!cpSpatialIndexQueryFunc(&ShapeQuery), &context);
    }
    cpSpaceUnlock(space, cpTrue);

    return context.anyCollision;
}
