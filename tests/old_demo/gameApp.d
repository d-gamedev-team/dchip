
// written in the D programming language

/++
 +	Authors: Stephan Dilly, www.extrawurst.org
 +/

module gameApp;

import framework;

import drawSpace;

import dchip.all;

import samples.benchmark;
import samples.LogoSmash;
import samples.Simple;
import samples.PyramidStack;
import samples.ChipmunkDemo;
import samples.Plink;
import samples.Tumble;
import samples.PyramidTopple;
import samples.Planet;
import samples.Query;
import samples.OneWay;
import samples.Sensors;
import samples.Bounce;
import samples.Springies;
import samples.Joints;
import samples.MagnetsElectric;
import samples.Player;
import samples.Tank;
import samples.Pump;
import samples.TheoJansen;
import samples.UnsafeOps;

// using derelict bindings for sdl/opengl
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.sdl.sdl;

import std.stdio;
import core.thread;

//version = TIME_TRIAL;

cpVect			mousePos;
cpVect			arrowDirection;

bool key_up = false;
bool key_down = false;
bool key_left = false;
bool key_right = false;
bool key_space = false;

///
final class GameApp {

private:

    chipmunkDemo[]	demos;
    chipmunkDemo*	currentDemo;
    cpSpace*		space;
    int				ticks;
    int				step;
    bool			trial=false;
    bool			paused=false;
    cpBody*			mouseBody;
    cpConstraint*	mouseJoint;
    cpVect			mousePos_last;

    bool 	m_running = true;

    drawSpaceOptions options = {
        0,		// drawHash
        0,		// drawBB
        1,		// drawShapes
        4.0f,	// collisionPointSize
        0.0f,	// bodyPointSize
        1.5f,	// lineThickness
    };

    enum width = 1024;
    enum height = 780;

    void time_trial(int index, int count)
    {
        currentDemo = &demos[index];
        space = currentDemo.initFunc();

        auto start = .tickCount();

        foreach(i; 0..count)
            currentDemo.updateFunc(i);

        auto end = .tickCount();
        auto duration = (end - start);

        currentDemo.destroyFunc();

        writefln("Time(%s) = %s (%s)", cast(char)(index + 'a'), duration, currentDemo.name);
    }

    ///
    public void boot(string[] _args) {

        demos = [
            LogoSmash,
            //Simple,
            PyramidStack,
            Plink,
            Tumble,
            PyramidTopple,
            Bounce,
            Planet,
            Springies,
            Pump,
            TheoJansen,
            MagnetsElectric,
            UnsafeOps,
            Query,
            OneWay,
            Player,
            Sensors,
            Joints,
            Tank,
        ];

        foreach(arg; _args)
        {
            switch(arg)
            {
            case "-bench":
                demos = bench_list;
                break;
            case "-trial":
                trial = true;
                break;
            default:
                break;
            }
        }

        if(trial)
        {
            foreach(i, demo; demos)
            {
                time_trial(i, 1000);
            }

            m_running = false;

            return;
        }

        //setup framework
        bool useVsync = false;
        framework.startup("chipmunk'd by Stephan Dilly",width,height,useVsync);

        reshape(width,height);

        glEnableClientState(GL_VERTEX_ARRAY);

        runDemo(&demos[0]);

        mouseBody = cpBodyNew(INFINITY, INFINITY);
    }

    ///
    void runDemo(chipmunkDemo *demo)
    {
        std.c.stdlib.srand(45073);

        currentDemo = demo;

        ticks = 0;
        mouseJoint = null;
        //messageString[0] = '\0';
        //maxArbiters = 0;
        //maxPoints = 0;
        //maxConstraints = 0;
        space = demo.initFunc();

        //glutSetWindowTitle(demoTitle(index));
    }

    ///
    void reshape(int width, int height)
    {
        glViewport(0, 0, width, height);

        double scale = 0.5/cpfmin(width/640.0, height/480.0);
        double hw = width*scale;
        double hh = height*scale;

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(-hw, hw, -hh, hh, -1.0, 1.0);
        glTranslated(0.5, 0.5, 0.0);
    }

