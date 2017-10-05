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
module dchip.cpBBTree;

import core.stdc.stdlib : qsort;

import dchip.chipmunk;
import dchip.chipmunk_private;
import dchip.chipmunk_types;
import dchip.cpArray;
import dchip.cpBB;
import dchip.cpHashSet;
import dchip.cpSpatialIndex;
import dchip.cpVect;
import dchip.util;

struct cpBBTree
{
    cpSpatialIndex spatialIndex;
    cpBBTreeVelocityFunc velocityFunc;

    cpHashSet* leaves;
    Node* root;

    Node* pooledNodes;
    Pair* pooledPairs;
    cpArray* allocatedBuffers;

    cpTimestamp stamp;
}

struct Node
{
    void* obj;
    cpBB bb;
    Node* parent;

    union UnionNode
    {
        // Internal nodes
        struct Children
        {
            Node* a;
            Node* b;
        }

        Children children;

        // Leaves
        struct Leaf
        {
            cpTimestamp stamp;
            Pair* pairs;
        }

        Leaf leaf;
    }

    UnionNode node;
}

// Can't use anonymous unions and still get good x-compiler compatability
ref A(T)(ref T t) { return t.node.children.a; }
ref B(T)(ref T t) { return t.node.children.b; }

ref STAMP(T)(ref T t) { return t.node.leaf.stamp; }
ref PAIRS(T)(ref T t) { return t.node.leaf.pairs; }

struct Thread
{
    Pair* prev;
    Node* leaf;
    Pair* next;
}

struct Pair
{
    Thread a, b;
    cpCollisionID id;
}

cpBB GetBB(cpBBTree* tree, void* obj)
{
    cpBB bb = tree.spatialIndex.bbfunc(obj);

    cpBBTreeVelocityFunc velocityFunc = tree.velocityFunc;

    if (velocityFunc)
    {
        cpFloat coef = 0.1f;
        cpFloat x    = (bb.r - bb.l) * coef;
        cpFloat y    = (bb.t - bb.b) * coef;

        cpVect v = cpvmult(velocityFunc(obj), 0.1f);
        return cpBBNew(bb.l + cpfmin(-x, v.x), bb.b + cpfmin(-y, v.y), bb.r + cpfmax(x, v.x), bb.t + cpfmax(y, v.y));
    }
    else
    {
        return bb;
    }
}

cpBBTree* GetTree(cpSpatialIndex* index)
{
    return (index && index.klass == Klass() ? cast(cpBBTree*)index : null);
}

Node* GetRootIfTree(cpSpatialIndex* index)
{
    return (index && index.klass == Klass() ? (cast(cpBBTree*)index).root : null);
}

cpBBTree* GetMasterTree(cpBBTree* tree)
{
    cpBBTree* dynamicTree = GetTree(tree.spatialIndex.dynamicIndex);
    return (dynamicTree ? dynamicTree : tree);
}

void IncrementStamp(cpBBTree* tree)
{
    cpBBTree* dynamicTree = GetTree(tree.spatialIndex.dynamicIndex);

    if (dynamicTree)
    {
        dynamicTree.stamp++;
    }
    else
    {
        tree.stamp++;
    }
}

//MARK: Pair/Thread Functions

void PairRecycle(cpBBTree* tree, Pair* pair)
{
    // Share the pool of the master tree.
    // TODO would be lovely to move the pairs stuff into an external data structure.
    tree = GetMasterTree(tree);

    pair.a.next      = tree.pooledPairs;
    tree.pooledPairs = pair;
}

Pair* PairFromPool(cpBBTree* tree)
{
    // Share the pool of the master tree.
    // TODO would be lovely to move the pairs stuff into an external data structure.
    tree = GetMasterTree(tree);

    Pair* pair = tree.pooledPairs;

    if (pair)
    {
        tree.pooledPairs = pair.a.next;
        return pair;
    }
    else
    {
        // Pool is exhausted, make more
        int count = CP_BUFFER_BYTES / Pair.sizeof;
        cpAssertHard(count, "Internal Error: Buffer size is too small.");

        Pair* buffer = cast(Pair*)cpcalloc(1, CP_BUFFER_BYTES);
        cpArrayPush(tree.allocatedBuffers, buffer);

        // push all but the first one, return the first instead
        for (int i = 1; i < count; i++)
            PairRecycle(tree, buffer + i);

        return buffer;
    }
}

