# opengl-tutorials

This is a collection of of D OpenGL Tutorials and D ports of C/C++/WebGL samples.

## About

These samples use OpenGL v3.x+, and will not cover the outdated immediate mode OpenGL.

When building make sure you have an OpenGL v3.x+ compatible GPU card and the latest device drivers installed.

## List of Tutorials and Ports

### Ports

#### opengl-tutorial.org

The [opengl-tutorial-web] project is a set of C++ tutorials covering OpenGL v3.3+.
This [port][opengl-tutorial-port] contains all of the code samples which have been ported into D.

[opengl-tutorial-web]: http://www.opengl-tutorial.org/
[opengl-tutorial-port]: https://raw.github.com/AndrejMitrovic/opengl-tutorials/ports/opengl-tutorial.org

## Building

All of the samples in this repository can be built using [dub].

## License

Unless noted otherwise, samples are distributed under the [Boost Software License][BoostLicense], Version 1.0.

See the accompanying file [license.txt](https://raw.github.com/AndrejMitrovic/dtk/master/license.txt) or an online copy [here][BoostLicense].

Note that samples which were ported from existing tutorials likely have their own specific license,
see their accompanying license headers for more info.

[dub]: http://code.dlang.org/download
[BoostLicense]: http://www.boost.org/LICENSE_1_0.txt
[Derelict3]: https://github.com/aldacron/Derelict3
[glad]: https://github.com/Dav1dde/glad
