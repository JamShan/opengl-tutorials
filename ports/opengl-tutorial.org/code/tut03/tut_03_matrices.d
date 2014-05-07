/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_03_matrices;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/beginners-tutorials/tutorial-3-matrices/
*/

import deimos.glfw.glfw3;

import glwtf.input;
import glwtf.window;

import glad.gl.all;

import dgl;

import gl3n.linalg;
import gl3n.math;

import gltut.utility;

/// The type of projection we want to use.
enum ProjectionType
{
    perspective,
    orthographic,
}

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
        initAttributesUniforms();
        initProjection();
        initVao();
    }

    /** Release all GL resources. */
    ~this()
    {
        vertices.release();

        foreach (shader; shaders)
            shader.release();

        program.release();

        glfwTerminate();
    }

    /// Get the projection type.
    @property ProjectionType projectionType()
    {
        return _projectionType;
    }

    /// Set a new projection type. This will recalculate the mvp matrix.
    @property void projectionType(ProjectionType newProjectionType)
    {
        if (newProjectionType == _projectionType)
            return;

        _projectionType = newProjectionType;
        initProjection();
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

        this.vertices = new GLBuffer(positions, UsageHint.staticDraw);
    }

    void initShaders()
    {
        enum strVertexShader =
        q{
            #version 330 core

            // Input vertex data, different for all executions of this shader.
            layout(location = 0) in vec3 vertexPosition_modelspace;

            // Values that stay constant for the whole mesh.
            uniform mat4 mvpMatrix;

            void main()
            {
                // Output position of the vertex, in clip space : mvpMatrix * position
                gl_Position = mvpMatrix * vec4(vertexPosition_modelspace, 1);
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

    void initAttributesUniforms()
    {
        this.positionAttribute = program.getAttribute("vertexPosition_modelspace");
        this.mvpUniform = program.getUniform("mvpMatrix");
    }

    void initProjection()
    {
        auto projMatrix = getProjMatrix();
        auto viewMatrix = getViewMatrix();
        auto modelMatrix = getModelMatrix();

        // Remember that matrix multiplication is right-to-left.
        this.mvpMatrix = projMatrix * viewMatrix * modelMatrix;
    }

    mat4 getProjMatrix()
    {
        final switch (_projectionType) with (ProjectionType)
        {
            case orthographic:
            {
                float left = -10.0;
                float right = 10.0;
                float bottom = -10.0;  // todo: check if this should be swapped with top
                float top = 10.0;
                float near = 0.0;
                float far = 100.0;
                return mat4.orthographic(left, right, bottom, top, near, far);
            }

            case perspective:
            {
                float fov = 45.0f;
                float near = 0.1f;
                float far = 100.0f;

                int width;
                int height;
                glfwGetWindowSize(window.window, &width, &height);

                // auto fovRadian = fov * (PI/180);
                return mat4.perspective(width, height, fov, near, far);
            }
        }
    }

    // view, a.k.a. camera matrix
    mat4 getViewMatrix()
    {
        auto eye = vec3(4, 3, 3);     // Camera is at (4, 3, 3), in World Space
        auto target = vec3(0, 0, 0);  // and looks at the origin
        auto up = vec3(0, 1, 0);      // Head is up (set to 0, -1, 0 to look upside-down)
        return mat4.look_at(eye, target, up);
    }

    //
    mat4 getModelMatrix()
    {
        // an identity matrix - model will be at the origin
        return mat4.identity();
    }

    void initVao()
    {
        // Note: this must be called when using the core profile,
        // and must be called before any other OpenGL call.
        GLuint vao;
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
    }

    // We need the window size to calculate the projection matrix.
    Window window;

    // Selectable projection type.
    ProjectionType _projectionType = ProjectionType.perspective;

    // reference to a GPU buffer containing the vertices.
    GLBuffer vertices;

    // kept around for cleanup.
    Shader[] shaders;

    // our main GL program.
    Program program;

    // The vertex positions attribute
    Attribute positionAttribute;

    // The uniform (location) of the matrix in the shader.
    Uniform mvpUniform;

    // The currently calculated matrix.
    mat4 mvpMatrix;
}

/** Our main render routine. */
void render(ref ProgramState state)
{
    glClearColor(0.0f, 0.0f, 0.4f, 0.0f);  // dark blue
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    state.program.bind();

    // set this to true when converting matrices from row-major order
    // to column-major order. Note that gl3n uses row-major ordering,
    // unlike the C++ glm library.
    enum doTranspose = GL_TRUE;
    enum matrixCount = 1;
    glUniformMatrix4fv(state.mvpUniform.ID, matrixCount, doTranspose, &state.mvpMatrix[0][0]);

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
    auto window = createWindow("Tutorial 03 - Matrices");

    auto state = ProgramState(window);

    /**
        We're using a keyboard callback that will update the projection type
        if the user presses the P (perspective) or O (orthographic) keys.
        This will trigger a recalculation of the mvp matrix.
    */
    auto keyHandler =
    (int key, int scanCode, int modifier)
    {
        switch (key)
        {
            case GLFW_KEY_P:
                state.projectionType = ProjectionType.perspective;
                break;

            case GLFW_KEY_O:
                state.projectionType = ProjectionType.orthographic;
                break;

            default:
        }
    };

    // hook the callback
    window.on_key_down.strongConnect(keyHandler);

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
