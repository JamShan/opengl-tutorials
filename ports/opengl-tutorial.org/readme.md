# D2 Port of opengl-tutorial.org (work in progress)

The [opengl-tutorial.org] project is a set of C++ tutorials covering OpenGL v3.3+.

The included D [port][opengl-tutorial-port] contains the code samples which have been ported into D.

## Dependencies

You will need to install the following shared libraries:

- [glfw3]
- [SDL2]
- [SDL2 Image]
- [Assimp]

Make sure the shared libraries binaries are available in your `PATH` environment variable,
or alternatively copy the binaries to the `bin` folder where the samples are built.

## Building the samples

All of the samples in this repository can be built using [dub]:

```
# note: In an upcoming dub release this will be 'dub run :tut01'
$ dub run opengl-tutorial.org:tut01

# alternatively CD to a sample's directory and simply run dub
$ cd tutorials/01_window
$ dub
```

## License

Unless noted otherwise, the samples are distributed under the [WTFPL Public License][WTFPL_License], Version 2, December 2004.

[opengl-tutorial.org]: http://www.opengl-tutorial.org
[opengl-tutorial-port]: https://github.com/d-gamedev-team/opengl-tutorials/tree/master/ports/opengl-tutorial.org
[dub]: http://code.dlang.org/download
[WTFPL_License]: http://www.wtfpl.net/txt/copying
[glfw3]: http://www.glfw.org
[SDL2]: http://www.libsdl.org
[SDL2 Image]: https://www.libsdl.org/projects/SDL_image
[assimp]: http://assimp.sourceforge.net