void ThreadUnlink(Thread thread)
{
    Pair* next = thread.next;
    Pair* prev = thread.prev;

    if (next)
    {
        if (next.a.leaf == thread.leaf)
            next.a.prev = prev;
        else
            next.b.prev = prev;
    }

    if (prev)
    {
        if (prev.a.leaf == thread.leaf)
            prev.a.next = next;
        else
            prev.b.next = next;
    }
    else
    {
        thread.leaf.PAIRS = next;
    }
}

void PairsClear(Node* leaf, cpBBTree* tree)
{
    Pair* pair = leaf.PAIRS;
    leaf.PAIRS = null;

    while (pair)
    {
        if (pair.a.leaf == leaf)
        {
            Pair* next = pair.a.next;
            ThreadUnlink(pair.b);
            PairRecycle(tree, pair);
            pair = next;
        }
        else
        {
            Pair* next = pair.b.next;
            ThreadUnlink(pair.a);
            PairRecycle(tree, pair);
            pair = next;
        }
    }
}

void PairInsert(Node* a, Node* b, cpBBTree* tree)
{
    Pair* nextA = a.PAIRS;
    Pair* nextB = b.PAIRS;
    Pair* pair  = PairFromPool(tree);
    Pair  temp  = { { null, a, nextA }, { null, b, nextB }, 0 };

    a.PAIRS = b.PAIRS = pair;
    *pair    = temp;

    if (nextA)
    {
        if (nextA.a.leaf == a)
            nextA.a.prev = pair;
        else
            nextA.b.prev = pair;
    }

    if (nextB)
    {
        if (nextB.a.leaf == b)
            nextB.a.prev = pair;
        else
            nextB.b.prev = pair;
    }
}

//MARK: Node Functions

void NodeRecycle(cpBBTree* tree, Node* node)
{
    node.parent      = tree.pooledNodes;
    tree.pooledNodes = node;
}

Node* NodeFromPool(cpBBTree* tree)
{
    Node* node = tree.pooledNodes;

    if (node)
    {
        tree.pooledNodes = node.parent;
        return node;
    }
    else
    {
        // Pool is exhausted, make more
        int count = CP_BUFFER_BYTES / Node.sizeof;
        cpAssertHard(count, "Internal Error: Buffer size is too small.");

        Node* buffer = cast(Node*)cpcalloc(1, CP_BUFFER_BYTES);
        cpArrayPush(tree.allocatedBuffers, buffer);

        // push all but the first one, return the first instead
        for (int i = 1; i < count; i++)
            NodeRecycle(tree, buffer + i);

        return buffer;
    }
}

void NodeSetA(Node* node, Node* value)
{
    node.A       = value;
    value.parent = node;
}

void NodeSetB(Node* node, Node* value)
{
    node.B       = value;
    value.parent = node;
}

Node* NodeNew(cpBBTree* tree, Node* a, Node* b)
{
    Node* node = NodeFromPool(tree);

    node.obj    = null;
    node.bb     = cpBBMerge(a.bb, b.bb);
    node.parent = null;

    NodeSetA(node, a);
    NodeSetB(node, b);

    return node;
}

cpBool NodeIsLeaf(Node* node)
{
    return (node.obj != null);
}

Node* NodeOther(Node* node, Node* child)
{
    return (node.A == child ? node.B : node.A);
}

void NodeReplaceChild(Node* parent, Node* child, Node* value, cpBBTree* tree)
{
    cpAssertSoft(!NodeIsLeaf(parent), "Internal Error: Cannot replace child of a leaf.");
    cpAssertSoft(child == parent.A || child == parent.B, "Internal Error: Node is not a child of parent.");

    if (parent.A == child)
    {
        NodeRecycle(tree, parent.A);
        NodeSetA(parent, value);
    }
    else
    {
        NodeRecycle(tree, parent.B);
        NodeSetB(parent, value);
    }

    for (Node* node = parent; node; node = node.parent)
    {
        node.bb = cpBBMerge(node.A.bb, node.B.bb);
    }
}

