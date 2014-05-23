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
module demo.ChipmunkDebugDraw;

/**
    IMPORTANT - READ ME!

    This file sets up a simple interface that the individual demos can use to get
    a Chipmunk space running and draw what's in it. In order to keep the Chipmunk
    examples clean and simple, they contain no graphics code. All drawing is done
    by accessing the Chipmunk structures at a very low level. It is NOT
    recommended to write a game or application this way as it does not scale
    beyond simple shape drawing and is very dependent on implementation details
    about Chipmunk which may change with little to no warning.
*/

import core.stdc.config;
import core.stdc.stdlib;
import core.stdc.string;

import glad.gl.all;

import demo.dchip;

import demo.ChipmunkDemoShaderSupport;
import demo.types;

const __gshared Color LINE_COLOR = { 200.0f / 255.0f, 210.0f / 255.0f, 230.0f / 255.0f, 1.0f };
const __gshared Color CONSTRAINT_COLOR = { 0.0f, 0.75f, 0.0f, 1.0f };
const __gshared float SHAPE_ALPHA = 1.0f;

__gshared float ChipmunkDebugDrawPointLineScale = 1.0f;
__gshared float ChipmunkDebugDrawOutlineWidth   = 1.0f;

__gshared GLuint program;

__gshared v2f v2f0 = { 0.0f, 0.0f };

__gshared GLuint vao = 0;
__gshared GLuint vbo = 0;

void ChipmunkDebugDrawInit()
{
    // Setup the AA shader.
    GLint vshader = CompileShader(GL_VERTEX_SHADER,
        q{
            #version 110

            attribute vec2 vertex;
            attribute vec2 aa_coord;
            attribute vec4 fill_color;
            attribute vec4 outline_color;

            varying vec2 v_aa_coord;
            varying vec4 v_fill_color;
            varying vec4 v_outline_color;

            void main(){
                // TODO get rid of the GL 2.x matrix bit eventually?
                gl_Position = gl_ModelViewProjectionMatrix * vec4(vertex, 0.0, 1.0);

                v_fill_color = fill_color;
                v_outline_color = outline_color;
                v_aa_coord = aa_coord;
            }
        });

    GLint fshader = CompileShader(GL_FRAGMENT_SHADER,
        q{
            #version 110

            uniform float u_outline_coef;

            varying vec2 v_aa_coord;
            varying vec4 v_fill_color;

            //const vec4 v_fill_color = vec4(0.0, 0.0, 0.0, 1.0);
            varying vec4 v_outline_color;

            float aa_step(float t1, float t2, float f)
            {
                //return step(t2, f);
                return smoothstep(t1, t2, f);
            }

            void main()
            {
                float l = length(v_aa_coord);

                // Different pixel size estimations are handy.
                //float fw = fwidth(l);
                //float fw = length(vec2(dFdx(l), dFdy(l)));
                float fw = length(fwidth(v_aa_coord));

                // Outline width threshold.
                float ow = 1.0 - fw; //*u_outline_coef;

                                    // Fill/outline color.
                float fo_step = aa_step(max(ow - fw, 0.0), ow, l);
                vec4 fo_color = mix(v_fill_color, v_outline_color, fo_step);

                // Use pre-multiplied alpha.
                float alpha = 1.0 - aa_step(1.0 - fw, 1.0, l);
                gl_FragColor = fo_color * (fo_color.a * alpha);

                //gl_FragColor = vec4(vec3(l), 1);
            }
        });

    program = LinkProgram(vshader, fshader);
    CheckGLErrors();

    // Setu VBO and VAO.

    version (OSX)
    {
        glGenVertexArraysAPPLE(1, &vao);
        glBindVertexArrayAPPLE(vao);
    }
    else
    {
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
    }

    glGenBuffers(1, &vbo);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);

    mixin(SET_ATTRIBUTE("program", "Vertex", "vertex", "GL_FLOAT"));
    mixin(SET_ATTRIBUTE("program", "Vertex", "aa_coord", "GL_FLOAT"));
    mixin(SET_ATTRIBUTE("program", "Vertex", "fill_color", "GL_FLOAT"));
    mixin(SET_ATTRIBUTE("program", "Vertex", "outline_color", "GL_FLOAT"));

    glBindBuffer(GL_ARRAY_BUFFER, 0);

    version (OSX)
    {
        glBindVertexArrayAPPLE(0);
    }
    else
    {
        glBindVertexArray(0);
    }

    CheckGLErrors();
}

