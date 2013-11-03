
// written in the D programming language

/++
 +	Authors: Stephan Dilly, www.extrawurst.org
 +/

module framework;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;

import std.string;
import std.stdio;

void startup(string _title,int _width,int _height,bool useVsync=true)
{
    DerelictGL.load();
    DerelictGLU.load();
    DerelictSDL.load();

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) < 0)
    {
        throw new Exception("Failed to initialize SDL");
    }

    // Enable key repeating
    if ((SDL_EnableKeyRepeat(SDL_DEFAULT_REPEAT_DELAY, SDL_DEFAULT_REPEAT_INTERVAL)))
    {
        throw new Exception("Failed to set key repeat");
    }

    //enable to get ascii/unicode info of key event
    SDL_EnableUNICODE(1);

    // Set the OpenGL attributes
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 6);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_SWAP_CONTROL, cast(int)useVsync);

    // Set the window title
    SDL_WM_SetCaption(cast(char*)toStringz(_title), null);

    int mode = SDL_OPENGL;

    // Now open a SDL OpenGL window with the given parameters
    if (SDL_SetVideoMode(_width, _height, 32, mode) is null)
    {
        throw new Exception("Failed to open SDL window");
    }

    /** Enable anti-aliasing by default. */
    glEnable(GL_LINE_SMOOTH);
    glEnable(GL_POINT_SMOOTH);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glHint(GL_LINE_SMOOTH_HINT, GL_DONT_CARE);
    glHint(GL_POINT_SMOOTH_HINT, GL_DONT_CARE);
}

alias void delegate(int,int,bool) MouseButton;
alias void delegate(int,int) MouseMove;
alias void delegate(int,bool) KeyEvent;
public bool processEvents(KeyEvent _keyevent,MouseMove _mmove,MouseButton _mbutton)
{
    SDL_Event event;
    while (SDL_PollEvent(&event))
    {
        switch (event.type)
        {
            case SDL_KEYUP:
            case SDL_KEYDOWN:
                _keyevent(event.key.keysym.sym,event.type == SDL_KEYDOWN);
                break;

            case SDL_MOUSEMOTION:
                _mmove(event.motion.x,event.motion.y);
                break;

            case SDL_MOUSEBUTTONUP:
            case SDL_MOUSEBUTTONDOWN:
                _mbutton(event.button.x,event.button.y,event.type == SDL_MOUSEBUTTONDOWN);
                break;

            case SDL_QUIT:
                return false;

            default:
                break;
        }
    }

    return true;
}

void shutdown()
{
    SDL_Quit();
}

version (Win32)
{
    import std.c.windows.windows;

    static long winfrequ;

    static this()
    {
        QueryPerformanceFrequency(&winfrequ);
    }

    ulong tickCount(){
        long ret;
        QueryPerformanceCounter(&ret);
        return (cast(ulong)(cast(float)ret / winfrequ * 1000));
    }
}
else version (linux)
{
    import std.c.linux.linux;

    ulong tickCount(){

        timeval val;
        gettimeofday(&val,null);

        //return time(null);
        return val.tv_usec/1000;
    }
}
else version (OSX)
{
    import std.date;

    ulong tickCount(){

         return cast(ulong)getUTCtime();
    }
}
