/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_04_colored_cube;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/beginners-tutorials/tutorial-4-a-colored-cube/
*/

import deimos.glfw.glfw3;

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
        initColors();
        initShaders();
        initProgram();
        initAttributesUniforms();
        initProjection();
        initVao();
    }

    /** Release all OpenGL resources. */
    ~this()
    {
        vertices.release();
        colors.release();

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
        // Our vertices. Three consecutive floats make a vertex (X, Y, Z).
        // cube = 6 squares.
        // square = 2 faces (2 triangles).
        // triangle = 3 vertices.
        // vertex = 3 floats.
        const float[] positions =
        [
            -1.0f, -1.0f, -1.0f,  // triangle #1 begin
            -1.0f, -1.0f,  1.0f,
            -1.0f,  1.0f,  1.0f,  // triangle #1 end
             1.0f,  1.0f, -1.0f,  // triangle #2 begin
            -1.0f, -1.0f, -1.0f,
            -1.0f,  1.0f, -1.0f,  // triangle #2 end
             1.0f, -1.0f,  1.0f,  // etc..
            -1.0f, -1.0f, -1.0f,
             1.0f, -1.0f, -1.0f,
             1.0f,  1.0f, -1.0f,
             1.0f, -1.0f, -1.0f,
            -1.0f, -1.0f, -1.0f,
            -1.0f, -1.0f, -1.0f,
            -1.0f,  1.0f,  1.0f,
            -1.0f,  1.0f, -1.0f,
             1.0f, -1.0f,  1.0f,
            -1.0f, -1.0f,  1.0f,
            -1.0f, -1.0f, -1.0f,
            -1.0f,  1.0f,  1.0f,
            -1.0f, -1.0f,  1.0f,
             1.0f, -1.0f,  1.0f,
             1.0f,  1.0f,  1.0f,
             1.0f, -1.0f, -1.0f,
             1.0f,  1.0f, -1.0f,
             1.0f, -1.0f, -1.0f,
             1.0f,  1.0f,  1.0f,
             1.0f, -1.0f,  1.0f,
             1.0f,  1.0f,  1.0f,
             1.0f,  1.0f, -1.0f,
            -1.0f,  1.0f, -1.0f,
             1.0f,  1.0f,  1.0f,
            -1.0f,  1.0f, -1.0f,
            -1.0f,  1.0f,  1.0f,
             1.0f,  1.0f,  1.0f,
            -1.0f,  1.0f,  1.0f,
             1.0f, -1.0f,  1.0f
        ];

        this.vertices = new GLBuffer(positions, UsageHint.staticDraw);
    }

    void initColors()
    {
        this.colors = new GLBuffer(colorsArr, UsageHint.staticDraw);
    }

    void initShaders()
    {
        enum vertexShader = q{
            #version 330 core

            // Input vertex data, different for all executions of this shader.
            layout(location = 0) in vec3 vertexPosition_modelspace;

            // we don't do anything with this, it's forwarded to the fragment shader
            // via the fragmentColor output.
            layout(location = 1) in vec3 vertexColor;

            // forward
            out vec3 fragmentColor;

            // Values that stay constant for the whole mesh.
            uniform mat4 mvpMatrix;

            void main()
            {
                // Output position of the vertex, in clip space : mvpMatrix * position
                gl_Position = mvpMatrix * vec4(vertexPosition_modelspace, 1);

                // forward to the fragment shader
                fragmentColor = vertexColor;
            }
        };

        enum fragmentShader = q{
            #version 330 core

            in vec3 fragmentColor;

            out vec3 color;

            void main()
            {
                // this time we don't hardcode the color, but set it to the value
                // forwarded from the vertex shader.
                color = fragmentColor;
            }
        };

        this.shaders ~= Shader.fromText(ShaderType.vertex, vertexShader);
        this.shaders ~= Shader.fromText(ShaderType.fragment, fragmentShader);
    }

    void initProgram()
    {
        this.program = new Program(shaders);
    }

    void initAttributesUniforms()
    {
        this.positionAttribute = program.getAttribute("vertexPosition_modelspace");
        this.colorAttribute = program.getAttribute("vertexColor");

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

    // the view (camera) matrix
    mat4 getViewMatrix()
    {
        auto eye = vec3(4, 3, 3);     // camera is at (4, 3, 3), in World Space.
        auto target = vec3(0, 0, 0);  // it looks at the origin.
        auto up = vec3(0, 1, 0);      // head is up (set to 0, -1, 0 to look upside-down).
        return mat4.look_at(eye, target, up);
    }

    //
    mat4 getModelMatrix()
    {
        // an identity matrix - the model will be at the origin.
        return mat4.identity();
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

    // Our colors, tree consecutive floats give an RGB color.
    // Each vertex gets its own color, so the colors array has
    // the same length as the vertices array.
    // We keep this as an instance member because we're allowing
    // modifications with a keyboard callback, which will re-copy
    // the modified array into the GL buffer.
    // This isn't efficient but it serves as an example.
    float[] colorsArr =
    [
        0.583f,  0.771f,  0.014f,
        0.609f,  0.115f,  0.436f,
        0.327f,  0.483f,  0.844f,
        0.822f,  0.569f,  0.201f,
        0.435f,  0.602f,  0.223f,
        0.310f,  0.747f,  0.185f,
        0.597f,  0.770f,  0.761f,
        0.559f,  0.436f,  0.730f,
        0.359f,  0.583f,  0.152f,
        0.483f,  0.596f,  0.789f,
        0.559f,  0.861f,  0.639f,
        0.195f,  0.548f,  0.859f,
        0.014f,  0.184f,  0.576f,
        0.771f,  0.328f,  0.970f,
        0.406f,  0.615f,  0.116f,
        0.676f,  0.977f,  0.133f,
        0.971f,  0.572f,  0.833f,
        0.140f,  0.616f,  0.489f,
        0.997f,  0.513f,  0.064f,
        0.945f,  0.719f,  0.592f,
        0.543f,  0.021f,  0.978f,
        0.279f,  0.317f,  0.505f,
        0.167f,  0.620f,  0.077f,
        0.347f,  0.857f,  0.137f,
        0.055f,  0.953f,  0.042f,
        0.714f,  0.505f,  0.345f,
        0.783f,  0.290f,  0.734f,
        0.722f,  0.645f,  0.174f,
        0.302f,  0.455f,  0.848f,
        0.225f,  0.587f,  0.040f,
        0.517f,  0.713f,  0.338f,
        0.053f,  0.959f,  0.120f,
        0.393f,  0.621f,  0.362f,
        0.673f,  0.211f,  0.457f,
        0.820f,  0.883f,  0.371f,
        0.982f,  0.099f,  0.879f
    ];

    // We need the window size to calculate the projection matrix.
    Window window;

    // Selectable projection type.
    ProjectionType _projectionType = ProjectionType.perspective;

    // reference to a GPU buffer containing the vertices.
    GLBuffer vertices;

    // ditto, but containing colors.
    GLBuffer colors;

    // kept around for cleanup.
    Shader[] shaders;

    // our main GL program.
    Program program;

    // The vertex positions attribute
    Attribute positionAttribute;

    // ditto for the color.
    Attribute colorAttribute;

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

    bindPositionAttribute(state);
    bindColorAttribute(state);

    enum startIndex = 0;

    // cube = 6 squares.
    // square = 2 faces (2 triangles).
    // triangle = 3 vertices.
    enum vertexCount = 6 * 2 * 3;
    glDrawArrays(GL_TRIANGLES, startIndex, vertexCount);

    state.positionAttribute.disable();
    state.vertices.unbind();

    state.colorAttribute.disable();
    state.colors.unbind();

    state.program.unbind();
}

void bindPositionAttribute(ref ProgramState state)
{
    enum int size = 3;  // (x, y, z) per vertex
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.vertices.bind(state.positionAttribute, size, type, normalized, stride, offset);
    state.positionAttribute.enable();
}

void bindColorAttribute(ref ProgramState state)
{
    // (r, g, b) per vertex (similar byte size to vertices above but completely different data!)
    enum int size = 3;
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.colors.bind(state.colorAttribute, size, type, normalized, stride, offset);
    state.colorAttribute.enable();
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
    auto onKeyDown =
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
    window.on_key_down.strongConnect(onKeyDown);

    /**
        Another keyboard callback that handles key repeats,
        which will change the color values of our color buffer,
        by increasing or decreasing the brightness.
        The buffer is then copied over to a GL buffer.
        This isn't efficient but it serves as an example.
    */
    auto onKeyRepeat =
    (int key, int scanCode, int modifier)
    {
        float addColor = 0.0;

        switch (key)
        {
            case GLFW_KEY_UP:
                addColor = 0.01;
                goto Multiplier;

            case GLFW_KEY_DOWN:
                addColor = -0.01;
                goto Multiplier;

            Multiplier:
            {
                foreach (ref color; state.colorsArr)
                    color += addColor;

                state.colors.write(state.colorsArr);
                break;
            }

            default:
        }
    };

    // hook the callback
    window.on_key_repeat.strongConnect(onKeyRepeat);

    // enable z-buffer depth testing.
    glEnable(GL_DEPTH_TEST);

    // Accept fragment if it is closer to the camera than another one.
    glDepthFunc(GL_LESS);

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