Color ColorFromHash(cpHashValue hash, float alpha)
{
    c_ulong val = cast(c_ulong)hash;

    // scramble the bits up using Robert Jenkins' 32 bit integer hash function
    val = (val + 0x7ed55d16) + (val << 12);
    val = (val ^ 0xc761c23c) ^ (val >> 19);
    val = (val + 0x165667b1) + (val << 5);
    val = (val + 0xd3a2646c) ^ (val << 9);
    val = (val + 0xfd7046c5) + (val << 3);
    val = (val ^ 0xb55a4f09) ^ (val >> 16);

    GLfloat r = cast(GLfloat)((val >> 0) & 0xFF);
    GLfloat g = cast(GLfloat)((val >> 8) & 0xFF);
    GLfloat b = cast(GLfloat)((val >> 16) & 0xFF);

    GLfloat max       = cast(GLfloat)cpfmax(cpfmax(r, g), b);
    GLfloat min       = cast(GLfloat)cpfmin(cpfmin(r, g), b);
    GLfloat intensity = 0.75f;

    // Saturate and scale the color
    if (min == max)
    {
        return RGBAColor(intensity, 0.0f, 0.0f, alpha);
    }
    else
    {
        GLfloat coef = cast(GLfloat)intensity / (max - min);
        return RGBAColor(
            (r - min) * coef,
            (g - min) * coef,
            (b - min) * coef,
            alpha
            );
    }
}

void glColor_from_color(Color color)
{
    glColor4fv(cast(GLfloat*)&color);
}

Color ColorForShape(cpShape* shape)
{
    if (cpShapeGetSensor(shape))
    {
        return LAColor(1.0f, 0.1f);
    }
    else
    {
        cpBody* body_ = shape.body_;

        if (cpBodyIsSleeping(body_))
        {
            return LAColor(0.2f, 1.0f);
        }
        else if (body_.node.idleTime > shape.space.sleepTimeThreshold)
        {
            return LAColor(0.66f, 1.0f);
        }
        else
        {
            return ColorFromHash(shape.hashid, SHAPE_ALPHA);
        }
    }
}

auto MAX(T)(T a, T b)
{
    return a > b ? a : b;
}

__gshared size_t triangle_capacity = 0;
__gshared GLsizei triangle_count    = 0;
__gshared Triangle* triangle_buffer = null;

Triangle* PushTriangles(size_t count)
{
    if (triangle_count + count > triangle_capacity)
    {
        triangle_capacity += MAX(triangle_capacity, count);
        triangle_buffer    = cast(Triangle*)realloc(triangle_buffer, triangle_capacity * Triangle.sizeof);
    }

    Triangle* buffer = triangle_buffer + triangle_count;
    triangle_count += count;
    return buffer;
}

void ChipmunkDebugDrawCircle(cpVect pos, cpFloat angle, cpFloat radius, Color outlineColor, Color fillColor)
{
    Triangle* triangles = PushTriangles(2);

    cpFloat r = radius + 1.0f / ChipmunkDebugDrawPointLineScale;
    Vertex  a = { { pos.x - r, pos.y - r }, { -1.0, -1.0 }, fillColor, outlineColor };
    Vertex  b = { { pos.x - r, pos.y + r }, { -1.0, 1.0 }, fillColor, outlineColor };
    Vertex  c = { { pos.x + r, pos.y + r }, { 1.0, 1.0 }, fillColor, outlineColor };
    Vertex  d = { { pos.x + r, pos.y - r }, { 1.0, -1.0 }, fillColor, outlineColor };

    Triangle t0 = { a, b, c };
    triangles[0] = t0;
    Triangle t1 = { a, c, d };
    triangles[1] = t1;

    ChipmunkDebugDrawSegment(pos, cpvadd(pos, cpvmult(cpvforangle(angle), radius - ChipmunkDebugDrawPointLineScale * 0.5f)), outlineColor);
}

