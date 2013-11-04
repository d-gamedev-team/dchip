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
module demo.ChipmunkDemo;

import core.memory;

import core.stdc.stdio;
import core.stdc.stdlib;

import std.exception;
import std.stdio;
import std.string;

alias stderr = std.stdio.stderr;

import glad.gl.all;
import glad.gl.loader;

version (USE_DEIMOS_GLFW)
{
    import deimos.glfw.glfw3;
}
else
{
    import derelict.glfw3.glfw3;

    shared static this()
    {
        DerelictGLFW3.load();
    }
}

import demo.dchip;

import demo.Bench;
import demo.ChipmunkDebugDraw;
import demo.ChipmunkDemoTextSupport;
import demo.glu;
import demo.types;

import demo.LogoSmash;
import demo.PyramidStack;
import demo.Plink;
import demo.Tumble;
import demo.PyramidTopple;
import demo.Planet;
import demo.Springies;
import demo.Pump;
import demo.TheoJansen;
import demo.Query;
import demo.OneWay;
import demo.Joints;
import demo.Tank;
import demo.Chains;
import demo.Crane;
import demo.ContactGraph;
import demo.Buoyancy;
import demo.Player;
import demo.Slice;
import demo.Convex;
import demo.Unicycle;
import demo.Sticky;
import demo.Shatter;

ChipmunkDemo[] demo_list;
shared static this()
{
    demo_list = [
        LogoSmash,
        PyramidStack,
        Plink,
        BouncyHexagons,
        Tumble,
        PyramidTopple,
        Planet,
        Springies,
        Pump,
        TheoJansen,
        Query,
        OneWay,
        Joints,
        Tank,
        Chains,
        Crane,
        ContactGraph,
        Buoyancy,
        Player,
        Slice,
        Convex,
        Unicycle,
        Sticky,
        Shatter,
    ];
}

alias ChipmunkDemoInitFunc = cpSpace* function();
alias ChipmunkDemoUpdateFunc = void function(cpSpace* space, double dt);
alias ChipmunkDemoDrawFunc = void function(cpSpace* space);
alias ChipmunkDemoDestroyFunc = void function(cpSpace* space);

__gshared GLFWwindow* window;

struct ChipmunkDemo
{
    string name;
    double timestep;

    ChipmunkDemoInitFunc initFunc;
    ChipmunkDemoUpdateFunc updateFunc;
    ChipmunkDemoDrawFunc drawFunc;

    ChipmunkDemoDestroyFunc destroyFunc;
}

cpFloat frand()
{
    return cast(cpFloat)rand() / cast(cpFloat)RAND_MAX;
}

cpVect frand_unit_circle()
{
    cpVect v = cpv(frand() * 2.0f - 1.0f, frand() * 2.0f - 1.0f);
    return (cpvlengthsq(v) < 1.0f ? v : frand_unit_circle());
}

enum GRABABLE_MASK_BIT = (1 << 31);
enum NOT_GRABABLE_MASK = (~GRABABLE_MASK_BIT);

void ChipmunkDemoDefaultDrawImpl(cpSpace* space);
void ChipmunkDemoFreeSpaceChildren(cpSpace* space);

ChipmunkDemo* demos;
int demo_count = 0;
int demo_index = 0;

cpBool paused = cpFalse;
cpBool step   = cpFalse;

cpSpace* space;

double Accumulator = 0.0;
double LastTime    = 0.0;
int ChipmunkDemoTicks = 0;
double ChipmunkDemoTime;

cpVect ChipmunkDemoMouse;
cpBool ChipmunkDemoRightClick = cpFalse;
cpBool ChipmunkDemoRightDown  = cpFalse;
cpVect ChipmunkDemoKeyboard;

cpBody* mouse_body        = null;
cpConstraint* mouse_joint = null;

char[] ChipmunkDemoMessageString;

cpVect  translate = { 0, 0 };
cpFloat scale = 1.0;

