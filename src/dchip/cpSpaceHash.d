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
module dchip.cpSpaceHash;

import dchip.cpBB;
import dchip.chipmunk;
import dchip.chipmunk_private;
import dchip.chipmunk_types;
import dchip.cpArray;
import dchip.cpHashSet;
import dchip.prime;
import dchip.cpSpatialIndex;
import dchip.chipmunk_types;
import dchip.cpVect;
import dchip.util;

struct cpSpaceHash
{
    cpSpatialIndex spatialIndex;

    int numcells;
    cpFloat celldim = 0;

    cpSpaceHashBin** table;
    cpHashSet* handleSet;

    cpSpaceHashBin* pooledBins;
    cpArray* pooledHandles;
    cpArray* allocatedBuffers;

    cpTimestamp stamp;
}

struct cpHandle
{
    void* obj;
    int retain;
    cpTimestamp stamp;
}

cpHandle* cpHandleInit(cpHandle* hand, void* obj)
{
    hand.obj    = obj;
    hand.retain = 0;
    hand.stamp  = 0;

    return hand;
}

void cpHandleRetain(cpHandle* hand)
{
    hand.retain++;
}

void cpHandleRelease(cpHandle* hand, cpArray* pooledHandles)
{
    hand.retain--;

    if (hand.retain == 0)
        cpArrayPush(pooledHandles, hand);
}

int handleSetEql(void* obj, cpHandle* hand)
{
    return (obj == hand.obj);
}

void* handleSetTrans(void* obj, cpSpaceHash* hash)
{
    if (hash.pooledHandles.num == 0)
    {
        // handle pool is exhausted, make more
        int count = CP_BUFFER_BYTES / cpHandle.sizeof;
        cpAssertHard(count, "Internal Error: Buffer size is too small.");

        cpHandle* buffer = cast(cpHandle*)cpcalloc(1, CP_BUFFER_BYTES);
        cpArrayPush(hash.allocatedBuffers, buffer);

        for (int i = 0; i < count; i++)
            cpArrayPush(hash.pooledHandles, buffer + i);
    }

    cpHandle* hand = cpHandleInit(cast(cpHandle*)cpArrayPop(hash.pooledHandles), obj);
    cpHandleRetain(hand);

    return hand;
}

struct cpSpaceHashBin
{
    cpHandle* handle;
    cpSpaceHashBin* next;
}

void recycleBin(cpSpaceHash* hash, cpSpaceHashBin* bin)
{
    bin.next        = hash.pooledBins;
    hash.pooledBins = bin;
}

void clearTableCell(cpSpaceHash* hash, int idx)
{
    cpSpaceHashBin* bin = hash.table[idx];

    while (bin)
    {
        cpSpaceHashBin* next = bin.next;

        cpHandleRelease(bin.handle, hash.pooledHandles);
        recycleBin(hash, bin);

        bin = next;
    }

    hash.table[idx] = null;
}

void clearTable(cpSpaceHash* hash)
{
    for (int i = 0; i < hash.numcells; i++)
        clearTableCell(hash, i);
}

// Get a recycled or new bin.
cpSpaceHashBin* getEmptyBin(cpSpaceHash* hash)
{
    cpSpaceHashBin* bin = hash.pooledBins;

    if (bin)
    {
        hash.pooledBins = bin.next;
        return bin;
    }
    else
    {
        // Pool is exhausted, make more
        int count = CP_BUFFER_BYTES / cpSpaceHashBin.sizeof;
        cpAssertHard(count, "Internal Error: Buffer size is too small.");

        cpSpaceHashBin* buffer = cast(cpSpaceHashBin*)cpcalloc(1, CP_BUFFER_BYTES);
        cpArrayPush(hash.allocatedBuffers, buffer);

        // push all but the first one, return the first instead
        for (int i = 1; i < count; i++)
            recycleBin(hash, buffer + i);

        return buffer;
    }
}

cpSpaceHash* cpSpaceHashAlloc()
{
    return cast(cpSpaceHash*)cpcalloc(1, cpSpaceHash.sizeof);
}