//MARK: Subtree Functions

cpFloat cpBBProximity(cpBB a, cpBB b)
{
    return cpfabs(a.l + a.r - b.l - b.r) + cpfabs(a.b + a.t - b.b - b.t);
}

Node* SubtreeInsert(Node* subtree, Node* leaf, cpBBTree* tree)
{
    if (subtree == null)
    {
        return leaf;
    }
    else if (NodeIsLeaf(subtree))
    {
        return NodeNew(tree, leaf, subtree);
    }
    else
    {
        cpFloat cost_a = cpBBArea(subtree.B.bb) + cpBBMergedArea(subtree.A.bb, leaf.bb);
        cpFloat cost_b = cpBBArea(subtree.A.bb) + cpBBMergedArea(subtree.B.bb, leaf.bb);

        if (cost_a == cost_b)
        {
            cost_a = cpBBProximity(subtree.A.bb, leaf.bb);
            cost_b = cpBBProximity(subtree.B.bb, leaf.bb);
        }

        if (cost_b < cost_a)
        {
            NodeSetB(subtree, SubtreeInsert(subtree.B, leaf, tree));
        }
        else
        {
            NodeSetA(subtree, SubtreeInsert(subtree.A, leaf, tree));
        }

        subtree.bb = cpBBMerge(subtree.bb, leaf.bb);
        return subtree;
    }
}

void SubtreeQuery(Node* subtree, void* obj, cpBB bb, cpSpatialIndexQueryFunc func, void* data)
{
    if (cpBBIntersects(subtree.bb, bb))
    {
        if (NodeIsLeaf(subtree))
        {
            func(obj, subtree.obj, 0, data);
        }
        else
        {
            SubtreeQuery(subtree.A, obj, bb, func, data);
            SubtreeQuery(subtree.B, obj, bb, func, data);
        }
    }
}

cpFloat SubtreeSegmentQuery(Node* subtree, void* obj, cpVect a, cpVect b, cpFloat t_exit, cpSpatialIndexSegmentQueryFunc func, void* data)
{
    if (NodeIsLeaf(subtree))
    {
        return func(obj, subtree.obj, data);
    }
    else
    {
        cpFloat t_a = cpBBSegmentQuery(subtree.A.bb, a, b);
        cpFloat t_b = cpBBSegmentQuery(subtree.B.bb, a, b);

        if (t_a < t_b)
        {
            if (t_a < t_exit)
                t_exit = cpfmin(t_exit, SubtreeSegmentQuery(subtree.A, obj, a, b, t_exit, func, data));

            if (t_b < t_exit)
                t_exit = cpfmin(t_exit, SubtreeSegmentQuery(subtree.B, obj, a, b, t_exit, func, data));
        }
        else
        {
            if (t_b < t_exit)
                t_exit = cpfmin(t_exit, SubtreeSegmentQuery(subtree.B, obj, a, b, t_exit, func, data));

            if (t_a < t_exit)
                t_exit = cpfmin(t_exit, SubtreeSegmentQuery(subtree.A, obj, a, b, t_exit, func, data));
        }

        return t_exit;
    }
}

void SubtreeRecycle(cpBBTree* tree, Node* node)
{
    if (!NodeIsLeaf(node))
    {
        SubtreeRecycle(tree, node.A);
        SubtreeRecycle(tree, node.B);
        NodeRecycle(tree, node);
    }
}

Node* SubtreeRemove(Node* subtree, Node* leaf, cpBBTree* tree)
{
    if (leaf == subtree)
    {
        return null;
    }
    else
    {
        Node* parent = leaf.parent;

        if (parent == subtree)
        {
            Node* other = NodeOther(subtree, leaf);
            other.parent = subtree.parent;
            NodeRecycle(tree, subtree);
            return other;
        }
        else
        {
            NodeReplaceChild(parent.parent, parent, NodeOther(parent, leaf), tree);
            return subtree;
        }
    }
}

//MARK: Marking Functions

struct MarkContext
{
    cpBBTree* tree;
    Node* staticRoot;
    cpSpatialIndexQueryFunc func;
    void* data;
}