void ShapeFreeWrap(cpSpace* space, cpShape* shape, void* unused)
{
    cpSpaceRemoveShape(space, shape);
    cpShapeFree(shape);
}

void PostShapeFree(cpShape* shape, cpSpace* space)
{
    cpSpaceAddPostStepCallback(space, safeCast!cpPostStepFunc(&ShapeFreeWrap), shape, null);
}

void ConstraintFreeWrap(cpSpace* space, cpConstraint* constraint, void* unused)
{
    cpSpaceRemoveConstraint(space, constraint);
    cpConstraintFree(constraint);
}

void PostConstraintFree(cpConstraint* constraint, cpSpace* space)
{
    cpSpaceAddPostStepCallback(space, safeCast!cpPostStepFunc(&ConstraintFreeWrap), constraint, null);
}

void BodyFreeWrap(cpSpace* space, cpBody* body_, void* unused)
{
    cpSpaceRemoveBody(space, body_);
    cpBodyFree(body_);
}

void PostBodyFree(cpBody* body_, cpSpace* space)
{
    cpSpaceAddPostStepCallback(space, safeCast!cpPostStepFunc(&BodyFreeWrap), body_, null);
}

// Safe and future proof way to remove and free all objects that have been added to the space.
void ChipmunkDemoFreeSpaceChildren(cpSpace* space)
{
    // Must remove these BEFORE freeing the body_ or you will access dangling pointers.
    cpSpaceEachShape(space, safeCast!cpSpaceShapeIteratorFunc(&PostShapeFree), space);
    cpSpaceEachConstraint(space, safeCast!cpSpaceConstraintIteratorFunc(&PostConstraintFree), space);

    cpSpaceEachBody(space, safeCast!cpSpaceBodyIteratorFunc(&PostBodyFree), space);
}

void ChipmunkDemoDefaultDrawImpl(cpSpace* space)
{
    ChipmunkDebugDrawShapes(space);
    ChipmunkDebugDrawConstraints(space);
    ChipmunkDebugDrawCollisionPoints(space);
}

void DrawInstructions()
{
    ChipmunkDemoTextDrawString(cpv(-300, 220),
                               "Controls:\n"
                               "A - * Switch demos. (return restarts)\n"
                               "Use the mouse to grab objects.\n"
                               );
}

int max_arbiters    = 0;
int max_points      = 0;
int max_constraints = 0;

void DrawInfo()
{
    int arbiters = space.arbiters.num;
    int points   = 0;

    for (int i = 0; i < arbiters; i++)
        points += (cast(cpArbiter*)(space.arbiters.arr[i])).numContacts;

    int constraints = (space.constraints.num + points) * space.iterations;

    max_arbiters    = arbiters > max_arbiters ? arbiters : max_arbiters;
    max_points      = points > max_points ? points : max_points;
    max_constraints = constraints > max_constraints ? constraints : max_constraints;

    char[1024] buffer = 0;
    string format =
        "Arbiters: %d (%d) - "
        "Contact Points: %d (%d)\n"
        "Other Constraints: %d, Iterations: %d\n"
        "Constraints x Iterations: %d (%d)\n"
        "Time:% 5.2fs, KE:% 5.2e\0";

    cpArray* bodies = space.bodies;
    cpFloat  ke     = 0.0f;

    for (int i = 0; i < bodies.num; i++)
    {
        cpBody* body_ = cast(cpBody*)bodies.arr[i];

        if (body_.m == INFINITY || body_.i == INFINITY)
            continue;

        ke += body_.m * cpvdot(body_.v, body_.v) + body_.i * body_.w * body_.w;
    }

    sprintf(buffer.ptr, format.ptr,
            arbiters, max_arbiters,
            points, max_points,
            space.constraints.num, space.iterations,
            constraints, max_constraints,
            ChipmunkDemoTime, (ke < 1e-10f ? 0.0f : ke)
            );

    ChipmunkDemoTextDrawString(cpv(0, 220), buffer);
}

char  PrintStringBuffer[1024 * 8] = 0;
size_t PrintStringCursor;