    ///
    public bool update() {

        if(!m_running) return m_running;

        if(!framework.processEvents(&keyEvent,&mouseMove,&mouseButtonEvent))
            return false;

        cpVect newPoint = cpvlerp(mousePos_last, mousePos, 0.25f);

        mouseBody.p = newPoint;
        mouseBody.v = cpvmult(cpvsub(newPoint, mousePos_last), 60.0f);
        mousePos_last = newPoint;

        if(!paused || step > 0){
            currentDemo.updateFunc(ticks++);
            step = (step > 1 ? step - 1 : 0);
        }

        // render

        glClearColor(1,1,1,1);

        glClear(GL_COLOR_BUFFER_BIT);

        DrawSpace(space, currentDemo.drawOptions ? currentDemo.drawOptions : &options);
        //drawInstructions();
        //drawInfo();
        //drawString(-300, -210, messageString);

        SDL_GL_SwapBuffers();

        return m_running;
    }

    ///
    public void shutdown() {

version(TIME_TRIAL){}else
{
        currentDemo.destroyFunc();

        framework.shutdown();
}
    }

    cpVect mouseToSpace(int x, int y)
    {
        GLdouble model[16];
        glGetDoublev(GL_MODELVIEW_MATRIX, model.ptr);

        GLdouble proj[16];
        glGetDoublev(GL_PROJECTION_MATRIX, proj.ptr);

        GLint view[4];
        glGetIntegerv(GL_VIEWPORT, view.ptr);

        GLdouble mx, my, mz;
        gluUnProject(x, height - y, 0.0f, model.ptr, proj.ptr, view.ptr, &mx, &my, &mz);

        return cpv(mx, my);
    }

    ///
    private void mouseMove(int x,int y)
    {
        mousePos = mouseToSpace(x,y);
    }

    ///
    private void mouseButtonEvent(int x,int y,bool _down)
    {
        if(_down){
            cpVect point = mouseToSpace(x,y);

            cpShape *shape = cpSpacePointQueryFirst(space, point, GRABABLE_MASK_BIT, CP_NO_GROUP);
            if(shape){
                cpBody *body_ = shape.body_;
                mouseJoint = cpPivotJointNew2(mouseBody, body_, cpvzero, cpBodyWorld2Local(body_, point));
                mouseJoint.maxForce = 50000.0f;
                mouseJoint.errorBias = 0.15f;
                cpSpaceAddConstraint(space, mouseJoint);
            }
        } else if(mouseJoint){
            cpSpaceRemoveConstraint(space, mouseJoint);
            cpConstraintFree(mouseJoint);
            mouseJoint = null;
        }
    }

    ///
    private void set_arrowDirection()
    {
        int x = 0, y = 0;

        if(key_up) y += 1;
        if(key_down) y -= 1;
        if(key_right) x += 1;
        if(key_left) x -= 1;

        arrowDirection = cpv(x, y);
    }

    ///
    private void keyEvent(int _key,bool _down)
    {
        int key = _key;

        if(_down)
        {
            int index = key - 'a';

            if(0 <= index && index < demos.length){
                runDemo(&demos[index]);
            } else if(key == '\r'){
                runDemo(currentDemo);
            } else if(key == 61){
                paused = !paused;
            } else if(key == 47){
                options.drawHash = !options.drawHash;
            } else if(key == '1'){
                step += 1;
            } else if(key == 92){
                options.drawBBs = !options.drawBBs;
            } else if(key == 27){
                m_running = false;
            } else if(key == 93){
                glEnable(GL_LINE_SMOOTH);
                glEnable(GL_POINT_SMOOTH);
                glEnable(GL_BLEND);
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                glHint(GL_LINE_SMOOTH_HINT, GL_DONT_CARE);
                glHint(GL_POINT_SMOOTH_HINT, GL_DONT_CARE);
            }
            else
            {
                if(key == SDLK_UP) key_up = true;
                else if(key == SDLK_DOWN) key_down = true;
                else if(key == SDLK_LEFT) key_left = true;
                else if(key == SDLK_RIGHT) key_right = true;
                else if(key == SDLK_SPACE) key_space = true;

                set_arrowDirection();
            }
        }
        else
        {
            if(key == SDLK_UP) key_up = false;
            else if(key == SDLK_DOWN) key_down = false;
            else if(key == SDLK_LEFT) key_left = false;
            else if(key == SDLK_RIGHT) key_right = false;
            else if(key == SDLK_SPACE) key_space = false;

            set_arrowDirection();
        }
    }
}