void ChipmunkDebugDrawSegment(cpVect a, cpVect b, Color color)
{
    ChipmunkDebugDrawFatSegment(a, b, 0.0f, color, color);
}

void ChipmunkDebugDrawFatSegment(cpVect a, cpVect b, cpFloat radius, Color outlineColor, Color fillColor)
{
    Triangle* triangles = PushTriangles(6);

    cpVect n = cpvnormalize(cpvperp(cpvsub(b, a)));
    cpVect t = cpvperp(n);

    cpFloat half = 1.0f / ChipmunkDebugDrawPointLineScale;
    cpFloat r    = radius + half;

    if (r <= half)
    {
        r         = half;
        fillColor = outlineColor;
    }

    cpVect nw     = (cpvmult(n, r));
    cpVect tw     = (cpvmult(t, r));
    v2f v0 = v2f(cpvsub(b, cpvadd(nw, tw))); // { 1.0, -1.0}
    v2f v1 = v2f(cpvadd(b, cpvsub(nw, tw))); // { 1.0,  1.0}
    v2f v2 = v2f(cpvsub(b, nw));             // { 0.0, -1.0}
    v2f v3 = v2f(cpvadd(b, nw));             // { 0.0,  1.0}
    v2f v4 = v2f(cpvsub(a, nw));             // { 0.0, -1.0}
    v2f v5 = v2f(cpvadd(a, nw));             // { 0.0,  1.0}
    v2f v6 = v2f(cpvsub(a, cpvsub(nw, tw))); // {-1.0, -1.0}
    v2f v7 = v2f(cpvadd(a, cpvadd(nw, tw))); // {-1.0,  1.0}

    Triangle t0 = { { v0, { 1.0f, -1.0f }, fillColor, outlineColor }, { v1, { 1.0f, 1.0f }, fillColor, outlineColor }, { v2, { 0.0f, -1.0f }, fillColor, outlineColor } };
    triangles[0] = t0;
    Triangle t1 = { { v3, { 0.0f, 1.0f }, fillColor, outlineColor }, { v1, { 1.0f, 1.0f }, fillColor, outlineColor }, { v2, { 0.0f, -1.0f }, fillColor, outlineColor } };
    triangles[1] = t1;
    Triangle t2 = { { v3, { 0.0f, 1.0f }, fillColor, outlineColor }, { v4, { 0.0f, -1.0f }, fillColor, outlineColor }, { v2, { 0.0f, -1.0f }, fillColor, outlineColor } };
    triangles[2] = t2;
    Triangle t3 = { { v3, { 0.0f, 1.0f }, fillColor, outlineColor }, { v4, { 0.0f, -1.0f }, fillColor, outlineColor }, { v5, { 0.0f, 1.0f }, fillColor, outlineColor } };
    triangles[3] = t3;
    Triangle t4 = { { v6, { -1.0f, -1.0f }, fillColor, outlineColor }, { v4, { 0.0f, -1.0f }, fillColor, outlineColor }, { v5, { 0.0f, 1.0f }, fillColor, outlineColor } };
    triangles[4] = t4;
    Triangle t5 = { { v6, { -1.0f, -1.0f }, fillColor, outlineColor }, { v7, { -1.0f, 1.0f }, fillColor, outlineColor }, { v5, { 0.0f, 1.0f }, fillColor, outlineColor } };
    triangles[5] = t5;
}

