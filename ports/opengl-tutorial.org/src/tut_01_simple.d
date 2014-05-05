module tut_01_simple;

import std.stdio;
import std.exception;

import deimos.glfw.glfw3;

import glwtf.input;
import glwtf.window;

import dgl;

import glad.gl.all;
import glad.gl.loader;

void on_glfw_error(int code, string msg)
{
    stderr.writefln("Error (%s): %s", code, msg);
}

void main()
{
    enforce(glfwInit());
    scope (exit)
        glfwTerminate();

    int width = 640;
    int height = 480;
    Window window = createWindow("Tutorial 01", WindowMode.windowed, width, height);

    register_glfw_error_callback(&on_glfw_error);

    window.samples = 4;

    window.make_context_current();

    // Load all OpenGL function pointers via glad.
    enforce(gladLoadGL());

    //~ enforce(GLVersion.major >= 3);

    enforce(glViewport !is null);

    // resize window and make sure we update the viewport transform on a resize
    onWindowResize(width, height);

    window.on_resize.strongConnect(onWindowResize);

    // call our initialization routines
    init();

    glfwSwapInterval(0);

    // todo: make sure onWindowResize calls this function
    // glfwGetFramebufferSize(window.window, &width, &height);

    while (!glfwWindowShouldClose(window.window))
    {
        /* Start rendering to the back buffer */
        display();

        /* Swap front and back buffers */
        window.swap_buffers();

        /* Poll for and process events */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }

    uninit();
}

/* The render function */
void display()
{
    /* clear the screen */
	glClearColor(0.0f, 0.0f, 0.0f, 0.0f);  // set clear color state
	glClear(GL_COLOR_BUFFER_BIT);  // clear the buffer with the color

    // This is how data flows down the pipeline in OpenGL. When rendering starts, vertex data in a buffer object is read based on setup work done by glVertexAttribPointer. This function describes where the data for an attribute comes from.

    // Each input to a vertex shader has an index location called an attribute index. The input in this shader was defined with this statement:

    // layout(location = 0) in vec4 position;

    // In code, when referring to attributes, they are always referred to by attribute index. The functions glEnableVertexAttribArray, glDisableVertexAttribArray, and glVertexAttribPointer all take as their first parameter an attribute index. We assigned the attribute index of the position attribute to 0 in the vertex shader, so the call to glEnableVertexAttribArray(0) enables the attribute index for the position attribute.

    /**
        Program object:
        An object in the OpenGL API that represents the full sequence of
        all shader processing to be used when rendering.
        Program objects can be queried for attribute locations and various other information about the program. They also contain some state that will be seen in later tutorials.
    */
    theProgram.bind();

    // attribute index location, this can be set in the shader, e.g. layout(location = 0),
    // but can also be retrieved by a getAttribute call from the program.
    Attribute vertexAttribute = Attribute(0);

    int size = 4;  // a single piece of data: (x, y, z, w) per vertex in vertexPositions
    GLenum type = GL_FLOAT;  // size of each element
    bool normalized = false;
    int stride = 0;  // no space between each set of 4 values
    int offset = 0;  // our data begins at the beginning of the object

    // bind this buffer to the attribute (the shader input variable)
    positionBuffer.bind(vertexAttribute, size, type, normalized, stride, offset);

    // the vertex attribute variable must be enabled before rendering
    vertexAttribute.enable();

    /*
        Once in window coordinates, OpenGL can now take these 3 vertices and scan-convert it into a series of fragments. In order to do this however, OpenGL must decide what the list of vertices represents.

        OpenGL can interpret a list of vertices in a variety of different ways. The way OpenGL interprets vertex lists is given by the draw command:

        glDrawArrays(GL_TRIANGLES, 0, 3);
    */

    int startIndex = 0;
    int vertexCount = 6;

    // GL_TRIANGLES: for every new 3 vertices interpret this as a unique separate rectangle
    glDrawArrays(GL_TRIANGLES, startIndex, vertexCount);

    vertexAttribute.disable();
    positionBuffer.unbind();
    theProgram.unbind();
}