// Frees the old table, and allocate a new one.
void cpSpaceHashAllocTable(cpSpaceHash* hash, int numcells)
{
    cpfree(hash.table);

    hash.numcells = numcells;
    hash.table    = cast(cpSpaceHashBin**)cpcalloc(numcells, (cpSpaceHashBin*).sizeof);
}

cpSpatialIndex* cpSpaceHashInit(cpSpaceHash* hash, cpFloat celldim, int numcells, cpSpatialIndexBBFunc bbfunc, cpSpatialIndex* staticIndex)
{
    cpSpatialIndexInit(cast(cpSpatialIndex*)hash, Klass(), bbfunc, staticIndex);

    cpSpaceHashAllocTable(hash, next_prime(numcells));
    hash.celldim = celldim;

    hash.handleSet = cpHashSetNew(0, cast(cpHashSetEqlFunc)&handleSetEql);

    hash.pooledHandles = cpArrayNew(0);

    hash.pooledBins       = null;
    hash.allocatedBuffers = cpArrayNew(0);

    hash.stamp = 1;

    return cast(cpSpatialIndex*)hash;
}

cpSpatialIndex* cpSpaceHashNew(cpFloat celldim, int cells, cpSpatialIndexBBFunc bbfunc, cpSpatialIndex* staticIndex)
{
    return cpSpaceHashInit(cpSpaceHashAlloc(), celldim, cells, bbfunc, staticIndex);
}

void cpSpaceHashDestroy(cpSpaceHash* hash)
{
    if (hash.table)
        clearTable(hash);
    cpfree(hash.table);

    cpHashSetFree(hash.handleSet);

    cpArrayFreeEach(hash.allocatedBuffers, &cpfree);
    cpArrayFree(hash.allocatedBuffers);
    cpArrayFree(hash.pooledHandles);
}

cpBool containsHandle(cpSpaceHashBin* bin, cpHandle* hand)
{
    while (bin)
    {
        if (bin.handle == hand)
            return cpTrue;
        bin = bin.next;
    }

    return cpFalse;
}

// The hash function itself.
cpHashValue hash_func(cpHashValue x, cpHashValue y, cpHashValue n)
{
    return (x * 1640531513uL ^ y * 2654435789uL) % n;
}

// Much faster than (int)floor(f)
// Profiling showed floor() to be a sizable performance hog
int floor_int(cpFloat f)
{
    int i = cast(int)f;
    return (f < 0.0f && f != i ? i - 1 : i);
}

void hashHandle(cpSpaceHash* hash, cpHandle* hand, cpBB bb)
{
    // Find the dimensions in cell coordinates.
    cpFloat dim = hash.celldim;
    int l       = floor_int(bb.l / dim); // Fix by ShiftZ
    int r       = floor_int(bb.r / dim);
    int b       = floor_int(bb.b / dim);
    int t       = floor_int(bb.t / dim);

    int n = hash.numcells;

    for (int i = l; i <= r; i++)
    {
        for (int j = b; j <= t; j++)
        {
            cpHashValue idx     = hash_func(i, j, n);
            cpSpaceHashBin* bin = hash.table[idx];

            // Don't add an object twice to the same cell.
            if (containsHandle(bin, hand))
                continue;

            cpHandleRetain(hand);

            // Insert a new bin for the handle in this cell.
            cpSpaceHashBin* newBin = getEmptyBin(hash);
            newBin.handle   = hand;
            newBin.next     = bin;
            hash.table[idx] = newBin;
        }
    }
}

void cpSpaceHashInsert(cpSpaceHash* hash, void* obj, cpHashValue hashid)
{
    cpHandle* hand = cast(cpHandle*)cpHashSetInsert(hash.handleSet, hashid, obj, hash, cast(cpHashSetTransFunc)&handleSetTrans);
    hashHandle(hash, hand, hash.spatialIndex.bbfunc(obj));
}

