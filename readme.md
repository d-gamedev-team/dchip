# dchip

This is a D2 port of the [Chipmunk2D](http://chipmunk2d.net/) library.
Currently it targets Chipmunk2D v6.2.1.

**Note:** Currently dchip is in a pre-alpha state.
Once it's tested on multiple platforms a `dub` package will be added.

Homepage: https://github.com/AndrejMitrovic/dchip

## Authors

This D2 port has been created by [Andrej Mitrovic].

The older v5.3.5 port was created by [Stephan Dilly],
and is being maintained here: https://bitbucket.org/Extrawurst/chipmunkd/wiki/Home

**Note:** The two ports are **not** backward-compatible with each other.

Samples were created by [Stephan Dilly], and updated to the new API by [Andrej Mitrovic].

[Stephan Dilly]: http://www.extrawurst.org
[Andrej Mitrovic]: https://github.com/AndrejMitrovic

## Building

Currently only the `build.bat` files are provided. A dub package will be added later
which will allow building in a cross-platform way.

### Version switches

The following `-version=VERSION` switches are supported:

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
turning this switch on will print out warnings to stderr.

- `CHIP_USE_DOUBLES`

By default all floating-point types are declared as `float`. Enabling this switch will use
`double` types instead.

**Note:** Regardless of this switch the D compiler will still use `real`'s for floating-point calculations,
meaning that enabling this switch will likely **not** give you a big improvement in accuracy. On the
other hand, using `double`'s will use twice as much memory and could lead to a performance
degradation.

## Links

- Chipmunk2D [homepage](http://chipmunk2d.net/).
- Chipmunk2D [github page](https://github.com/slembcke/Chipmunk2D).
- Chipmunk2D [v6.2.1 documentation](http://chipmunk-physics.net/release/Chipmunk-6.x/Chipmunk-6.2.1-Docs/).

## License

Distributed under the MIT License. See the accompanying file LICENSE.txt.
