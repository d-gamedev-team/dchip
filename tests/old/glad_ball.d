module glad_test;

import core.time;

import std.datetime;
import std.exception;
import std.stdio;
import std.string;

import glad.gl.all;
import glad.gl.loader;

import deimos.glfw.glfw3;

import dchip;

immutable GLfloat circleVAR[] = [
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

immutable int circleVAR_count = circleVAR.length / 2;

class World
{
    this()
    {
        // Create a space, a space is a simulation world. It simulates the motions of rigid bodies,
        // handles collisions between them, and simulates the joints between them.
        this.space = cpSpaceNew();

        // Lets set some parameters of the space:
        // More iterations make the simulation more accurate but slower
        space.iterations = 10;
        // These parameters tune the efficiency of the collision detection.
        // For more info: http://code.google.com/p/chipmunk-physics/wiki/cpSpace
        //cpSpaceResizeStaticHash(space, 30.0f, 1000);
        //cpSpaceResizeActiveHash(space, 30.0f, 1000);
        // Give it some gravity
        space.gravity = cpv(0, -1);

        // Create A ground segment along the bottom of the screen
        // By attaching it to &space.staticBody instead of a body_, we make it a static shape.
        cpShape *ground = cpSegmentShapeNew(space.staticBody, cpv(-320,-240), cpv(320,-240), 0.0f);
        // Set some parameters of the shape.
        // For more info: http://code.google.com/p/chipmunk-physics/wiki/cpShape
        ground.e = 1.0f; ground.u = 1.0f;
        // Add the shape to the space as a static shape
        // If a shape never changes position, add it as static so Chipmunk knows it only needs to
        // calculate collision information for it once when it is added.
        // Do not change the postion of a static shape after adding it.
        cpSpaceAddShape(space, ground);

        // Add a moving circle object.
        this.radius = 15.0f;
        cpFloat mass = 10.0f;
        // This time we need to give a mass and moment of inertia when creating the circle.
        this.ballBody = cpBodyNew(mass, cpMomentForCircle(mass, 0.0f, radius, cpvzero));
        assert(ballBody);
        // Set some parameters of the body_:
        // For more info: http://code.google.com/p/chipmunk-physics/wiki/cpBody
        ballBody.p = cpv(0, -100 + radius+50);
        ballBody.v = cpv(0, -20);
        // Add the body_ to the space so it will be simulated and move around.
        cpSpaceAddBody(space, ballBody);

        // Add a circle shape for the ball.
        // Shapes are always defined relative to the center of
        // gravity of the body_ they are attached to.
        // When the body_ moves or rotates, the shape will move with it.
        // Additionally, all of the cpSpaceAdd*() functions return
        // the thing they added so you can create and add in one go.
        this.ballShape = cpSpaceAddShape(space, cpCircleShapeNew(ballBody, radius, cpvzero));
        ballShape.e = 0.0f; ballShape.u = 0.9f;

        // free our objects
        //cpSpaceFreeChildren(space);
        // free the space
    }

    void release()
    {
        cpSpaceFree(space);
    }

    void update()
    {
        cpSpaceStep(space, 1.0f/60.0f);
    }

    void render()
    {
        auto width = 640;
        auto height = 480;
        auto ratio = cast(float)640/ cast(float)480;

        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(-ratio, ratio, -1.0, 1.0, 1.0, -1.0);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        //~ glRotatef(cast(float) glfwGetTime() * 50.0, 0.0, 0.0, 1.0);

        auto body_ = ballBody;
        auto circle = cast(cpCircleShape *)ballShape;

        glBegin(GL_TRIANGLES);
        glColor3f(1.0, 0.0, 0.0);
        glVertex3f(-0.6f, -0.4f, 0.0);
        glColor3f(0.0, 1.0, 0.0);
        glVertex3f(0.6f, -0.4f, 0.0);
        glColor3f(0.0, 0.0, 1.0);
        glVertex3f(0.0, 0.6f, 0.0);
        glEnd();

        //~ glVertexPointer(2, GL_FLOAT, 0, circleVAR.ptr);

        glPushMatrix();
        {
            cpVect center = circle.tc;
            center.x = center.x / 220.0;
            center.y = center.y / 220.0;
            //~ stderr.writeln(center);
            glTranslatef(center.x, center.y, 0.0f);
            glRotatef(body_.a*180.0f/M_PI, 0.0f, 0.0f, 1.0f);
            glScalef(circle.r, circle.r, 1.0f);

            //~ if(!circle.shape.sensor){
                glColor3f(1.0, 0.0, 0.0);
                glDrawArrays(GL_TRIANGLE_FAN, 0, circleVAR_count - 1);
            //~ }

            glColor3f(0.0, 1.0, 0.0);
            glDrawArrays(GL_LINE_STRIP, 0, circleVAR_count);
        }
        glPopMatrix();
    }

    @property bool isFinished()
    {
        return ballBody.p.y < -240 + radius;
    }

private:
    cpSpace* space;
    cpShape* ballShape;
    cpBody* ballBody;
    cpFloat radius = 0;
}

extern(C) void Reshape(GLFWwindow* window, int width, int height)
{
	glViewport(0, 0, width, height);

	float scale = cast(float)cpfmin(width/640.0, height/480.0);
	float hw = width*(0.5f/scale);
	float hh = height*(0.5f/scale);

	//~ ChipmunkDebugDrawPointLineScale = scale;
	glLineWidth(cast(GLfloat)scale);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	gluOrtho2D(-hw, hw, -hh, hh);
}

void gluOrtho2D(float left, float right, float bottom, float top)
{
    // todo: or -1.0 and 1.0
    glOrtho(left, right, bottom, top, 1.0, -1.0);
}

void SetupGL()
{
	//~ glewExperimental = GL_TRUE;
	//~ cpAssertHard(glewInit() == GLEW_NO_ERROR, "There was an error initializing GLEW.");
	//~ cpAssertHard(GLEW_ARB_vertex_array_object, "Requires VAO support.");

	//~ ChipmunkDebugDrawInit();
	//~ ChipmunkDemoTextInit();

	glClearColor(52.0f/255.0f, 62.0f/255.0f, 72.0f/255.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_LINE_SMOOTH);
	glEnable(GL_POINT_SMOOTH);

	glHint(GL_LINE_SMOOTH_HINT, GL_DONT_CARE);
	glHint(GL_POINT_SMOOTH_HINT, GL_DONT_CARE);

	glEnable(GL_BLEND);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

void main()
{
    // initialize glwf
    auto res = glfwInit();
    enforce(res, format("glfwInit call failed with return code: '%s'", res));
    scope(exit)
        glfwTerminate();

    int width = 640;
    int height = 480;

    // Create a windowed mode window and its OpenGL context
    auto window = enforce(glfwCreateWindow(width, height, "Hello World", null, null),
                          "glfwCreateWindow call failed.");

    // Make the window's context current
    glfwMakeContextCurrent(window);

    // load all glad function pointers
    enforce(gladLoadGL());

    float ratio = 0.0;

    /* control v-sync. */
    glfwSwapInterval(0);

    Duration gameTickDur = 1.seconds / 60;
    Duration renderTickDur = 1.seconds / 60;

    Duration gameTickAccumulator;
    Duration renderAccumulator;

    /* start timer. */
    StopWatch gameTimer;
    gameTimer.start();
    scope(exit) gameTimer.stop();

    TickDuration currentTime = gameTimer.peek();
    TickDuration oldTime;
    TickDuration delta;

    auto world = new World();
    scope (exit)
        world.release();

    extern(C) void onKeyEvent(GLFWwindow* window, int key, int scancode, int state, int modifier)
    {
        if (key == GLFW_KEY_ESCAPE && state == GLFW_PRESS)
            glfwSetWindowShouldClose(window, true);
    }

    glfwSetKeyCallback(window, &onKeyEvent);

	SetupGL();

	glfwSetWindowSizeCallback(window, &Reshape);
	//~ glfwSetWindowCloseCallback(WindowClose);

	//~ glfwSetCharCallback(Keyboard);
	//~ glfwSetKeyCallback(SpecialKeyboard);

	//~ glfwSetMousePosCallback(Mouse);
	//~ glfwSetMouseButtonCallback(Click);

    bool finished;
    while (!finished)
    {
        oldTime = currentTime;
        currentTime = gameTimer.peek();

        delta = currentTime - oldTime;

        gameTickAccumulator += delta;

        while (gameTickAccumulator >= gameTickDur)
        {
            world.update();
            gameTickAccumulator -= gameTickDur;
        }

        world.render();

        /* Swap front and back buffers */
        glfwSwapBuffers(window);
        glClear(GL_COLOR_BUFFER_BIT);

        /* Poll for and process events. */
        glfwPollEvents();

        if (glfwWindowShouldClose(window))
            finished = true;

        // stop simulation once the ball touches the ground
        if (world.isFinished)
            finished = true;
    }
}
