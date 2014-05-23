
// written in the D programming language

module drawSpace;

import derelict.opengl.gl;

import dchip.all;

import std.math:PI;
import std.stdio;

struct drawSpaceOptions {
    int drawHash;
    int drawBBs;
    int drawShapes;
    float collisionPointSize;
    float bodyPointSize;
    float lineThickness;
}

/*
    IMPORTANT - READ ME!

    This file sets up a simple interface that the individual demos can use to get
    a Chipmunk space running and draw what's in it. In order to keep the Chipmunk
    examples clean and simple, they contain no graphics code. All drawing is done
    by accessing the Chipmunk structures at a very low level. It is NOT
    recommended to write a game or application this way as it does not scale
    beyond simple shape drawing and is very dependent on implementation details
    about Chipmunk which may change with little to no warning.
*/

enum float[3] LINE_COLOR = [0,0,0];

static void
glColor_from_hash(cpHashValue hash)
{
    ulong val = cast(ulong)hash;

    // scramble the bits up using Robert Jenkins' 32 bit integer hash function
    val = (val+0x7ed55d16) + (val<<12);
    val = (val^0xc761c23c) ^ (val>>19);
    val = (val+0x165667b1) + (val<<5);
    val = (val+0xd3a2646c) ^ (val<<9);
    val = (val+0xfd7046c5) + (val<<3);
    val = (val^0xb55a4f09) ^ (val>>16);

    GLubyte r = (val>>0) & 0xFF;
    GLubyte g = (val>>8) & 0xFF;
    GLubyte b = (val>>16) & 0xFF;

    GLubyte max = (r > g ? (r > b ? r : b) : (g > b ? g : b));

    // saturate and scale the colors
    enum int mult = 255;
    enum int add = 0;
    r = cast(ubyte)((r*mult)/max + add);
    g = cast(ubyte)((g*mult)/max + add);
    b = cast(ubyte)((b*mult)/max + add);

    glColor4ub(r, g, b, 196);
}

static void
glColor_for_shape(cpShape *shape, cpSpace *space)
{
    cpBody *body_ = shape.body_;
    if(body_){
        if(cpBodyIsSleeping(body_)){
            GLfloat v = 0.2f;
            glColor3f(v,v,v);
            return;
        } else if(body_.node.idleTime > space.sleepTimeThreshold) {
            GLfloat v = 0.66f;
            glColor3f(v,v,v);
            return;
        }
    }

    glColor_from_hash(shape.hashid);
}

enum GLfloat[] circleVAR = [
     0.0000f,  1.0000f,
     0.2588f,  0.9659f,
     0.5000f,  0.8660f,
     0.7071f,  0.7071f,
     0.8660f,  0.5000f,
     0.9659f,  0.2588f,
     1.0000f,  0.0000f,
     0.9659f, -0.2588f,
     0.8660f, -0.5000f,
     0.7071f, -0.7071f,
     0.5000f, -0.8660f,
     0.2588f, -0.9659f,
     0.0000f, -1.0000f,
    -0.2588f, -0.9659f,
    -0.5000f, -0.8660f,
    -0.7071f, -0.7071f,
    -0.8660f, -0.5000f,
    -0.9659f, -0.2588f,
    -1.0000f, -0.0000f,
    -0.9659f,  0.2588f,
    -0.8660f,  0.5000f,
    -0.7071f,  0.7071f,
    -0.5000f,  0.8660f,
    -0.2588f,  0.9659f,
     0.0000f,  1.0000f,
     0.0f, 0.0f, // For an extra line to see the rotation.
];
enum int circleVAR_count = circleVAR.length / 2;

static void
drawCircleShape(cpBody *body_, cpCircleShape *circle, cpSpace *space)
{
    glVertexPointer(2, GL_FLOAT, 0, circleVAR.ptr);

    glPushMatrix(); {
        cpVect center = circle.tc;
        glTranslatef(center.x, center.y, 0.0f);
        glRotatef(body_.a*180.0f/PI, 0.0f, 0.0f, 1.0f);
        glScalef(circle.r, circle.r, 1.0f);

        if(!circle.shape.sensor){
            glColor_for_shape(cast(cpShape *)circle, space);
            glDrawArrays(GL_TRIANGLE_FAN, 0, circleVAR_count - 1);
        }

        glColor3fv(LINE_COLOR.ptr);
        glDrawArrays(GL_LINE_STRIP, 0, circleVAR_count);
    } glPopMatrix();
}