void MarkLeafQuery(Node* subtree, Node* leaf, cpBool left, MarkContext* context)
{
    if (cpBBIntersects(leaf.bb, subtree.bb))
    {
        if (NodeIsLeaf(subtree))
        {
            if (left)
            {
                PairInsert(leaf, subtree, context.tree);
            }
            else
            {
                if (subtree.STAMP < leaf.STAMP)
                    PairInsert(subtree, leaf, context.tree);
                context.func(leaf.obj, subtree.obj, 0, context.data);
            }
        }
        else
        {
            MarkLeafQuery(subtree.A, leaf, left, context);
            MarkLeafQuery(subtree.B, leaf, left, context);
        }
    }
}

void MarkLeaf(Node* leaf, MarkContext* context)
{
    cpBBTree* tree = context.tree;

    if (leaf.STAMP == GetMasterTree(tree).stamp)
    {
        Node* staticRoot = context.staticRoot;

        if (staticRoot)
            MarkLeafQuery(staticRoot, leaf, cpFalse, context);

        for (Node* node = leaf; node.parent; node = node.parent)
        {
            if (node == node.parent.A)
            {
                MarkLeafQuery(node.parent.B, leaf, cpTrue, context);
            }
            else
            {
                MarkLeafQuery(node.parent.A, leaf, cpFalse, context);
            }
        }
    }
    else
    {
        Pair* pair = leaf.PAIRS;

        while (pair)
        {
            if (leaf == pair.b.leaf)
            {
                pair.id = context.func(pair.a.leaf.obj, leaf.obj, pair.id, context.data);
                pair     = pair.b.next;
            }
            else
            {
                pair = pair.a.next;
            }
        }
    }
}

void MarkSubtree(Node* subtree, MarkContext* context)
{
    if (NodeIsLeaf(subtree))
    {
        MarkLeaf(subtree, context);
    }
    else
    {
        MarkSubtree(subtree.A, context);
        MarkSubtree(subtree.B, context);         // TODO Force TCO here?
    }
}

//MARK: Leaf Functions

Node* LeafNew(cpBBTree* tree, void* obj, cpBB bb)
{
    Node* node = NodeFromPool(tree);
    node.obj = obj;
    node.bb  = GetBB(tree, obj);

    node.parent = null;
    node.STAMP  = 0;
    node.PAIRS  = null;

    return node;
}

cpBool LeafUpdate(Node* leaf, cpBBTree* tree)
{
    Node* root = tree.root;
    cpBB  bb   = tree.spatialIndex.bbfunc(leaf.obj);

    if (!cpBBContainsBB(leaf.bb, bb))
    {
        leaf.bb = GetBB(tree, leaf.obj);

        root       = SubtreeRemove(root, leaf, tree);
        tree.root = SubtreeInsert(root, leaf, tree);

        PairsClear(leaf, tree);
        leaf.STAMP = GetMasterTree(tree).stamp;

        return cpTrue;
    }
    else
    {
        return cpFalse;
    }
}

cpCollisionID VoidQueryFunc(void* obj1, void* obj2, cpCollisionID id, void* data)
{
    return id;
}

void LeafAddPairs(Node* leaf, cpBBTree* tree)
{
    cpSpatialIndex* dynamicIndex = tree.spatialIndex.dynamicIndex;

    if (dynamicIndex)
    {
        Node* dynamicRoot = GetRootIfTree(dynamicIndex);

        if (dynamicRoot)
        {
            cpBBTree* dynamicTree = GetTree(dynamicIndex);
            MarkContext context   = { dynamicTree, null, null, null };
            MarkLeafQuery(dynamicRoot, leaf, cpTrue, &context);
        }
    }
    else
    {
        Node* staticRoot    = GetRootIfTree(tree.spatialIndex.staticIndex);
        MarkContext context = { tree, staticRoot, &VoidQueryFunc, null };
        MarkLeaf(leaf, &context);
    }
}

cpBBTree* cpBBTreeAlloc()
{
    return cast(cpBBTree*)cpcalloc(1, cpBBTree.sizeof);
}

bool leafSetEql(void* obj, Node* node)
{
    return (obj == node.obj);
}

