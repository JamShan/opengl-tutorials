# opengl-tutorials

## About

This is a collection of D ports of various C/C++/WebGL online OpenGL tutorials
and samples contained within OpenGL books, as well as any new D OpenGL examples.

This project seeks to be a hub of ready-to-compile OpenGL examples which will
make it easy for new D game developers to learn from and experiment with.

It is a long-term project and will be getting steady updates over time.

Homepage: https://github.com/d-gamedev-team/opengl-tutorials

## Target OpenGL version

These samples use OpenGL v3.x+ and do not cover immediate mode OpenGL.

## Hardware Requirements

Before building make sure you have an OpenGL v3.x+ compatible GPU card and the
latest device drivers.

## Platform support

- Tested run on Windows 7 x64 with x86 and x86_64 as the target architectures.

- Buildable on Linux x64, with x86_64 as target.
We have not been able to build with x86 as the target yet.
Additionally we weren't able to run the samples on Posix since
VirtualBox has poor OpenGL driver support.

Note: Use `-a x86` or `-a x86_64` when invoking **dub** to select the target architecture.

## Building

All of the samples in this repository can be built using [dub] and a recent (2.065+)
version of a D [compiler][compilers].

## List of OpenGL projects in this repository

### OpenGL Tutorial Ports

#### opengl-tutorial.org (work in progress)

The [opengl-tutorial.org] project is a set of C++ tutorials covering OpenGL v3.3+.

The included [D port][opengl-tutorial-port] contains code samples which have been ported into D.

[opengl-tutorial.org]: http://www.opengl-tutorial.org/
[opengl-tutorial-port]: https://github.com/d-gamedev-team/opengl-tutorials/tree/master/ports/opengl-tutorial.org

### Upcoming Ports

There are several D ports that are awaiting some cleanup and dubification,
the following are coming soon:

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
- http://www.humus.name/index.php?page=3D
- http://learningwebgl.com
- http://www.spacesimulator.net/wiki/index.php?title=3d_Engine_Programming_Tutorials
- http://en.wikibooks.org/wiki/OpenGL_Programming (Covers GL v2.x, but can be ported to 3.x)

Note: If you know of any other tutorials targetting OpenGL v3.x+ please file an issue
with a link to the tutorial, thanks!

Examples from the following books might be worth porting,
although these aren't planned yet:

- [Real-Time Rendering](http://www.realtimerendering.com/)
- [OpenGL Programming Guide (8th edition)](http://amzn.com/0321773039)
- [OpenGL SuperBible](http://www.openglsuperbible.com/)
- [OpenGL Shading Language](http://amzn.com/0321637631)
- [OpenGL 4.0 Shading Language Cookbook](http://amzn.com/1782167021)
- [OpenGL Development Cookbook](http://amzn.com/1849695040)
- [OpenGL Insights](http://amzn.com/1439893764)

WebGL-based tutorials and books also exist in great numbers,
and should be worth porting to D.

## License

Each tutorial or book has a license for the samples that it contains.
Check the individual D ports for licensing information.

[dub]: http://code.dlang.org/download
[Derelict3]: https://github.com/aldacron/Derelict3
[glad]: https://github.com/Dav1dde/glad
[compilers]: http://wiki.dlang.org/Compilers