void cpSpaceHashRehashObject(cpSpaceHash* hash, void* obj, cpHashValue hashid)
{
    cpHandle* hand = cast(cpHandle*)cpHashSetRemove(hash.handleSet, hashid, obj);

    if (hand)
    {
        hand.obj = null;
        cpHandleRelease(hand, hash.pooledHandles);

        cpSpaceHashInsert(hash, obj, hashid);
    }
}

void rehash_helper(cpHandle* hand, cpSpaceHash* hash)
{
    hashHandle(hash, hand, hash.spatialIndex.bbfunc(hand.obj));
}

void cpSpaceHashRehash(cpSpaceHash* hash)
{
    clearTable(hash);
    cpHashSetEach(hash.handleSet, safeCast!cpHashSetIteratorFunc(&rehash_helper), hash);
}

void cpSpaceHashRemove(cpSpaceHash* hash, void* obj, cpHashValue hashid)
{
    cpHandle* hand = cast(cpHandle*)cpHashSetRemove(hash.handleSet, hashid, obj);

    if (hand)
    {
        hand.obj = null;
        cpHandleRelease(hand, hash.pooledHandles);
    }
}

struct eachContext
{
    cpSpatialIndexIteratorFunc func;
    void* data;
}

void eachHelper(cpHandle* hand, eachContext* context)
{
    context.func(hand.obj, context.data);
}

void cpSpaceHashEach(cpSpaceHash* hash, cpSpatialIndexIteratorFunc func, void* data)
{
    eachContext context = { func, data };
    cpHashSetEach(hash.handleSet, safeCast!cpHashSetIteratorFunc(&eachHelper), &context);
}

void remove_orphaned_handles(cpSpaceHash* hash, cpSpaceHashBin** bin_ptr)
{
    cpSpaceHashBin* bin = *bin_ptr;

    while (bin)
    {
        cpHandle* hand       = bin.handle;
        cpSpaceHashBin* next = bin.next;

        if (!hand.obj)
        {
            // orphaned handle, unlink and recycle the bin
            (*bin_ptr) = bin.next;
            recycleBin(hash, bin);

            cpHandleRelease(hand, hash.pooledHandles);
        }
        else
        {
            bin_ptr = &bin.next;
        }

        bin = next;
    }
}

void query_helper(cpSpaceHash* hash, cpSpaceHashBin** bin_ptr, void* obj, cpSpatialIndexQueryFunc func, void* data)
{
restart:

    for (cpSpaceHashBin * bin = *bin_ptr; bin; bin = bin.next)
    {
        cpHandle* hand = bin.handle;
        void* other    = hand.obj;

        if (hand.stamp == hash.stamp || obj == other)
        {
            continue;
        }
        else if (other)
        {
            func(obj, other, 0, data);
            hand.stamp = hash.stamp;
        }
        else
        {
            // The object for this handle has been removed
            // cleanup this cell and restart the query
            remove_orphaned_handles(hash, bin_ptr);
            goto restart;             // GCC not smart enough/able to tail call an inlined function.
        }
    }
}

void cpSpaceHashQuery(cpSpaceHash* hash, void* obj, cpBB bb, cpSpatialIndexQueryFunc func, void* data)
{
    // Get the dimensions in cell coordinates.
    cpFloat dim = hash.celldim;
    int l       = floor_int(bb.l / dim); // Fix by ShiftZ
    int r       = floor_int(bb.r / dim);
    int b       = floor_int(bb.b / dim);
    int t       = floor_int(bb.t / dim);

    int n = hash.numcells;
    cpSpaceHashBin** table = hash.table;

    // Iterate over the cells and query them.
    for (int i = l; i <= r; i++)
    {
        for (int j = b; j <= t; j++)
        {
            query_helper(hash, &table[hash_func(i, j, n)], obj, func, data);
        }
    }

    hash.stamp++;
}

// Similar to struct eachPair above.
struct queryRehashContext
{
    cpSpaceHash* hash;
    cpSpatialIndexQueryFunc func;
    void* data;
}

