
// written in the D programming language

/++
 +	Authors: Stephan Dilly, www.extrawurst.org
 +/

module main;

import gameApp;

import std.stdio;

///
int main(string[] args) {

    try {

        scope auto game = new GameApp();
        game.boot(args);

        //game loop
        while(true)
        {
            if(!game.update())
                break;
        }

        game.shutdown();
    }
    catch(Throwable o) {

        //write out whatever exception is thrown
        debug writefln("[exception] E: \"%s\"",o);

        return -1;
    }

    return 0;
}