enum GLfloat[] pillVAR = [
     0.0000f,  1.0000f, 1.0f,
     0.2588f,  0.9659f, 1.0f,
     0.5000f,  0.8660f, 1.0f,
     0.7071f,  0.7071f, 1.0f,
     0.8660f,  0.5000f, 1.0f,
     0.9659f,  0.2588f, 1.0f,
     1.0000f,  0.0000f, 1.0f,
     0.9659f, -0.2588f, 1.0f,
     0.8660f, -0.5000f, 1.0f,
     0.7071f, -0.7071f, 1.0f,
     0.5000f, -0.8660f, 1.0f,
     0.2588f, -0.9659f, 1.0f,
     0.0000f, -1.0000f, 1.0f,

     0.0000f, -1.0000f, 0.0f,
    -0.2588f, -0.9659f, 0.0f,
    -0.5000f, -0.8660f, 0.0f,
    -0.7071f, -0.7071f, 0.0f,
    -0.8660f, -0.5000f, 0.0f,
    -0.9659f, -0.2588f, 0.0f,
    -1.0000f, -0.0000f, 0.0f,
    -0.9659f,  0.2588f, 0.0f,
    -0.8660f,  0.5000f, 0.0f,
    -0.7071f,  0.7071f, 0.0f,
    -0.5000f,  0.8660f, 0.0f,
    -0.2588f,  0.9659f, 0.0f,
     0.0000f,  1.0000f, 0.0f,
];
enum int pillVAR_count = pillVAR.length/3;

static void
drawSegmentShape(cpBody *body_, cpSegmentShape *seg, cpSpace *space)
{
    cpVect a = seg.ta;
    cpVect b = seg.tb;

    if(seg.r){
        glVertexPointer(3, GL_FLOAT, 0, pillVAR.ptr);
        glPushMatrix(); {
            cpVect d = cpvsub(b, a);
            cpVect r = cpvmult(d, seg.r/cpvlength(d));

            GLfloat matrix[] = [
                 r.x, r.y, 0.0f, 0.0f,
                -r.y, r.x, 0.0f, 0.0f,
                 d.x, d.y, 0.0f, 0.0f,
                 a.x, a.y, 0.0f, 1.0f,
            ];
            glMultMatrixf(matrix.ptr);

            if(!seg.shape.sensor){
                glColor_for_shape(cast(cpShape *)seg, space);
                glDrawArrays(GL_TRIANGLE_FAN, 0, pillVAR_count);
            }

            glColor3fv(LINE_COLOR.ptr);
            glDrawArrays(GL_LINE_LOOP, 0, pillVAR_count);
        } glPopMatrix();
    } else {
        glColor3fv(LINE_COLOR.ptr);
        glBegin(GL_LINES); {
            glVertex2f(a.x, a.y);
            glVertex2f(b.x, b.y);
        } glEnd();
    }
}

static void
drawPolyShape(cpBody *body_, cpPolyShape *poly, cpSpace *space)
{
    int count = poly.numVerts;
version(CP_USE_DOUBLES)
{
    glVertexPointer(2, GL_DOUBLE, 0, poly.tVerts);
}
else
{
    glVertexPointer(2, GL_FLOAT, 0, poly.tVerts);
}

    if(!poly.shape.sensor){
        glColor_for_shape(cast(cpShape *)poly, space);
        glDrawArrays(GL_TRIANGLE_FAN, 0, count);
    }

    glColor3fv(LINE_COLOR.ptr);
    glDrawArrays(GL_LINE_LOOP, 0, count);
}

static void
drawObject(cpShape *shape, cpSpace *space)
{
    cpBody *body_ = shape.body_;

    switch(shape.klass.type){
        case cpShapeType.CP_CIRCLE_SHAPE:
            drawCircleShape(body_, cast(cpCircleShape *)shape, space);
            break;
        case cpShapeType.CP_SEGMENT_SHAPE:
            drawSegmentShape(body_, cast(cpSegmentShape *)shape, space);
            break;
        case cpShapeType.CP_POLY_SHAPE:
            drawPolyShape(body_, cast(cpPolyShape *)shape, space);
            break;
        default:
            writefln("Bad enumeration in drawObject().");
    }
}