// Hashset iterator func used with cpSpaceHashQueryRehash().
void queryRehash_helper(cpHandle* hand, queryRehashContext* context)
{
    cpSpaceHash* hash = context.hash;
    cpSpatialIndexQueryFunc func = context.func;
    void* data = context.data;

    cpFloat dim = hash.celldim;
    int n       = hash.numcells;

    void* obj = hand.obj;
    cpBB  bb  = hash.spatialIndex.bbfunc(obj);

    int l = floor_int(bb.l / dim);
    int r = floor_int(bb.r / dim);
    int b = floor_int(bb.b / dim);
    int t = floor_int(bb.t / dim);

    cpSpaceHashBin** table = hash.table;

    for (int i = l; i <= r; i++)
    {
        for (int j = b; j <= t; j++)
        {
            cpHashValue idx     = hash_func(i, j, n);
            cpSpaceHashBin* bin = table[idx];

            if (containsHandle(bin, hand))
                continue;

            cpHandleRetain(hand);             // this MUST be done first in case the object is removed in func()
            query_helper(hash, &bin, obj, func, data);

            cpSpaceHashBin* newBin = getEmptyBin(hash);
            newBin.handle = hand;
            newBin.next   = bin;
            table[idx]     = newBin;
        }
    }

    // Increment the stamp for each object hashed.
    hash.stamp++;
}

void cpSpaceHashReindexQuery(cpSpaceHash* hash, cpSpatialIndexQueryFunc func, void* data)
{
    clearTable(hash);

    queryRehashContext context = { hash, func, data };
    cpHashSetEach(hash.handleSet, safeCast!cpHashSetIteratorFunc(&queryRehash_helper), &context);

    cpSpatialIndexCollideStatic(cast(cpSpatialIndex*)hash, hash.spatialIndex.staticIndex, func, data);
}

cpFloat segmentQuery_helper(cpSpaceHash* hash, cpSpaceHashBin** bin_ptr, void* obj, cpSpatialIndexSegmentQueryFunc func, void* data)
{
    cpFloat t = 1.0f;

restart:

    for (cpSpaceHashBin * bin = *bin_ptr; bin; bin = bin.next)
    {
        cpHandle* hand = bin.handle;
        void* other    = hand.obj;

        // Skip over certain conditions
        if (hand.stamp == hash.stamp)
        {
            continue;
        }
        else if (other)
        {
            t = cpfmin(t, func(obj, other, data));
            hand.stamp = hash.stamp;
        }
        else
        {
            // The object for this handle has been removed
            // cleanup this cell and restart the query
            remove_orphaned_handles(hash, bin_ptr);
            goto restart;             // GCC not smart enough/able to tail call an inlined function.
        }
    }

    return t;
}

// modified from http://playtechs.blogspot.com/2007/03/raytracing-on-grid.html
void cpSpaceHashSegmentQuery(cpSpaceHash* hash, void* obj, cpVect a, cpVect b, cpFloat t_exit, cpSpatialIndexSegmentQueryFunc func, void* data)
{
    a = cpvmult(a, 1.0f / hash.celldim);
    b = cpvmult(b, 1.0f / hash.celldim);

    int cell_x = floor_int(a.x), cell_y = floor_int(a.y);

    cpFloat t = 0;

    int x_inc, y_inc;
    cpFloat temp_v = 0, temp_h = 0;

    if (b.x > a.x)
    {
        x_inc  = 1;
        temp_h = (cpffloor(a.x + 1.0f) - a.x);
    }
    else
    {
        x_inc  = -1;
        temp_h = (a.x - cpffloor(a.x));
    }

    if (b.y > a.y)
    {
        y_inc  = 1;
        temp_v = (cpffloor(a.y + 1.0f) - a.y);
    }
    else
    {
        y_inc  = -1;
        temp_v = (a.y - cpffloor(a.y));
    }

    // Division by zero is *very* slow on ARM
    cpFloat dx    = cpfabs(b.x - a.x), dy = cpfabs(b.y - a.y);
    cpFloat dt_dx = (dx ? 1.0f / dx : INFINITY), dt_dy = (dy ? 1.0f / dy : INFINITY);

    // fix NANs in horizontal directions
    cpFloat next_h = (temp_h ? temp_h * dt_dx : dt_dx);
    cpFloat next_v = (temp_v ? temp_v * dt_dy : dt_dy);

    int n = hash.numcells;
    cpSpaceHashBin** table = hash.table;

    while (t < t_exit)
    {
        cpHashValue idx = hash_func(cell_x, cell_y, n);
        t_exit = cpfmin(t_exit, segmentQuery_helper(hash, &table[idx], obj, func, data));

        if (next_v < next_h)
        {
            cell_y += y_inc;
            t       = next_v;
            next_v += dt_dy;
        }
        else
        {
            cell_x += x_inc;
            t       = next_h;
            next_h += dt_dx;
        }
    }

    hash.stamp++;
}