void* leafSetTrans(void* obj, cpBBTree* tree)
{
    return LeafNew(tree, obj, tree.spatialIndex.bbfunc(obj));
}

cpSpatialIndex* cpBBTreeInit(cpBBTree* tree, cpSpatialIndexBBFunc bbfunc, cpSpatialIndex* staticIndex)
{
    cpSpatialIndexInit(cast(cpSpatialIndex*)tree, Klass(), bbfunc, staticIndex);

    tree.velocityFunc = null;

    tree.leaves = cpHashSetNew(0, safeCast!cpHashSetEqlFunc(&leafSetEql));
    tree.root   = null;

    tree.pooledNodes      = null;
    tree.allocatedBuffers = cpArrayNew(0);

    tree.stamp = 0;

    return cast(cpSpatialIndex*)tree;
}

void cpBBTreeSetVelocityFunc(cpSpatialIndex* index, cpBBTreeVelocityFunc func)
{
    if (index.klass != Klass())
    {
        cpAssertWarn(cpFalse, "Ignoring cpBBTreeSetVelocityFunc() call to non-tree spatial index.");
        return;
    }

    (cast(cpBBTree*)index).velocityFunc = func;
}

cpSpatialIndex* cpBBTreeNew(cpSpatialIndexBBFunc bbfunc, cpSpatialIndex* staticIndex)
{
    return cpBBTreeInit(cpBBTreeAlloc(), bbfunc, staticIndex);
}

void cpBBTreeDestroy(cpBBTree* tree)
{
    cpHashSetFree(tree.leaves);

    if (tree.allocatedBuffers)
        cpArrayFreeEach(tree.allocatedBuffers, &cpfree);
    cpArrayFree(tree.allocatedBuffers);
}

//MARK: Insert/Remove

void cpBBTreeInsert(cpBBTree* tree, void* obj, cpHashValue hashid)
{
    Node* leaf = cast(Node*)cpHashSetInsert(tree.leaves, hashid, obj, tree, safeCast!cpHashSetTransFunc(&leafSetTrans));

    Node* root = tree.root;
    tree.root = SubtreeInsert(root, leaf, tree);

    leaf.STAMP = GetMasterTree(tree).stamp;
    LeafAddPairs(leaf, tree);
    IncrementStamp(tree);
}

void cpBBTreeRemove(cpBBTree* tree, void* obj, cpHashValue hashid)
{
    Node* leaf = cast(Node*)cpHashSetRemove(tree.leaves, hashid, obj);

    tree.root = SubtreeRemove(tree.root, leaf, tree);
    PairsClear(leaf, tree);
    NodeRecycle(tree, leaf);
}

cpBool cpBBTreeContains(cpBBTree* tree, void* obj, cpHashValue hashid)
{
    return (cpHashSetFind(tree.leaves, hashid, obj) != null);
}

//MARK: Reindex

/** Workaround for https://github.com/slembcke/Chipmunk2D/issues/56. */
void LeafUpdateWrap(void* elt, void* data)
{
    LeafUpdate(cast(Node*)elt, cast(cpBBTree*)data);
}

void cpBBTreeReindexQuery(cpBBTree* tree, cpSpatialIndexQueryFunc func, void* data)
{
    if (!tree.root)
        return;

    // LeafUpdate() may modify tree.root. Don't cache it.
    cpHashSetEach(tree.leaves, safeCast!cpHashSetIteratorFunc(&LeafUpdateWrap), tree);

    cpSpatialIndex* staticIndex = tree.spatialIndex.staticIndex;
    Node* staticRoot = (staticIndex && staticIndex.klass == Klass() ? (cast(cpBBTree*)staticIndex).root : null);

    MarkContext context = { tree, staticRoot, func, data };
    MarkSubtree(tree.root, &context);

    if (staticIndex && !staticRoot)
        cpSpatialIndexCollideStatic(cast(cpSpatialIndex*)tree, staticIndex, func, data);

    IncrementStamp(tree);
}

void cpBBTreeReindex(cpBBTree* tree)
{
    cpBBTreeReindexQuery(tree, &VoidQueryFunc, null);
}