enum GLfloat[] springVAR = [
    0.00f, 0.0f,
    0.20f, 0.0f,
    0.25f, 3.0f,
    0.30f,-6.0f,
    0.35f, 6.0f,
    0.40f,-6.0f,
    0.45f, 6.0f,
    0.50f,-6.0f,
    0.55f, 6.0f,
    0.60f,-6.0f,
    0.65f, 6.0f,
    0.70f,-3.0f,
    0.75f, 6.0f,
    0.80f, 0.0f,
    1.00f, 0.0f,
];
enum int springVAR_count = springVAR.length / 2;

static void
drawSpring(cpDampedSpring *spring, cpBody *body_a, cpBody *body_b)
{
    cpVect a = cpvadd(body_a.p, cpvrotate(spring.anchr1, body_a.rot));
    cpVect b = cpvadd(body_b.p, cpvrotate(spring.anchr2, body_b.rot));

    glPointSize(5.0f);
    glBegin(GL_POINTS); {
        glVertex2f(a.x, a.y);
        glVertex2f(b.x, b.y);
    } glEnd();

    cpVect delta = cpvsub(b, a);

    glVertexPointer(2, GL_FLOAT, 0, springVAR.ptr);
    glPushMatrix(); {
        GLfloat x = a.x;
        GLfloat y = a.y;
        GLfloat cos = delta.x;
        GLfloat sin = delta.y;
        GLfloat s = 1.0f/cpvlength(delta);

        GLfloat matrix[] = [
                 cos,    sin, 0.0f, 0.0f,
            -sin*s,  cos*s, 0.0f, 0.0f,
                0.0f,   0.0f, 1.0f, 0.0f,
                     x,      y, 0.0f, 1.0f,
        ];

        glMultMatrixf(matrix.ptr);
        glDrawArrays(GL_LINE_STRIP, 0, springVAR_count);
    } glPopMatrix();
}

static void
drawConstraint(cpConstraint *constraint)
{
    cpBody *body_a = constraint.a;
    cpBody *body_b = constraint.b;

    const cpConstraintClass *klass = constraint.klass;
    if(klass == cpPinJointGetClass()){
        cpPinJoint *joint = cast(cpPinJoint *)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.anchr1, body_a.rot));
        cpVect b = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        glPointSize(5.0f);
        glBegin(GL_POINTS); {
            glVertex2f(a.x, a.y);
            glVertex2f(b.x, b.y);
        } glEnd();

        glBegin(GL_LINES); {
            glVertex2f(a.x, a.y);
            glVertex2f(b.x, b.y);
        } glEnd();
    } else if(klass == cpSlideJointGetClass()){
        cpSlideJoint *joint = cast(cpSlideJoint *)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.anchr1, body_a.rot));
        cpVect b = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        glPointSize(5.0f);
        glBegin(GL_POINTS); {
            glVertex2f(a.x, a.y);
            glVertex2f(b.x, b.y);
        } glEnd();

        glBegin(GL_LINES); {
            glVertex2f(a.x, a.y);
            glVertex2f(b.x, b.y);
        } glEnd();
    } else if(klass == cpPivotJointGetClass()){
        cpPivotJoint *joint = cast(cpPivotJoint *)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.anchr1, body_a.rot));
        cpVect b = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        glPointSize(10.0f);
        glBegin(GL_POINTS); {
            glVertex2f(a.x, a.y);
            glVertex2f(b.x, b.y);
        } glEnd();
    } else if(klass == cpGrooveJointGetClass()){
        cpGrooveJoint *joint = cast(cpGrooveJoint *)constraint;

        cpVect a = cpvadd(body_a.p, cpvrotate(joint.grv_a, body_a.rot));
        cpVect b = cpvadd(body_a.p, cpvrotate(joint.grv_b, body_a.rot));
        cpVect c = cpvadd(body_b.p, cpvrotate(joint.anchr2, body_b.rot));

        glPointSize(5.0f);
        glBegin(GL_POINTS); {
            glVertex2f(c.x, c.y);
        } glEnd();

        glBegin(GL_LINES); {
            glVertex2f(a.x, a.y);
            glVertex2f(b.x, b.y);
        } glEnd();
    } else if(klass == cpDampedSpringGetClass()){
        drawSpring(cast(cpDampedSpring *)constraint, body_a, body_b);
    } else {
//		printf("Cannot draw constraint\n");
    }
}

