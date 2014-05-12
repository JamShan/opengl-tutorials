# opengl-tutorials

## About

This is a collection of D ports of various C/C++/WebGL online OpenGL tutorials
and samples contained within OpenGL books, as well as any new D OpenGL examples.

This project seeks to be a hub of ready-to-compile OpenGL examples which will
make it easy for new D game developers to learn from and experiment with.

It is a long-term project and will be getting steady updates over time.

Homepage: https://github.com/AndrejMitrovic/opengl-tutorials

## Target OpenGL version

These samples use OpenGL v3.x+ and do not cover the dated immediate mode OpenGL.

## Hardware Requirements

Before building make sure you have an OpenGL v3.x+ compatible GPU card and the
latest device drivers.

## Platform support

- Can build and run on Windows 7 x64 with x86 and x86_64 as the target architectures.

- Can build on Linux x64, with x86_64 as target.
I was not able to build with x86 as the target.
Additionally I wasn't able to run the samples since VirtualBox has poor OpenGL driver support.

Note: Use `-a x86` or `-a x86_64` when invoking **dub** to select the target architecture.

## Building

All of the samples in this repository can be built using [dub] and a recent
version of a D [compiler][compilers].

## List of OpenGL projects in this repository

### OpenGL Tutorial Ports

#### opengl-tutorial.org (work in progress)

The [opengl-tutorial.org] project is a set of C++ tutorials covering OpenGL v3.3+.

The included D [port][opengl-tutorial-port] contains all of the code samples which have been ported into D.

[opengl-tutorial.org]: http://www.opengl-tutorial.org/
[opengl-tutorial-port]: https://github.com/AndrejMitrovic/opengl-tutorials/tree/master/ports/opengl-tutorial.org

### Upcoming Ports

There are several D ports that are awaiting some cleanup and dub-ification,
the following will be coming soon:

- http://www.arcsynthesis.org/gltut
- http://open.gl

### Planned Ports

- http://www.antongerdelan.net/opengl
- http://www.swiftless.com/opengl4tuts.html
- http://www.swiftless.com/glsltuts.html
- http://ogldev.atspace.co.uk/
- http://duriansoftware.com/joe/An-intro-to-modern-OpenGL.-Table-of-Contents.html
- http://www.lighthouse3d.com/tutorials/glsl-core-tutorial/
- http://www.lighthouse3d.com/cg-topics/code-samples/
- http://www.mbsoftworks.sk/index.php?page=tutorials
- http://www.mbsoftworks.sk/index.php?page=demos

Note: If you know of any other tutorials targetting OpenGL v3.x+ please file an issue
with a link to the tutorial, thanks!

Additionally examples from the following books might be worth porting,
although these aren't planned yet:

- Real-Time Rendering
- OpenGL Programming Guide
- OpenGL SuperBible
- OpenGL Shading Language
- OpenGL 4.0 Shading Language Cookbook
- OpenGL Development Cookbook
- OpenGL Insights

WebGL tutorials and books also exist in great numbers,
although they might be more difficult to port to D due to the
use of Javascript / HTML5.

## License

Unless noted otherwise, samples are distributed under the [Boost Software License][BoostLicense], Version 1.0.

Note that samples which were ported from existing tutorials likely have their own specific license.

See their accompanying license headers for more info.

[dub]: http://code.dlang.org/download
[BoostLicense]: http://www.boost.org/LICENSE_1_0.txt
[Derelict3]: https://github.com/aldacron/Derelict3
[glad]: https://github.com/Dav1dde/glad
[compilers]: http://wiki.dlang.org/Compilers
