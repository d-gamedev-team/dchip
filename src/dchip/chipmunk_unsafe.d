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
module dchip.chipmunk_unsafe;

import dchip.types;

/// Set the radius of a circle shape.
void cpCircleShapeSetRadius(cpShape* shape, cpFloat radius);

/// Set the offset of a circle shape.
void cpCircleShapeSetOffset(cpShape* shape, cpVect offset);

/// Set the endpoints of a segment shape.
void cpSegmentShapeSetEndpoints(cpShape* shape, cpVect a, cpVect b);

/// Set the radius of a segment shape.
void cpSegmentShapeSetRadius(cpShape* shape, cpFloat radius);

/// Set the vertexes of a poly shape.
void cpPolyShapeSetVerts(cpShape* shape, int numVerts, cpVect* verts, cpVect offset);

/// Set the radius of a poly shape.
void cpPolyShapeSetRadius(cpShape* shape, cpFloat radius);