void cpBBTreeReindexObject(cpBBTree* tree, void* obj, cpHashValue hashid)
{
    Node* leaf = cast(Node*)cpHashSetFind(tree.leaves, hashid, obj);

    if (leaf)
    {
        if (LeafUpdate(leaf, tree))
            LeafAddPairs(leaf, tree);
        IncrementStamp(tree);
    }
}

//MARK: Query

void cpBBTreeSegmentQuery(cpBBTree* tree, void* obj, cpVect a, cpVect b, cpFloat t_exit, cpSpatialIndexSegmentQueryFunc func, void* data)
{
    Node* root = tree.root;

    if (root)
        SubtreeSegmentQuery(root, obj, a, b, t_exit, func, data);
}

void cpBBTreeQuery(cpBBTree* tree, void* obj, cpBB bb, cpSpatialIndexQueryFunc func, void* data)
{
    if (tree.root)
        SubtreeQuery(tree.root, obj, bb, func, data);
}

int cpBBTreeCount(cpBBTree* tree)
{
    return cpHashSetCount(tree.leaves);
}

struct eachContext
{
    cpSpatialIndexIteratorFunc func;
    void* data;
}

void each_helper(Node* node, eachContext* context)
{
    context.func(node.obj, context.data);
}

void cpBBTreeEach(cpBBTree* tree, cpSpatialIndexIteratorFunc func, void* data)
{
    eachContext context = { func, data };
    cpHashSetEach(tree.leaves, safeCast!cpHashSetIteratorFunc(&each_helper), &context);
}

__gshared cpSpatialIndexClass klass;

void _initModuleCtor_cpBBTree()
{
    klass = cpSpatialIndexClass(
        safeCast!cpSpatialIndexDestroyImpl(&cpBBTreeDestroy),

        safeCast!cpSpatialIndexCountImpl(&cpBBTreeCount),
        safeCast!cpSpatialIndexEachImpl(&cpBBTreeEach),

        safeCast!cpSpatialIndexContainsImpl(&cpBBTreeContains),
        safeCast!cpSpatialIndexInsertImpl(&cpBBTreeInsert),
        safeCast!cpSpatialIndexRemoveImpl(&cpBBTreeRemove),

        safeCast!cpSpatialIndexReindexImpl(&cpBBTreeReindex),
        safeCast!cpSpatialIndexReindexObjectImpl(&cpBBTreeReindexObject),
        safeCast!cpSpatialIndexReindexQueryImpl(&cpBBTreeReindexQuery),

        safeCast!cpSpatialIndexQueryImpl(&cpBBTreeQuery),
        safeCast!cpSpatialIndexSegmentQueryImpl(&cpBBTreeSegmentQuery),
    );
}

cpSpatialIndexClass* Klass()
{
    return &klass;
}

//MARK: Tree Optimization

int cpfcompare(const cpFloat* a, const cpFloat* b)
{
    return (*a < *b ? -1 : (*b < *a ? 1 : 0));
}

void fillNodeArray(Node* node, Node*** cursor)
{
    (**cursor) = node;
    (*cursor)++;
}

Node* partitionNodes(cpBBTree* tree, Node** nodes, int count)
{
    if (count == 1)
    {
        return nodes[0];
    }
    else if (count == 2)
    {
        return NodeNew(tree, nodes[0], nodes[1]);
    }

    // Find the AABB for these nodes
    cpBB bb = nodes[0].bb;

    for (int i = 1; i < count; i++)
        bb = cpBBMerge(bb, nodes[i].bb);

    // Split it on it's longest axis
    cpBool splitWidth = (bb.r - bb.l > bb.t - bb.b);

    // Sort the bounds and use the median as the splitting point
    cpFloat* bounds = cast(cpFloat*)cpcalloc(count * 2, cpFloat.sizeof);

    if (splitWidth)
    {
        for (int i = 0; i < count; i++)
        {
            bounds[2 * i + 0] = nodes[i].bb.l;
            bounds[2 * i + 1] = nodes[i].bb.r;
        }
    }
    else
    {
        for (int i = 0; i < count; i++)
        {
            bounds[2 * i + 0] = nodes[i].bb.b;
            bounds[2 * i + 1] = nodes[i].bb.t;
        }
    }

    alias extern(C) int function(scope const void*, scope const void*) CompareFunc;

    qsort(bounds, count * 2, cpFloat.sizeof, safeCast!CompareFunc(&cpfcompare));
    cpFloat split = (bounds[count - 1] + bounds[count]) * 0.5f;   // use the medain as the split
    cpfree(bounds);

    // Generate the child BBs
    cpBB a = bb, b = bb;

    if (splitWidth)
        a.r = b.l = split;
    else
        a.t = b.b = split;

    // Partition the nodes
    int right = count;

    for (int left = 0; left < right; )
    {
        Node* node = nodes[left];

        if (cpBBMergedArea(node.bb, b) < cpBBMergedArea(node.bb, a))
        {
            //		if(cpBBProximity(node.bb, b) < cpBBProximity(node.bb, a)){
            right--;
            nodes[left]  = nodes[right];
            nodes[right] = node;
        }
        else
        {
            left++;
        }
    }

    if (right == count)
    {
        Node* node = null;

        for (int i = 0; i < count; i++)
            node = SubtreeInsert(node, nodes[i], tree);

        return node;
    }

    // Recurse and build the node!
    return NodeNew(tree,
                   partitionNodes(tree, nodes, right),
                   partitionNodes(tree, nodes + right, count - right)
                   );
}

