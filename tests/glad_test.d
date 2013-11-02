module glad_test;

import std.exception;
import std.string;

import glad.gl.all;
import glad.gl.loader;

import deimos.glfw.glfw3;

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

    /* Loop until the user closes the window */
    while (!glfwWindowShouldClose(window))
    {
        /* Render here */
        ratio = cast(float)width / cast(float)height;
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT);
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(-ratio, ratio, -1.0, 1.0, 1.0, -1.0);
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        glRotatef(cast(float) glfwGetTime() * 50.0, 0.0, 0.0, 1.0);
        glBegin(GL_TRIANGLES);
        glColor3f(1.0, 0.0, 0.0);
        glVertex3f(-0.6f, -0.4f, 0.0);
        glColor3f(0.0, 1.0, 0.0);
        glVertex3f(0.6f, -0.4f, 0.0);
        glColor3f(0.0, 0.0, 1.0);
        glVertex3f(0.0, 0.6f, 0.0);
        glEnd();

        /* Swap front and back buffers */
        glfwSwapBuffers(window);

        /* Poll for and process events */
        glfwPollEvents();
    }
}