void ChipmunkDebugDrawPolygon(int count, cpVect* verts, cpFloat radius, Color outlineColor, Color fillColor)
{
    struct ExtrudeVerts
    {
        cpVect offset, n;
    }

    size_t bytes = ExtrudeVerts.sizeof * count;
    ExtrudeVerts* extrude = cast(ExtrudeVerts*)alloca(bytes);
    memset(extrude, 0, bytes.sizeof);

    for (int i = 0; i < count; i++)
    {
        cpVect v0 = verts[(i - 1 + count) % count];
        cpVect v1 = verts[i];
        cpVect v2 = verts[(i + 1) % count];

        cpVect n1 = cpvnormalize(cpvperp(cpvsub(v1, v0)));
        cpVect n2 = cpvnormalize(cpvperp(cpvsub(v2, v1)));

        cpVect offset         = cpvmult(cpvadd(n1, n2), 1.0 / (cpvdot(n1, n2) + 1.0f));
        ExtrudeVerts v = { offset, n2 };
        extrude[i] = v;
    }

    //	Triangle *triangles = PushTriangles(6*count);
    Triangle* triangles = PushTriangles(5 * count - 2);
    Triangle* cursor    = triangles;

    cpFloat inset = cpfmax(0.0f, 1.0f / ChipmunkDebugDrawPointLineScale - radius);

    for (int i = 0; i < count - 2; i++)
    {
        v2f v0 = v2f(cpvsub(verts[0], cpvmult(extrude[0].offset, inset)));
        v2f v1 = v2f(cpvsub(verts[i + 1], cpvmult(extrude[i + 1].offset, inset)));
        v2f v2 = v2f(cpvsub(verts[i + 2], cpvmult(extrude[i + 2].offset, inset)));

        Triangle t = { { v0, v2f0, fillColor, fillColor }, { v1, v2f0, fillColor, fillColor }, { v2, v2f0, fillColor, fillColor } };
        *cursor++ = t;
    }

    cpFloat outset = inset + 1.0f / ChipmunkDebugDrawPointLineScale + radius;

    for (int i = 0, j = count - 1; i < count; j = i, i++)
    {
        cpVect vA = verts[i];
        cpVect vB = verts[j];

        cpVect nA = extrude[i].n;
        cpVect nB = extrude[j].n;

        cpVect offsetA = extrude[i].offset;
        cpVect offsetB = extrude[j].offset;

        cpVect innerA = cpvsub(vA, cpvmult(offsetA, inset));
        cpVect innerB = cpvsub(vB, cpvmult(offsetB, inset));

        // Admittedly my variable naming sucks here...
        v2f inner0 = v2f(innerA);
        v2f inner1 = v2f(innerB);
        v2f outer0 = v2f(cpvadd(innerA, cpvmult(nB, outset)));
        v2f outer1 = v2f(cpvadd(innerB, cpvmult(nB, outset)));
        v2f outer2 = v2f(cpvadd(innerA, cpvmult(offsetA, outset)));
        v2f outer3 = v2f(cpvadd(innerA, cpvmult(nA, outset)));

        v2f n0      = v2f(nA);
        v2f n1      = v2f(nB);
        v2f offset0 = v2f(offsetA);

        Triangle t0 = { { inner0, v2f0, fillColor, outlineColor }, { inner1, v2f0, fillColor, outlineColor }, { outer1, n1, fillColor, outlineColor } };
        *cursor++ = t0;
        Triangle t1 = { { inner0, v2f0, fillColor, outlineColor }, { outer0, n1, fillColor, outlineColor }, { outer1, n1, fillColor, outlineColor } };
        *cursor++ = t1;
        Triangle t2 = { { inner0, v2f0, fillColor, outlineColor }, { outer0, n1, fillColor, outlineColor }, { outer2, offset0, fillColor, outlineColor } };
        *cursor++ = t2;
        Triangle t3 = { { inner0, v2f0, fillColor, outlineColor }, { outer2, offset0, fillColor, outlineColor }, { outer3, n0, fillColor, outlineColor } };
        *cursor++ = t3;
    }
}

void ChipmunkDebugDrawDot(cpFloat size, cpVect pos, Color fillColor)
{
    Triangle* triangles = PushTriangles(2);

    float  r = size * 0.5f / ChipmunkDebugDrawPointLineScale;
    Vertex a = { { pos.x - r, pos.y - r }, { -1.0f, -1.0f }, fillColor, fillColor };
    Vertex b = { { pos.x - r, pos.y + r }, { -1.0f, 1.0f }, fillColor, fillColor };
    Vertex c = { { pos.x + r, pos.y + r }, { 1.0f, 1.0f }, fillColor, fillColor };
    Vertex d = { { pos.x + r, pos.y - r }, { 1.0f, -1.0f }, fillColor, fillColor };

    Triangle t0 = { a, b, c };
    triangles[0] = t0;
    Triangle t1 = { a, c, d };
    triangles[1] = t1;
}