void cpSpaceHashResize(cpSpaceHash* hash, cpFloat celldim, int numcells)
{
    if (hash.spatialIndex.klass != Klass())
    {
        cpAssertWarn(cpFalse, "Ignoring cpSpaceHashResize() call to non-cpSpaceHash spatial index.");
        return;
    }

    clearTable(hash);

    hash.celldim = celldim;
    cpSpaceHashAllocTable(hash, next_prime(numcells));
}

int cpSpaceHashCount(cpSpaceHash* hash)
{
    return cpHashSetCount(hash.handleSet);
}

int cpSpaceHashContains(cpSpaceHash* hash, void* obj, cpHashValue hashid)
{
    return cpHashSetFind(hash.handleSet, hashid, obj) != null;
}

__gshared cpSpatialIndexClass klass;

void _initModuleCtor_cpSpaceHash()
{
    klass = cpSpatialIndexClass(
        cast(cpSpatialIndexDestroyImpl)&cpSpaceHashDestroy,

        cast(cpSpatialIndexCountImpl)&cpSpaceHashCount,
        cast(cpSpatialIndexEachImpl)&cpSpaceHashEach,
        cast(cpSpatialIndexContainsImpl)&cpSpaceHashContains,

        cast(cpSpatialIndexInsertImpl)&cpSpaceHashInsert,
        cast(cpSpatialIndexRemoveImpl)&cpSpaceHashRemove,

        cast(cpSpatialIndexReindexImpl)&cpSpaceHashRehash,
        cast(cpSpatialIndexReindexObjectImpl)&cpSpaceHashRehashObject,
        cast(cpSpatialIndexReindexQueryImpl)&cpSpaceHashReindexQuery,

        cast(cpSpatialIndexQueryImpl)&cpSpaceHashQuery,
        cast(cpSpatialIndexSegmentQueryImpl)&cpSpaceHashSegmentQuery,
    );
}

cpSpatialIndexClass* Klass()
{
    return &klass;
}

// drey later todo
// version = CHIP_BBTREE_DEBUG_DRAW;
version (CHIP_BBTREE_DEBUG_DRAW)
{
    /+ #include "OpenGL/gl.h"
    #include "OpenGL/glu.h"
    #include <GLUT/glut.h>

    void cpSpaceHashRenderDebug(cpSpatialIndex* index)
    {
        if (index.klass != &klass)
        {
            cpAssertWarn(cpFalse, "Ignoring cpSpaceHashRenderDebug() call to non-spatial hash spatial index.");
            return;
        }

        cpSpaceHash* hash = (cpSpaceHash*)index;
        cpBB bb = cpBBNew(-320, -240, 320, 240);

        cpFloat dim = hash.celldim;
        int n       = hash.numcells;

        int l = (int)floor(bb.l / dim);
        int r = (int)floor(bb.r / dim);
        int b = (int)floor(bb.b / dim);
        int t = (int)floor(bb.t / dim);

        for (int i = l; i <= r; i++)
        {
            for (int j = b; j <= t; j++)
            {
                int cell_count = 0;

                int index = hash_func(i, j, n);

                for (cpSpaceHashBin* bin = hash.table[index]; bin; bin = bin.next)
                    cell_count++;

                GLfloat v = 1.0f - (GLfloat)cell_count / 10.0f;
                glColor3f(v, v, v);
                glRectf(i * dim, j * dim, (i + 1) * dim, (j + 1) * dim);
            }
        }
    } +/
}
