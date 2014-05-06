/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module code.tut_02_triangle;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/beginners-tutorials/tutorial-2-the-first-triangle
*/

import deimos.glfw.glfw3;

import dgl;

import code.helper;

/// Contains all of our state. Avoids using globals.
struct ProgramState
{
    /// Use initProgramState to get an instance.
    @disable this();

    /** Release all GL resources. */
    ~this()
    {
        vertices.release();

        foreach (shader; shaders)
            shader.release();

        program.release();
    }

private:

    /** Explicit ctor. Use initProgramState instead. */
    this(int)
    {
        initVertices();
        initShaders();
        initProgram();
        initAttributes();
        initVao();
    }

    void initVertices()
    {
        const float[] positions =
        [
            // 3 vertices (x, y, z)
           -1.0f, -1.0f, 0.0f,
           1.0f, -1.0f, 0.0f,
           0.0f,  1.0f, 0.0f,
        ];

        vertices = new GLBuffer(positions, UsageHint.staticDraw);
    }

    void initShaders()
    {
        enum strVertexShader = q{
            #version 330 core

            layout(location = 0) in vec3 vertexPosition_modelspace;

            void main()
            {
                gl_Position.xyz = vertexPosition_modelspace;
                gl_Position.w = 1.0;
            }
        };

        enum strFragmentShader = q{
            #version 330 core

            out vec3 color;

            void main()
            {
                color = vec3(1, 0, 0);
            }
        };

        shaders ~= Shader.fromText(ShaderType.vertex, strVertexShader);
        shaders ~= Shader.fromText(ShaderType.fragment, strFragmentShader);
    }

    void initProgram()
    {
        program = new Program(shaders);
    }

    void initAttributes()
    {
        positionAttribute = program.getAttribute("vertexPosition_modelspace");
    }

    void initVao()
    {
        // Note: this must be called when using the core profile,
        // and must be called before any other OpenGL call.
        GLuint vao;
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
    }

    // reference to a GPU buffer containing the vertices.
    GLBuffer vertices;

    // kept around for cleanup.
    Shader[] shaders;

    // our main GL program.
    Program program;

    // The vertex positions attribute
    Attribute positionAttribute;
}

/**
    Return an instance of ProgramState which will have
    its dtor called at the exit of the scope.
*/
ProgramState initProgramState()
{
    return ProgramState(1);
}

/** */
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
    state.vertices.bind(state.positionAttribute, size, type, normalized, stride, offset);

    state.positionAttribute.enable();
    enum startIndex = 0;
    enum vertexCount = 3;
    glDrawArrays(GL_TRIANGLES, startIndex, vertexCount);

    state.positionAttribute.disable();
    state.vertices.unbind();
    state.program.unbind();
}

void main()
{
    auto window = createWindow("Tutorial 02 - Render Triangle");

    auto state = initProgramState();

    while (!glfwWindowShouldClose(window.window))
    {
        /* Rendering to the back buffer. */
        render(state);

        /* Swap front and back buffers. */
        window.swap_buffers();

        /* Poll for and process events. */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }
}
