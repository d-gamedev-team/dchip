# dchip

This is a D2 port of the [Chipmunk2D](http://chipmunk2d.net/) library.
Currently it targets version **6.2.1**.

Currently dchip has only been tested on Windows,
but has no platform-dependent code other than a
few build scripts for the samples.

Homepage: https://github.com/AndrejMitrovic/dchip

## Authors

This D2 port has been created by [Andrej Mitrovic].

The older v5.3.5 port was created by [Stephan Dilly],
and is being maintained here: https://bitbucket.org/Extrawurst/chipmunkd/wiki/Home

**Note:** The two ports are **not** compatible with each other.

The older SDL-based samples were created by [Stephan Dilly], and updated to the new API by [Andrej Mitrovic].

The newer samples use GLFW and were written by [Scott Lembcke] and [Howling Moon Software],
and ported to D by [Andrej Mitrovic].

[Scott Lembcke]: http://slembcke.net
[Howling Moon Software]: http://howlingmoonsoftware.com
[Stephan Dilly]: http://www.extrawurst.org
[Andrej Mitrovic]: https://github.com/AndrejMitrovic

## Building

You can use [dub] to make this library a dependency for your project.

Alternatively if you're on Windows you may use the various `build.bat` scripts.

[dub]: http://code.dlang.org/about

### Version switches

The following `-version=NAME` switches are supported:

- `CHIP_ENABLE_UNITTESTS`

Enable unittest blocks.
By default unittest blocks are not compiled-in, leading to huge savings in compilation time.

**Note:** The `-unittest` flag still needs to be passed to run the tests.

- `CHIP_ALLOW_PRIVATE_ACCESS`

Make private or package fields public. This switch will enable you to directly
manipulate internal fields. However this is not future-compatible since these fields might
be reordered or changed in the future. You should prefer to use accessor methods unless
performance demands that you directly manipulate internal fields.

- `CHIP_ENABLE_WARNINGS`

Enable internal library warnings. When the internal state is in an unexpected state
turning this switch on will print out warnings to the standard error stream (`stderr`).

- `CHIP_USE_DOUBLES`

By default all floating-point types are declared as `float`. Enabling this switch will use
`double` types instead.

**Note:** Regardless of this switch, the D compiler will still use `real`'s for floating-point calculations,
meaning that enabling this switch will likely **not** give you a big improvement in accuracy. On the
other hand, using `double`'s will use twice as much memory and could lead to a performance
degradation.

**Warning:** Don't enable this switch if using DMD, the performance degradation is unreal.

## Running the tests

The tests require the `glfw3.dll` library. See the [glfw] homepage on how to obtain it.

Examples of building the samples:

```
$ cd path\to\dchip\tests

# Showcases a simple iteration of the physics engine without any drawing
$ build\build.bat simple.d simple.d

# Contains a serious of visual and interactive demos, selectable with the keyboard
# Select each demo by pressing the key such as 'a' or upward (e.g. 'a', 'b', 'c', etc..)
$ build\build.bat demo_run demo_run.d

# Similar to above, but demos were based on the older v5.3.5. release and they also
# use the SDL library (which means you'll have to get `SDL.dll` to run it)
$ cd old_demo
$ build.bat
```

[glfw]: http://www.glfw.org/

## Links

- Chipmunk2D [homepage](http://chipmunk2d.net/).
- Chipmunk2D [github page](https://github.com/slembcke/Chipmunk2D).
- Chipmunk2D [v6.2.1 documentation](http://chipmunk-physics.net/release/Chipmunk-6.x/Chipmunk-6.2.1-Docs/).

## License

Distributed under the MIT License. See the accompanying file LICENSE.txt.
