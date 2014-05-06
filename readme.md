# opengl-tutorials

This is a collection of D OpenGL Tutorials and D ports of C/C++/WebGL samples.

## About

These samples use OpenGL v3.x+ and do not cover the outdated immediate mode OpenGL.

When building make sure you have an OpenGL v3.x+ compatible GPU card and the latest device drivers.

## List of Tutorials and Ports

### Ports

#### Upcoming Ports

There are several D ports that are awaiting some cleanup and dub-ification,
these will be coming soon:

- http://www.arcsynthesis.org/gltut
- http://open.gl

#### Planned Ports

- http://www.antongerdelan.net/opengl
- http://www.swiftless.com/opengl4tuts.html
- http://www.swiftless.com/glsltuts.html
- http://ogldev.atspace.co.uk/
- http://duriansoftware.com/joe/An-intro-to-modern-OpenGL.-Table-of-Contents.html
- http://www.lighthouse3d.com/tutorials/glsl-core-tutorial/

#### opengl-tutorial.org (work in progress)

The [opengl-tutorial.org] project is a set of C++ tutorials covering OpenGL v3.3+.

The included D [port][opengl-tutorial-port] contains all of the code samples which have been ported into D.

[opengl-tutorial.org]: http://www.opengl-tutorial.org/
[opengl-tutorial-port]: https://github.com/AndrejMitrovic/opengl-tutorials/tree/master/ports/opengl-tutorial.org

## Building

All of the samples in this repository can be built using [dub].

## License

Unless noted otherwise, samples are distributed under the [Boost Software License][BoostLicense], Version 1.0.

Note that samples which were ported from existing tutorials likely have their own specific license.

See their accompanying license headers for more info.

[dub]: http://code.dlang.org/download
[BoostLicense]: http://www.boost.org/LICENSE_1_0.txt
[Derelict3]: https://github.com/aldacron/Derelict3
[glad]: https://github.com/Dav1dde/glad