//void
//cpBBTreeOptimizeIncremental(cpBBTree *tree, int passes)
//{
//	for(int i=0; i<passes; i++){
//		Node *root = tree.root;
//		Node *node = root;
//		int bit = 0;
//		uint path = tree.opath;
//
//		while(!NodeIsLeaf(node)){
//			node = (path&(1<<bit) ? node.a : node.b);
//			bit = (bit + 1)&(sizeof(uint)*8 - 1);
//		}
//
//		root = subtreeRemove(root, node, tree);
//		tree.root = subtreeInsert(root, node, tree);
//	}
//}

void cpBBTreeOptimize(cpSpatialIndex* index)
{
    if (index.klass != &klass)
    {
        cpAssertWarn(cpFalse, "Ignoring cpBBTreeOptimize() call to non-tree spatial index.");
        return;
    }

    cpBBTree* tree = cast(cpBBTree*)index;
    Node* root     = tree.root;

    if (!root)
        return;

    int count     = cpBBTreeCount(tree);
    Node** nodes  = cast(Node**)cpcalloc(count, (Node*).sizeof);
    Node** cursor = nodes;

    cpHashSetEach(tree.leaves, safeCast!cpHashSetIteratorFunc(&fillNodeArray), &cursor);

    SubtreeRecycle(tree, root);
    tree.root = partitionNodes(tree, nodes, count);
    cpfree(nodes);
}

// drey later todo
// version = CHIP_BBTREE_DEBUG_DRAW;
version (CHIP_BBTREE_DEBUG_DRAW)
{
    /+ #include "OpenGL/gl.h"
    #include "OpenGL/glu.h"
    #include <GLUT/glut.h>

    void NodeRender(Node* node, int depth)
    {
        if (!NodeIsLeaf(node) && depth <= 10)
        {
            NodeRender(node.a, depth + 1);
            NodeRender(node.b, depth + 1);
        }

        cpBB bb = node.bb;

        //	GLfloat v = depth/2.0f;
        //	glColor3f(1.0f - v, v, 0.0f);
        glLineWidth(cpfmax(5.0f - depth, 1.0f));
        glBegin(GL_LINES);
        {
            glVertex2f(bb.l, bb.b);
            glVertex2f(bb.l, bb.t);

            glVertex2f(bb.l, bb.t);
            glVertex2f(bb.r, bb.t);

            glVertex2f(bb.r, bb.t);
            glVertex2f(bb.r, bb.b);

            glVertex2f(bb.r, bb.b);
            glVertex2f(bb.l, bb.b);
        };
        glEnd();
    }

    void cpBBTreeRenderDebug(cpSpatialIndex* index)
    {
        if (index.klass != &klass)
        {
            cpAssertWarn(cpFalse, "Ignoring cpBBTreeRenderDebug() call to non-tree spatial index.");
            return;
        }

        cpBBTree* tree = (cpBBTree*)index;

        if (tree.root)
            NodeRender(tree.root, 0);
    } +/
}