Program theProgram;

/* Called after the window and OpenGL are initialized. Called exactly once, before the main loop. */
void init()
{
    InitializeProgram();
    InitializeVertexBuffer();

    /// Note: this must be called when using the core profile
    GLuint vao;
	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);
}

void uninit()
{
    theProgram.release();
    positionBuffer.release();

    foreach (shader; shaders)
        shader.release();
}

/**
    Notes:
    - Each invocation of a vertex shader operates on a single vertex.
    - This shader must output, among any other user-defined outputs, a clip-space position for that vertex.
    - gl_Position - This is a variable that is not defined in the shader but is a standard variable defined in every vertex shader
    - gl_Position is defined as 'out vec4 gl_Position'
    - The positions of the triangle's vertices in clip space are called clip coordinates.
    - A position in clip space has four coordinates. The first three are the usual X, Y, Z positions; the fourth is called W. This last coordinate actually defines what the extents of clip space are for this vertex.
    - Inputs to a vertex shader are called vertex attributes.
*/
string strVertexShader = q{
	#version 330

	layout(location = 0) in vec4 position;

	void main()
	{
        gl_Position = position;
	}
};

/**
    Notes:
    - A fragment shader is used to compute the output color(s) of a fragment. The inputs of a fragment shader include the window-space XYZ position of the fragment.
    - Though all fragment shaders are provided the window-space position of the fragment, this one does not need it, so it doesn't use it.
*/
string strFragmentShader = q{
	#version 330

    out vec4 outputColor;

	void main()
	{
        outputColor = vec4(1.0f, 1.0f, 1.0f, 1.0f);
	}
};

Shader[] shaders;

void InitializeProgram()
{
    shaders ~= Shader.fromText(ShaderType.vertex, strVertexShader);
    shaders ~= Shader.fromText(ShaderType.fragment, strFragmentShader);

	theProgram = new Program(shaders);
}

// vertices in GPU memory
GLBuffer positionBuffer;

void InitializeVertexBuffer()
{
    const float[] vertexPositions =
    [
        // 3 vertices (x, y, z, w)
         0.75f,  0.75f, 0.0f, 1.0f,
         0.75f, -0.75f, 0.0f, 1.0f,
        -0.75f, -0.75f, 0.0f, 1.0f,

        // another 3 vertices
        -1, 0.5, 0.0f, 1.0f,
        -0.5, 0.5, 0.0f, 1.0f,
        -0.75, 0.8, 0.0f, 1.0f,
    ];

    positionBuffer = new GLBuffer(vertexPositions, UsageHint.staticDraw);
}

void delegate(int width, int height) onWindowResize;

shared static this()
{
    /* This tells OpenGL what area of the available area we are rendering to. In this case, we change it to match the full available area. Without this function call, resizing the window would have no effect on the rendering. */
    onWindowResize = (int width, int height)
    {
        // bottom-left position
        int x = 0;
        int y = 0;

        /**
            This function defines the current viewport transform.
            It defines as a region of the window, specified by the
            bottom-left position and a width/height.

            Note about viewport transform:
            The process of transforming vertex data from normalized device coordinate space to window space. It specifies the viewable region of a window.
        */
        glViewport(x, y, width, height);
    };
}

enum WindowMode
{
    fullscreen,
    windowed,
}

/* Wrapper around the glwtf API. */
Window createWindow(string windowName, WindowMode windowMode, int width, int height)
{
    auto window = new Window();
    auto monitor = windowMode == WindowMode.fullscreen ? glfwGetPrimaryMonitor() : null;
    auto cv = window.create_highest_available_context(width, height, windowName, monitor, null, GLFW_OPENGL_CORE_PROFILE);
    return window;
}