static void
drawBB(cpShape *shape, void *unused)
{
    glBegin(GL_LINE_LOOP); {
        glVertex2f(shape.bb.l, shape.bb.b);
        glVertex2f(shape.bb.l, shape.bb.t);
        glVertex2f(shape.bb.r, shape.bb.t);
        glVertex2f(shape.bb.r, shape.bb.b);
    } glEnd();
}

void
DrawSpace(cpSpace *space, const drawSpaceOptions *options)
{
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    if(options.drawHash){
//		glColorMask(GL_FALSE, GL_TRUE, GL_FALSE, GL_TRUE);
//		drawSpatialHash(space->activeShapes);
//		glColorMask(GL_TRUE, GL_FALSE, GL_FALSE, GL_FALSE);
//		drawSpatialHash(space->staticShapes);
//		glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

//		glColor3f(0.5, 0.5, 0.5);
//		cpBBTreeRenderDebug(space->staticShapes);
//		glColor3f(0, 1, 0);
//		cpBBTreeRenderDebug(space->activeShapes);
    }

    glLineWidth(options.lineThickness);
    if(options.drawShapes){
        cpSpatialIndexEach(space.activeShapes, cast(cpSpatialIndexIteratorFunc)&drawObject, space);
        cpSpatialIndexEach(space.staticShapes, cast(cpSpatialIndexIteratorFunc)&drawObject, space);
    }

    glLineWidth(1.0f);
    if(options.drawBBs){
        glColor3f(0.3f, 0.5f, 0.3f);
        cpSpatialIndexEach(space.activeShapes, cast(cpSpatialIndexIteratorFunc)&drawBB, null);
        cpSpatialIndexEach(space.staticShapes, cast(cpSpatialIndexIteratorFunc)&drawBB, null);
    }

    cpArray *constraints = space.constraints;

    glColor3f(0.0f, 0.0f, 0.5f);
    for(int i=0, count = constraints.num; i<count; i++){
        drawConstraint(cast(cpConstraint *)constraints.arr[i]);
    }

    if(options.bodyPointSize){
        glPointSize(options.bodyPointSize);

        glBegin(GL_POINTS); {
            glColor3fv(LINE_COLOR.ptr);
            cpArray *bodies = space.bodies;
            for(int i=0, count = bodies.num; i<count; i++){
                cpBody *body_ = cast(cpBody *)bodies.arr[i];
                glVertex2f(body_.p.x, body_.p.y);
            }

//			glColor3f(0.5f, 0.5f, 0.5f);
//			cpArray *components = space.components;
//			for(int i=0; i<components.num; i++){
//				cpBody *root = components.arr[i];
//				cpBody *body = root, *next;
//				do {
//					next = body.node.next;
//					glVertex2f(body.p.x, body.p.y);
//				} while((body = next) != root);
//			}
        } glEnd();
    }

    if(options.collisionPointSize){
        cpArray* arbiters = space.arbiters;

        glColor3f(0.0f, 1.0f, 0.0f);
        glPointSize(2.0f*options.collisionPointSize);

        glBegin(GL_POINTS); {
            for(int i=0; i<arbiters.num; i++){
                cpArbiter *arb = cast(cpArbiter*)arbiters.arr[i];
                if(arb.state != cpArbiterState.cpArbiterStateFirstColl) continue;

                for(int j=0; j<arb.numContacts; j++){
                    cpVect v = arb.contacts[j].p;
                    glVertex2f(v.x, v.y);
                }
            }
        } glEnd();

        glColor3f(1.0f, 0.0f, 0.0f);
        glPointSize(options.collisionPointSize);

        glBegin(GL_POINTS); {
            for(int i=0; i<arbiters.num; i++){
                cpArbiter *arb = cast(cpArbiter*)arbiters.arr[i];
                if(arb.state == cpArbiterState.cpArbiterStateFirstColl) continue;

                for(int j=0; j<arb.numContacts; j++){
                    cpVect v = arb.contacts[j].p;
                    glVertex2f(v.x, v.y);
                }
            }
        } glEnd();
    }
}