void ChipmunkDebugDrawBB(cpBB bb, Color color)
{
    cpVect[4] verts;
    verts[0] = cpv(bb.l, bb.b);
    verts[1] = cpv(bb.l, bb.t);
    verts[2] = cpv(bb.r, bb.t);
    verts[3] = cpv(bb.r, bb.b);
    ChipmunkDebugDrawPolygon(4, verts.ptr, 0.0f, color, LAColor(0, 0));
}

struct ShapeColors
{
    Color outlineColor, fillColor;
}

void DrawShape(cpShape* shape, ShapeColors* colors)
{
    cpBody* body_        = shape.body_;
    Color fill_color    = (colors ? colors.fillColor : ColorForShape(shape));
    Color outline_color = (colors ? colors.outlineColor : LINE_COLOR);

    switch (shape.klass.type)
    {
        case CP_CIRCLE_SHAPE:
        {
            cpCircleShape* circle = cast(cpCircleShape*)shape;
            ChipmunkDebugDrawCircle(circle.tc, body_.a, circle.r, outline_color, fill_color);
            break;
        }

        case CP_SEGMENT_SHAPE:
        {
            cpSegmentShape* seg = cast(cpSegmentShape*)shape;
            ChipmunkDebugDrawFatSegment(seg.ta, seg.tb, seg.r, outline_color, fill_color);
            break;
        }

        case CP_POLY_SHAPE:
        {
            cpPolyShape* poly = cast(cpPolyShape*)shape;
            ChipmunkDebugDrawPolygon(poly.numVerts, poly.tVerts, poly.r, outline_color, fill_color);
            break;
        }

        default:
            break;
    }
}

void ChipmunkDebugDrawShape(cpShape* shape, Color outlineColor, Color fillColor)
{
    ShapeColors colors = { outlineColor, fillColor };
    DrawShape(shape, (outlineColor.a == 0.0 && fillColor.a == 0.0 ? null : &colors));
}

void ChipmunkDebugDrawShapes(cpSpace* space)
{
    cpSpaceEachShape(space, safeCast!cpSpaceShapeIteratorFunc(&DrawShape), null);
}

immutable cpVect[] spring_verts = [
    { 0.00f, 0.0f },
    { 0.20f, 0.0f },
    { 0.25f, 3.0f },
    { 0.30f, -6.0f },
    { 0.35f, 6.0f },
    { 0.40f, -6.0f },
    { 0.45f, 6.0f },
    { 0.50f, -6.0f },
    { 0.55f, 6.0f },
    { 0.60f, -6.0f },
    { 0.65f, 6.0f },
    { 0.70f, -3.0f },
    { 0.75f, 6.0f },
    { 0.80f, 0.0f },
    { 1.00f, 0.0f },
];

immutable int spring_count = spring_verts.length;

void drawSpring(cpDampedSpring* spring, cpBody* body_a, cpBody* body_b)
{
    cpVect a = cpvadd(body_a.p, cpvrotate(spring.anchr1, body_a.rot));
    cpVect b = cpvadd(body_b.p, cpvrotate(spring.anchr2, body_b.rot));

    ChipmunkDebugDrawDot(5, a, CONSTRAINT_COLOR);
    ChipmunkDebugDrawDot(5, b, CONSTRAINT_COLOR);

    cpVect  delta = cpvsub(b, a);
    GLfloat cos   = delta.x;
    GLfloat sin   = delta.y;
    GLfloat s     = 1.0f / cpvlength(delta);

    cpVect r1 = cpv(cos, -sin * s);
    cpVect r2 = cpv(sin, cos * s);

    cpVect* verts = cast(cpVect*)alloca(spring_count * cpVect.sizeof);

    for (int i = 0; i < spring_count; i++)
    {
        cpVect v = spring_verts[i];
        verts[i] = cpv(cpvdot(v, r1) + a.x, cpvdot(v, r2) + a.y);
    }

    for (int i = 0; i < spring_count - 1; i++)
    {
        ChipmunkDebugDrawSegment(verts[i], verts[i + 1], CONSTRAINT_COLOR);
    }
}

