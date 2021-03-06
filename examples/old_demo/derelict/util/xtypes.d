/*

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

*/
module derelict.util.xtypes;

version (freebsd)
{
    version = GLX;
}

else version (FreeBSD)
{
    version = GLX;
}

else version (linux)
{
    version = GLX;
}

version(GLX)
{
    alias int  Bool;
    alias uint VisualID;
    alias byte*   XPointer;

    alias void Display;
    alias uint XID;
    alias XID Pixmap;
    alias XID Font;
    alias XID Window;

    struct XExtData
    {
        int number;
        XExtData* next;
        extern(C) int function(XExtData*) free_private;
        XPointer private_data;
    }

    struct Visual
    {
        XExtData* ext_data;
        VisualID  visualid;
        int       _class;
        uint      red_mask, green_mask, blue_mask;
        int       bits_per_rgb;
        int       map_entries;
    }

    struct XVisualInfo
    {
        Visual   *visual;
        VisualID visualid;
        int      screen;
        int      depth;
        int      _class;
        uint     red_mask;
        uint     green_mask;
        uint     blue_mask;
        int      colormap_size;
        int      bits_per_rgb;
    }
}
