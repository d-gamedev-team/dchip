# dchip

![DChip](https://raw.github.com/AndrejMitrovic/dchip/master/screenshots/dchip.png)

This is a D2 port of the [Chipmunk2D](http://chipmunk2d.net/) game physics library.
Currently it targets version **6.2.1**.

DChip is a platform-independent library with no dependencies.

The sample projects have dependencies on either [GLFW] or [SDL],
and the OpenGL Utility Library (GLU).

Homepage: https://github.com/AndrejMitrovic/dchip

[SDL]: http://www.libsdl.org
[GLFW]: http://www.glfw.org

## Authors

This D2 port has been created by [Andrej Mitrovic].

The older v5.3.5 port was created by [Stephan Dilly],
and is being maintained here: https://bitbucket.org/Extrawurst/chipmunkd/wiki/Home

**Note:** The two ports are **not** compatible with each other.

The older [SDL]-based samples were created by [Stephan Dilly],
and updated to the new API by [Andrej Mitrovic].

The newer samples use [GLFW] and were written by [Scott Lembcke]
and [Howling Moon Software], and were ported to D by [Andrej Mitrovic].

[Scott Lembcke]: http://slembcke.net
[Howling Moon Software]: http://howlingmoonsoftware.com
[Stephan Dilly]: http://www.extrawurst.org
[Andrej Mitrovic]: https://github.com/AndrejMitrovic

[SDL]: http://www.libsdl.org
[GLFW]: http://www.glfw.org

## Building

### Using dub

You can use [dub] to make this library a dependency for your project.

[dub]: http://code.dlang.org/about

### Using Windows-specific build scripts

You can use the `build.bat` script in the `dchip\build\` folder.

### Version switches

The following `-version=NAME` switches are supported:

- `CHIP_ALLOW_PRIVATE_ACCESS`

Make private or package fields public. This switch will enable you to directly
manipulate internal fields. However this is not future-compatible since these
fields might be reordered or changed in the future. You should prefer to use
accessor methods unless performance demands that you directly manipulate
internal fields.

- `CHIP_ENABLE_WARNINGS`

Enable internal library warnings. When the internal state is in an
unexpected state turning this switch on will print out warnings to
the standard error stream (`stderr`).

- `CHIP_USE_DOUBLES`

By default all floating-point types are declared as `float`. Enabling this
switch will use `double` types instead.

**Note:** Regardless of this switch, the D compiler will still use `real`'s
for floating-point calculations, meaning that enabling this switch will
likely **not** give you a big improvement in accuracy. On the other hand
using `double`'s will use twice as much memory and could lead to a
performance degradation.

**Warning:** There is a large performance hit when enabling this switch and
using DMD.

## Running the tests

Most tests require the [GLFW] library. See the [GLFW] homepage on how to
obtain this library.

### Using dub

Compile and run one of the examples via:

```
# Just a simple hello world.
dub --config=hello_world

# Showcases a simple iteration of the physics engine without any drawing.
dub --config=simple

# Contains a series of visual and interactive demos, selectable with the keyboard.
# Select each of the demo's by pressing the keys 'a' through 'y'.
dub --config=demo

# Similar to the above, but demos were based on the older v5.3.5 version and they
# use the [SDL] library (which means you'll have to install [SDL] to run it).
dub --config=old_demo

# Build with another compiler, in release mode (Run `dub build --help` for more help)
dub --compiler=ldc2 --build=release
```

**Note**: The `old_demo` examples are based on the v5.3.5 version and require
[SDL] rather than [GLFW].

**Note**: If you're using Windows you might get dub errors when automatically
running the samples. The samples should still be built and located in the
`dchip\tests\bin` subfolder.

**Note**: As of 04 February 2014, building with LDC2 from the latest prepackaged
binary of LDC2 on Windows might produce crashing applications.
However the latest LDC2 built from source (commit `704ab30001582dc67084e6ea8967e61e8112d595`)
using the [MinGW instructions](http://wiki.dlang.org/Building_LDC_on_MinGW_x86)
is known to work.

### Using Windows-specific build scripts

There are `build.bat` scripts you can use to build the samples:

```
$ cd path\to\dchip\tests

# Showcases a simple iteration of the physics engine without any drawing
$ build\build.bat simple.d simple.d

# Contains a series of visual and interactive demos, selectable with the keyboard.
# Select each of the demo's by pressing the keys 'a' through 'y'.
$ build\build.bat demo_run demo_run.d

# Similar to above, but demos were based on the older v5.3. 5version and they also
# use the [SDL] library (which means you'll have to get [SDL] to run it)
$ cd old_demo
$ build.bat
```

[SDL]: http://www.libsdl.org
[GLFW]: http://www.glfw.org

## Documentation

Since `dchip` is a straight port of the C library to D all existing C-based
documentation should be applicable and easily transferable to D with very little
to no code modification. In particular, the Chipmunk2D documentation will
come in handy:

- Chipmunk2D [v6.2.1 documentation](http://chipmunk-physics.net/release/Chipmunk-6.x/Chipmunk-6.2.1-Docs/).

## Usage

You can import the `dchip.all` module to bring in the entire library at your disposal.
Alternatively if you're using the latest compiler (e.g. 2.064+ or git-head) you may
use the new package module feature and import `dchip`.

Most dchip types have getter and setter functions to access and modify internal fields,
for example the `cpArbiter`'s internal fields such as the `e` field for elasticity
can be accessed and manipulated with this code:

```
cpArbiter * arb
cpFloat elasticity = cpArbiterGetElasticity(arb);  // get the internal 'e' field
elasticity += 1.0;
cpArbiterSetElasticity(arb, elasticity);  // set the internal 'e' field
```

The getters and setters are auto-generated via a mixin template, such as:

```
// Inject 'cpArbiterGetElasticity' and 'cpArbiterSetElasticity' which
// operate on a `cpFloat` type.
mixin CP_DefineArbiterStructProperty!(cpFloat, "e", "Elasticity");
```

Some dchip types only define getters and not setters, via:

```
// Inject 'cpBodyGetRot', which returns the internal 'rot' field of
// type 'cpVect'.
mixin CP_DefineBodyStructGetter!(cpVect, "rot", "Rot");
```

As mentioned in the `Building` section above, passing the `CHIP_ALLOW_PRIVATE_ACCESS`
version flag allows you to access all fields directly rather than through getter and
setter functions. However, using the internal fields directly is not future-proof as
these internal fields are not part of the public API and may change at any future
version release.

Additionally, setter functions typically perform additional actions, for example
`cpBody` setters usually call `cpBodyActivate` before assigning to an internal field,
followed by a call to `cpBodyAssertSane`. If you ever have bodies that seem to
"hang in the air", they might be sleeping, so make sure you call `cpBodyActivate`
before manipulating internal fields.

## Links

- Chipmunk2D [homepage](http://chipmunk2d.net/).
- Chipmunk2D [github page](https://github.com/slembcke/Chipmunk2D).
- Chipmunk2D [v6.2.1 documentation](http://chipmunk-physics.net/release/Chipmunk-6.x/Chipmunk-6.2.1-Docs/).

## License

Distributed under the MIT License. See the accompanying file LICENSE.txt.
