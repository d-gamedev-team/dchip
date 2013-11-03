import dchip.all;

import std.stdio;

void main()
{
    // Create a space, a space is a simulation world. It simulates the motions of rigid bodies,
    // handles collisions between them, and simulates the joints between them.
    cpSpace* space = cpSpaceNew();

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
    // By attaching it to &space.staticBody instead of a body, we make it a static shape.
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
    cpFloat radius = 15.0f;
    cpFloat mass = 10.0f;
    // This time we need to give a mass and moment of inertia when creating the circle.
    cpBody *ballBody = cpBodyNew(mass, cpMomentForCircle(mass, 0.0f, radius, cpvzero));
    assert(ballBody);
    // Set some parameters of the body:
    // For more info: http://code.google.com/p/chipmunk-physics/wiki/cpBody
    ballBody.p = cpv(0, -100 + radius+50);
    ballBody.v = cpv(0, -20);
    // Add the body to the space so it will be simulated and move around.
    cpSpaceAddBody(space, ballBody);

    // Add a circle shape for the ball.
    // Shapes are always defined relative to the center of
    // gravity of the body they are attached to.
    // When the body moves or rotates, the shape will move with it.
    // Additionally, all of the cpSpaceAdd*() functions return
    // the thing they added so you can create and add in one go.
    cpShape *ballShape = cpSpaceAddShape(space, cpCircleShapeNew(ballBody, radius, cpvzero));
    ballShape.e = 0.0f; ballShape.u = 0.9f;

    bool finished=false;
    while(!finished)
    {
        // Chipmunk allows you to use a different timestep each frame,
        // but it works much better when you use a fixed timestep.
        // An excellent article on why fixed timesteps for game logic can
        // be found here: http://gafferongames.com/game-physics/fix-your-timestep/
        cpSpaceStep(space, 1.0f/60.0f);

        // print position
        writefln("pos %s,%s",ballBody.p.x,ballBody.p.y);

        // stop simulation once the ball touches the ground
        finished = (ballBody.p.y < -240 + radius);
    }

    // free our objects
    //cpSpaceFreeChildren(space);
    // free the space
    cpSpaceFree(space);
}