void ChipmunkDemoPrintString(Args...)(string fmt, Args args)
{
    ChipmunkDemoMessageString = PrintStringBuffer[];
    PrintStringCursor += sformat(PrintStringBuffer[PrintStringCursor .. $], fmt, args).length;
}

void Tick(double dt)
{
    if (!paused || step)
    {
        PrintStringBuffer[0] = 0;
        PrintStringCursor = 0;

        // Completely reset the renderer only at the beginning of a tick.
        // That way it can always display at least the last ticks' debug drawing.
        ChipmunkDebugDrawClearRenderer();
        ChipmunkDemoTextClearRenderer();

        cpVect new_point = cpvlerp(mouse_body.p, ChipmunkDemoMouse, 0.25f);
        mouse_body.v = cpvmult(cpvsub(new_point, mouse_body.p), 60.0f);
        mouse_body.p = new_point;

        demos[demo_index].updateFunc(space, dt);

        ChipmunkDemoTicks++;
        ChipmunkDemoTime += dt;

        step = cpFalse;
        ChipmunkDemoRightDown = cpFalse;

        ChipmunkDemoTextDrawString(cpv(-300, -200), ChipmunkDemoMessageString);
    }
}

void Update()
{
    double time = glfwGetTime();
    double dt   = time - LastTime;

    if (dt > 0.2)
        dt = 0.2;

    double fixed_dt = demos[demo_index].timestep;

    for (Accumulator += dt; Accumulator > fixed_dt; Accumulator -= fixed_dt)
    {
        Tick(fixed_dt);
    }

    LastTime = time;
}

void Display()
{
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(cast(GLfloat)translate.x, cast(GLfloat)translate.y, 0.0f);
    glScalef(cast(GLfloat)scale, cast(GLfloat)scale, 1.0f);

    Update();

    ChipmunkDebugDrawPushRenderer();
    demos[demo_index].drawFunc(space);

    // Highlight the shape under the mouse because it looks neat.
    cpShape* nearest = cpSpaceNearestPointQueryNearest(space, ChipmunkDemoMouse, 0.0f, CP_ALL_LAYERS, CP_NO_GROUP, null);

    if (nearest)
        ChipmunkDebugDrawShape(nearest, RGBAColor(1.0f, 0.0f, 0.0f, 1.0f), LAColor(0.0f, 0.0f));

    // Draw the renderer contents and reset it back to the last tick's state.
    ChipmunkDebugDrawFlushRenderer();
    ChipmunkDebugDrawPopRenderer();

    ChipmunkDemoTextPushRenderer();

    // Now render all the UI text.
    DrawInstructions();
    DrawInfo();

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    {
        // Draw the text at fixed positions,
        // but save the drawing matrix for the mouse picking
        glLoadIdentity();

        ChipmunkDemoTextFlushRenderer();
        ChipmunkDemoTextPopRenderer();
    }
    glPopMatrix();

    glfwSwapBuffers(window);
    glClear(GL_COLOR_BUFFER_BIT);
}

extern(C) void Reshape(GLFWwindow* window, int width, int height)
{
    glViewport(0, 0, width, height);

    float scale = cast(float)cpfmin(width / 640.0, height / 480.0);
    float hw    = width * (0.5f / scale);
    float hh    = height * (0.5f / scale);

    ChipmunkDebugDrawPointLineScale = scale;
    glLineWidth(cast(GLfloat)scale);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluOrtho2D(-hw, hw, -hh, hh);
}

char[] DemoTitle(int index)
{
    static char[1024] title;
    title[] = 0;
    sformat(title, "Demo(%s): %s", cast(char)('a' + index), demos[demo_index].name);
    return title;
}

