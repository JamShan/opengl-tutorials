module tut_03_matrices;

import std.stdio;
import std.exception;
import std.math;

import deimos.glfw.glfw3;

import glwtf.input;
import glwtf.window;

import dgl;

import glad.gl.all;
import glad.gl.loader;

import gl3n.linalg;
import gl3n.math;

void on_glfw_error(int code, string msg)
{
    stderr.writefln("Error (%s): %s", code, msg);
}

enum width = 1024;
enum height = 768;

void main()
{
    enforce(glfwInit());
    scope (exit)
        glfwTerminate();

    // set the window to inivisible since it will briefly appear during testing.
    //~ glfwWindowHint(GLFW_VISIBLE, 0);

    Window window = createWindow("Tutorial 01", WindowMode.windowed, width, height);

    register_glfw_error_callback(&on_glfw_error);

    // antialiasing
    window.samples = 4;

    window.make_context_current();

    // Load all OpenGL function pointers via glad.
    enforce(gladLoadGL());

    // 9600 only supports up to 3.3
    // enforce(GLVersion.major == 3 && GLVersion.minor == 3);

    // resize window and make sure we update the viewport transform on a resize
    onWindowResize(width, height);
    window.on_resize.strongConnect(onWindowResize);

    // call our initialization routines
    initShaders();

    glfwSwapInterval(0);

    // todo: make sure onWindowResize calls this function
    // glfwGetFramebufferSize(window.window, &width, &height);

    while (!glfwWindowShouldClose(window.window))
    {
        /* Start rendering to the back buffer */
        render();

        /* Swap front and back buffers */
        window.swap_buffers();

        /* Poll for and process events */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }
}

///
void render()
{
    glClearColor(0.0f, 0.0f, 0.4f, 0.0f);  // dark-blue
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    theProgram.bind();

    enum matrixCount = 1;
    enum doTranspose = GL_TRUE;  // must be true when converting row_major to column_major
    glUniformMatrix4fv(MVPUniform.ID, matrixCount, doTranspose, &MVP[0][0]);

    Attribute vertexAttribute = Attribute(0);
    int size = 3;  // (x, y, z) per vertex
    GLenum type = GL_FLOAT;
    bool normalized = false;
    int stride = 0;
    int offset = 0;

    positionBuffer.bind(vertexAttribute, size, type, normalized, stride, offset);

    vertexAttribute.enable();

    int startIndex = 0;
    int vertexCount = 3;
    glDrawArrays(GL_TRIANGLES, startIndex, vertexCount);

    vertexAttribute.disable();
    positionBuffer.unbind();
    theProgram.unbind();
}

Program theProgram;

// vertices in GPU memory
GLBuffer positionBuffer;

Uniform MVPUniform;

mat4 MVP;

void print(string name, mat4 Mat0)
{
	writeln(name);
	writeln("mat4(");
	writefln("\tvec4(%2.3f, %2.3f, %2.3f, %2.3f)", Mat0[0][0], Mat0[0][1], Mat0[0][2], Mat0[0][3]);
	writefln("\tvec4(%2.3f, %2.3f, %2.3f, %2.3f)", Mat0[1][0], Mat0[1][1], Mat0[1][2], Mat0[1][3]);
	writefln("\tvec4(%2.3f, %2.3f, %2.3f, %2.3f)", Mat0[2][0], Mat0[2][1], Mat0[2][2], Mat0[2][3]);
	writefln("\tvec4(%2.3f, %2.3f, %2.3f, %2.3f))\n", Mat0[3][0], Mat0[3][1], Mat0[3][2], Mat0[3][3]);
}

void initShaders()
{
    theProgram = initGLProgram();
    positionBuffer = initPositionBuffer();

    // Note: this must be called when using the core profile,
    // and must be called before any other OpenGL call.
    GLuint vao;
	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

    // Get a handle for our "MVP" uniform
	MVPUniform = theProgram.getUniform("MVP");

    mat4 Projection;

    version (none)
    {
        // ortographic projection
        float left = -10.0;
        float right = 10.0;
        float bottom = -10.0;  // todo: check if this should be swapped with top
        float top = 10.0;
        float near = 0.0;
        float far = 100.0;
        Projection = mat4.orthographic(left, right, bottom, top, near, far);
    }

    // version (none)
    {
        // perspective projection
        float fov = 45.0f;
        float near = 0.1f;
        float far = 100.0f;
        // auto fovRadian = fov * (PI/180);
        Projection = mat4.perspective(width, height, fov, near, far);
    }

    // Camera matrix
	auto eye = vec3(4, 3, 3);     // Camera is at (4, 3, 3), in World Space
    auto target = vec3(0, 0, 0);  // and looks at the origin
    auto up = vec3(0, 1, 0);      // Head is up (set to 0, -1, 0 to look upside-down)
    mat4 View = mat4.look_at(eye, target, up);

    // Model matrix : an identity matrix (model will be at the origin)
	mat4 Model = mat4.identity();

    // Our ModelViewProjection : multiplication of our 3 matrices
	MVP = Projection * View * Model; // Remember, matrix multiplication is the other way around
}

string strVertexShader = q{
    #version 330 core

    // Input vertex data, different for all executions of this shader.
    layout(location = 0) in vec3 vertexPosition_modelspace;

    // Values that stay constant for the whole mesh.
    uniform mat4 MVP;

    void main()
    {
        // Output position of the vertex, in clip space : MVP * position
        gl_Position =  MVP * vec4(vertexPosition_modelspace, 1);
    }
};

string strFragmentShader = q{
	#version 330 core

    out vec3 color;

	void main()
	{
        color = vec3(1, 0, 0);
	}
};

Program initGLProgram()
{
    Shader[] shaders;

    shaders ~= Shader.fromText(ShaderType.vertex, strVertexShader);
    shaders ~= Shader.fromText(ShaderType.fragment, strFragmentShader);

	return new Program(shaders);
}

GLBuffer initPositionBuffer()
{
    const float[] vertexPositions =
    [
        // 3 vertices (x, y, z)
       -1.0f, -1.0f, 0.0f,
        1.0f, -1.0f, 0.0f,
        0.0f,  1.0f, 0.0f,
    ];

    return new GLBuffer(vertexPositions, UsageHint.staticDraw);
}

void delegate(int width, int height) onWindowResize;

shared static this()
{
    onWindowResize = (int width, int height)
    {
        int x = 0;
        int y = 0;
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
