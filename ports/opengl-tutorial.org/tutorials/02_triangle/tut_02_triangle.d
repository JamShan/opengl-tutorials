/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_02_triangle;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/beginners-tutorials/tutorial-2-the-first-triangle
*/

import deimos.glfw.glfw3;

import glwtf.window;

import glad.gl.all;

import dgl;

import gltut.window;

/**
    Contains all of our OpenGL program state.
    This avoids the use of globals and
    makes the code more maintainable.
*/
struct ProgramState
{
    ///
    this(Window window)
    {
        this.window = window;
        initVertices();
        initShaders();
        initProgram();
        initAttributes();
        initVao();
    }

    /** Release all OpenGL resources. */
    ~this()
    {
        vertexBuffer.release();

        foreach (shader; shaders)
            shader.release();

        program.release();

        glfwTerminate();
    }

private:

    void initVertices()
    {
        const float[] positions =
        [
            // 3 vertices (x, y, z)
           -1.0f, -1.0f, 0.0f,
            1.0f, -1.0f, 0.0f,
            0.0f,  1.0f, 0.0f,
        ];

        this.vertexBuffer = new GLBuffer(positions, UsageHint.staticDraw);
    }

    void initShaders()
    {
        enum vertexShader = q{
            #version 330 core

            layout(location = 0) in vec3 vertexPosition_modelspace;

            void main()
            {
                gl_Position.xyz = vertexPosition_modelspace;
                gl_Position.w = 1.0;
            }
        };

        enum fragmentShader = q{
            #version 330 core

            out vec3 color;

            void main()
            {
                color = vec3(1, 0, 0);
            }
        };

        this.shaders ~= Shader.fromText(ShaderType.vertex, vertexShader);
        this.shaders ~= Shader.fromText(ShaderType.fragment, fragmentShader);
    }

    void initProgram()
    {
        this.program = new Program(shaders);
    }

    void initAttributes()
    {
        this.positionAttribute = program.getAttribute("vertexPosition_modelspace");
    }

    void initVao()
    {
        // Note: this must be called when using the core profile,
        // and it must be called before any other OpenGL call.
        // VAOs have a proper use-case but it's not shown here,
        // search the web for VAO documentation and check it out.
        GLuint vao;
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
    }

    // unused in this tutorial
    Window window;

    // reference to a GPU buffer containing the vertices.
    GLBuffer vertexBuffer;

    // kept around for cleanup.
    Shader[] shaders;

    // our main GL program.
    Program program;

    // The vertex positions attribute
    Attribute positionAttribute;
}

/** Our main render routine. */
void render(ref ProgramState state)
{
    glClearColor(0.0f, 0.0f, 0.4f, 0.0f);  // dark blue
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    state.program.bind();

    enum int size = 3;  // (x, y, z) per vertex
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;
    state.vertexBuffer.bind(state.positionAttribute, size, type, normalized, stride, offset);

    state.positionAttribute.enable();
    enum startIndex = 0;
    enum vertexCount = 3;
    glDrawArrays(GL_TRIANGLES, startIndex, vertexCount);

    state.positionAttribute.disable();
    state.vertexBuffer.unbind();
    state.program.unbind();
}

void main()
{
    auto window = createWindow("Tutorial 02 - Render Triangle");

    auto state = ProgramState(window);

    while (!glfwWindowShouldClose(window.window))
    {
        /* Render to the back buffer. */
        render(state);

        /* Swap front and back buffers. */
        window.swap_buffers();

        /* Poll for and process events. */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }
}