void RunDemo(int index)
{
    srand(45073);

    demo_index = index;

    ChipmunkDemoTicks = 0;
    ChipmunkDemoTime  = 0.0;
    Accumulator       = 0.0;
    LastTime = glfwGetTime();

    mouse_joint = null;
    ChipmunkDemoMessageString = "\0".dup;
    max_arbiters    = 0;
    max_points      = 0;
    max_constraints = 0;
    space = demos[demo_index].initFunc();

    enforce(window !is null);
    glfwSetWindowTitle(window, DemoTitle(index).toStringz);
}

extern(C) void Keyboard(GLFWwindow* window, int key, int scancode, int state, int modifier)
{
    if (state != GLFW_REPEAT)  // we ignore repeat
    switch (key)
    {
        case GLFW_KEY_UP:
            ChipmunkDemoKeyboard.y += (state == GLFW_PRESS ?  1.0 : -1.0);
            break;

        case GLFW_KEY_DOWN:
            ChipmunkDemoKeyboard.y += (state == GLFW_PRESS ? -1.0 :  1.0);
            break;

        case GLFW_KEY_RIGHT:
            ChipmunkDemoKeyboard.x += (state == GLFW_PRESS ?  1.0 : -1.0);
            break;

        case GLFW_KEY_LEFT:
            ChipmunkDemoKeyboard.x += (state == GLFW_PRESS ? -1.0 :  1.0);
            break;

        default:
            break;
    }

    if (key == GLFW_KEY_ESCAPE && (state == GLFW_PRESS || state == GLFW_REPEAT))
        glfwSetWindowShouldClose(window, true);

    // We ignore release for these next keys.
    if (state == GLFW_RELEASE)
        return;

    int index = key - GLFW_KEY_A;

    if (0 <= index && index < demo_count)
    {
        demos[demo_index].destroyFunc(space);
        RunDemo(index);
    }
    else if (key == ' ')
    {
        demos[demo_index].destroyFunc(space);
        RunDemo(demo_index);
    }
    else if (key == '`')
    {
        paused = !paused;
    }
    else if (key == '1')
    {
        step = cpTrue;
    }
    else if (key == '\\')
    {
        glDisable(GL_LINE_SMOOTH);
        glDisable(GL_POINT_SMOOTH);
    }

    GLfloat translate_increment = 50.0f / cast(GLfloat)scale;
    GLfloat scale_increment     = 1.2f;

    if (key == '5')
    {
        translate.x = 0.0f;
        translate.y = 0.0f;
        scale       = 1.0f;
    }
    else if (key == '4')
    {
        translate.x += translate_increment;
    }
    else if (key == '6')
    {
        translate.x -= translate_increment;
    }
    else if (key == '2')
    {
        translate.y += translate_increment;
    }
    else if (key == '8')
    {
        translate.y -= translate_increment;
    }
    else if (key == '7')
    {
        scale /= scale_increment;
    }
    else if (key == '9')
    {
        scale *= scale_increment;
    }
}

cpVect MouseToSpace(double x, double y)
{
    GLdouble model[16];
    glGetDoublev(GL_MODELVIEW_MATRIX, model.ptr);

    GLdouble proj[16];
    glGetDoublev(GL_PROJECTION_MATRIX, proj.ptr);

    GLint view[4];
    glGetIntegerv(GL_VIEWPORT, view.ptr);

    int ww, wh;
    glfwGetWindowSize(window, &ww, &wh);

    GLdouble mx, my, mz;
    gluUnProject(x, wh - y, 0.0f, model.ptr, proj.ptr, view.ptr, &mx, &my, &mz);

    return cpv(mx, my);
}

extern(C) void Mouse(GLFWwindow* window, double x, double y)
{
    ChipmunkDemoMouse = MouseToSpace(x, y);
}