void drawConstraint(cpConstraint* constraint, void* unused)
{
    cpBody* body_a = constraint.a;
    cpBody* body_b = constraint.b;

    const cpConstraintClass* klass = constraint.klass;

    if (klass == cpPinJointGetClass())
    {
        cpPinJoint* joint = cast(cpPinJoint*)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.anchr1, body_a.rot));
        cpVect b = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        ChipmunkDebugDrawDot(5, a, CONSTRAINT_COLOR);
        ChipmunkDebugDrawDot(5, b, CONSTRAINT_COLOR);
        ChipmunkDebugDrawSegment(a, b, CONSTRAINT_COLOR);
    }
    else if (klass == cpSlideJointGetClass())
    {
        cpSlideJoint* joint = cast(cpSlideJoint*)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.anchr1, body_a.rot));
        cpVect b = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        ChipmunkDebugDrawDot(5, a, CONSTRAINT_COLOR);
        ChipmunkDebugDrawDot(5, b, CONSTRAINT_COLOR);
        ChipmunkDebugDrawSegment(a, b, CONSTRAINT_COLOR);
    }
    else if (klass == cpPivotJointGetClass())
    {
        cpPivotJoint* joint = cast(cpPivotJoint*)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.anchr1, body_a.rot));
        cpVect b = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        ChipmunkDebugDrawDot(5, a, CONSTRAINT_COLOR);
        ChipmunkDebugDrawDot(5, b, CONSTRAINT_COLOR);
    }
    else if (klass == cpGrooveJointGetClass())
    {
        cpGrooveJoint* joint = cast(cpGrooveJoint*)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.grv_a, body_a.rot));
        cpVect b = cpvadd(body_a.p, cpvrotate(joint.grv_b, body_a.rot));
        cpVect c = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        ChipmunkDebugDrawDot(5, c, CONSTRAINT_COLOR);
        ChipmunkDebugDrawSegment(a, b, CONSTRAINT_COLOR);
    }
    else if (klass == cpDampedSpringGetClass())
    {
        drawSpring(cast(cpDampedSpring*)constraint, body_a, body_b);
    }
}

void ChipmunkDebugDrawConstraint(cpConstraint* constraint)
{
    drawConstraint(constraint, null);
}

void ChipmunkDebugDrawConstraints(cpSpace* space)
{
    cpSpaceEachConstraint(space, &drawConstraint, null);
}

void ChipmunkDebugDrawCollisionPoints(cpSpace* space)
{
    cpArray* arbiters = space.arbiters;
    Color color       = RGBAColor(1.0f, 0.0f, 0.0f, 1.0f);

    for (int i = 0; i < arbiters.num; i++)
    {
        cpArbiter* arb = cast(cpArbiter*)arbiters.arr[i];

        for (int j = 0; j < arb.numContacts; j++)
        {
            cpVect  p = arb.contacts[j].p;
            cpVect  n = arb.contacts[j].n;
            cpFloat d = 2.0 - arb.contacts[j].dist / 2.0;

            cpVect a = cpvadd(p, cpvmult(n, d));
            cpVect b = cpvadd(p, cpvmult(n, -d));
            ChipmunkDebugDrawSegment(a, b, color);
        }
    }
}

void ChipmunkDebugDrawFlushRenderer()
{
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, Triangle.sizeof * triangle_count, triangle_buffer, GL_STREAM_DRAW);

    glUseProgram(program);
    glUniform1f(glGetUniformLocation(program, "u_outline_coef"), ChipmunkDebugDrawPointLineScale);

    version (OSX)
    {
        glBindVertexArrayAPPLE(vao);
    }
    else
    {
        glBindVertexArray(vao);
    }

    glDrawArrays(GL_TRIANGLES, 0, triangle_count * 3);

    CheckGLErrors();
}

void ChipmunkDebugDrawClearRenderer()
{
    triangle_count = 0;
}

__gshared GLsizei pushed_triangle_count = 0;

void ChipmunkDebugDrawPushRenderer()
{
    pushed_triangle_count = triangle_count;
}

void ChipmunkDebugDrawPopRenderer()
{
    triangle_count = pushed_triangle_count;
}