extern(C) void Click(GLFWwindow* window, int button, int state, int mods)
{
    if (button == GLFW_MOUSE_BUTTON_1)
    {
        if (state == GLFW_PRESS)
        {
            cpShape* shape = cpSpacePointQueryFirst(space, ChipmunkDemoMouse, GRABABLE_MASK_BIT, CP_NO_GROUP);

            if (shape)
            {
                cpBody* body_ = shape.body_;
                mouse_joint = cpPivotJointNew2(mouse_body, body_, cpvzero, cpBodyWorld2Local(body_, ChipmunkDemoMouse));
                mouse_joint.maxForce  = 50000.0f;
                mouse_joint.errorBias = cpfpow(1.0f - 0.15f, 60.0f);
                cpSpaceAddConstraint(space, mouse_joint);
            }
        }
        else if (mouse_joint)
        {
            cpSpaceRemoveConstraint(space, mouse_joint);
            cpConstraintFree(mouse_joint);
            mouse_joint = null;
        }
    }
    else if (button == GLFW_MOUSE_BUTTON_2)
    {
        ChipmunkDemoRightDown = ChipmunkDemoRightClick = (state == GLFW_PRESS);
    }
}

extern(C) void WindowClose(GLFWwindow* window)
{
    glfwTerminate();
    glfwSetWindowShouldClose(window, true);
}

void SetupGL()
{
    ChipmunkDebugDrawInit();
    ChipmunkDemoTextInit();

    glClearColor(52.0f / 255.0f, 62.0f / 255.0f, 72.0f / 255.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_POINT_SMOOTH);

    glHint(GL_LINE_SMOOTH_HINT, GL_DONT_CARE);
    glHint(GL_POINT_SMOOTH_HINT, GL_DONT_CARE);

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

void TimeTrial(int index, int count)
{
    space = demos[index].initFunc();

    double start_time = glfwGetTime();
    double dt         = demos[index].timestep;

    for (int i = 0; i < count; i++)
        demos[index].updateFunc(space, dt);

    double end_time = glfwGetTime();

    demos[index].destroyFunc(space);

    printf("Time(%c) = %8.2f ms (%s)\n", index + 'a', (end_time - start_time) * 1e3f, demos[index].name);
}

int main(string[] args)
{
    GC.disable();
    scope (exit)
        GC.enable();

    // Segment/segment collisions need to be explicitly enabled currently.
    // This will becoume enabled by default in future versions of Chipmunk.
    cpEnableSegmentToSegmentCollisions();

    demos      = demo_list.ptr;
    demo_count = demo_list.length;
    int trial = 0;

    foreach (arg; args[1 .. $])
    {
        if (arg == "-bench")
        {
            demos      = cast(ChipmunkDemo*)bench_list.ptr;
            demo_count = bench_count;
        }
        else
        if (arg == "-trial")
        {
            trial = 1;
        }
    }

    if (trial)
    {
        cpAssertHard(glfwInit(), "Error initializing GLFW.");

        //		sleep(1);
        for (int i = 0; i < demo_count; i++)
            TimeTrial(i, 1000);

        //		time_trial('d' - 'a', 10000);
        return 0;
    }
    else
    {
        mouse_body = cpBodyNew(INFINITY, INFINITY);

        // initialize glwf
        auto res = glfwInit();
        enforce(res, format("glfwInit call failed with return code: '%s'", res));
        scope(exit)
            glfwTerminate();

        int width = 640;
        int height = 480;

        // Create a windowed mode window and its OpenGL context
        window = enforce(glfwCreateWindow(width, height, "Hello World", null, null),
                              "glfwCreateWindow call failed.");

        glfwSwapInterval(0);

        // Make the window's context current
        glfwMakeContextCurrent(window);

        // load all glad function pointers
        enforce(gladLoadGL());

        SetupGL();

        // glfw3 doesn't want to automatically do this the first time the window is shown
        Reshape(window, 640, 480);

        glfwSetWindowSizeCallback(window, &Reshape);
        glfwSetKeyCallback(window, &Keyboard);

        glfwSetCursorPosCallback(window, &Mouse);
        glfwSetMouseButtonCallback(window, &Click);

        RunDemo(demo_index);

        /* Loop until the user closes the window */
        while (!glfwWindowShouldClose(window))
        {
            /* Poll for and process events */
            glfwPollEvents();

            /* Render here */
            Display();
        }
    }

    return 0;
}
