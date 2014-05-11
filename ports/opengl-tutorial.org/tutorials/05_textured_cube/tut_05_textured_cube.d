/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_05_textured_cube;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/beginners-tutorials/tutorial-5-a-textured-cube/
*/

import std.file : thisExePath;
import std.path : buildPath, dirName;
import std.range : chunks;

import deimos.glfw.glfw3;

import glwtf.window;

import glad.gl.all;

import dgl;

import gl3n.linalg;
import gl3n.math;

import derelict.sdl2.sdl;
import derelict.sdl2.image;

import glamour.texture;

import gltut.window;

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
        this.workDirPath = thisExePath.dirName.buildPath("..");

        initVertices();
        initUV();
        initTextures();
        initShaders();
        initProgram();
        initAttributesUniforms();
        initProjection();
        initVao();
    }

    /** Release all OpenGL resources. */
    ~this()
    {
        vertexBuffer.release();
        uvBuffer.release();
        texture.remove();

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

        this.vertexBuffer = new GLBuffer(positions, UsageHint.staticDraw);
    }

    void initUV()
    {
        this.uvBuffer = new GLBuffer(uvArr, UsageHint.staticDraw);
    }

    void initTextures()
    {
        string textPath = workDirPath.buildPath("textures/uvtemplate.tga");
        this.texture = Texture2D.from_image(textPath);
    }

    void initShaders()
    {
        enum vertexShader = q{
            #version 330 core

            // Input vertex data, different for all executions of this shader.
            layout(location = 0) in vec3 vertexPosition_modelspace;

            // this is forwarded to the fragment shader.
            layout(location = 1) in vec2 vertexUV;

            // forward
            out vec2 fragmentUV;

            // Values that stay constant for the whole mesh.
            uniform mat4 mvpMatrix;

            void main()
            {
                // Output position of the vertex, in clip space : mvpMatrix * position
                gl_Position = mvpMatrix * vec4(vertexPosition_modelspace, 1);

                // forward to the fragment shader
                fragmentUV = vertexUV;
            }
        };

        enum fragmentShader = q{
            #version 330 core

            // interpolated values from the vertex shader
            in vec2 fragmentUV;

            // output
            out vec3 color;

            // this is our constant texture. It's constant throughout the running of the program,
            // but can be changed between each run.
            uniform sampler2D textureSampler;

            void main()
            {
                // we pick one of the pixels in the texture based on the 2D coordinate value of fragmentUV.
                color = texture(textureSampler, fragmentUV).rgb;
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
        this.uvAttribute = program.getAttribute("vertexUV");

        this.mvpUniform = program.getUniform("mvpMatrix");
        this.textureSamplerUniform = program.getUniform("textureSampler");
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
                float bottom = -10.0;
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

    // Our UV coolrdinates.
    // We keep this as an instance member because we're allowing
    // modifications with a keyboard callback, which will re-copy
    // the modified array into the GL buffer.
    // This isn't efficient but it serves as an example.
    float[] uvArr =
    [
        // Note: the '1.0f -' part is there in case the .tga image
        // was already flipped. The texture loading routines in
        // glamour may or may not flip the TGA vertically,
        // based on the code path it takes.
        0.000059f, 1.0f - 0.000004f,
        0.000103f, 1.0f - 0.336048f,
        0.335973f, 1.0f - 0.335903f,
        1.000023f, 1.0f - 0.000013f,
        0.667979f, 1.0f - 0.335851f,
        0.999958f, 1.0f - 0.336064f,
        0.667979f, 1.0f - 0.335851f,
        0.336024f, 1.0f - 0.671877f,
        0.667969f, 1.0f - 0.671889f,
        1.000023f, 1.0f - 0.000013f,
        0.668104f, 1.0f - 0.000013f,
        0.667979f, 1.0f - 0.335851f,
        0.000059f, 1.0f - 0.000004f,
        0.335973f, 1.0f - 0.335903f,
        0.336098f, 1.0f - 0.000071f,
        0.667979f, 1.0f - 0.335851f,
        0.335973f, 1.0f - 0.335903f,
        0.336024f, 1.0f - 0.671877f,
        1.000004f, 1.0f - 0.671847f,
        0.999958f, 1.0f - 0.336064f,
        0.667979f, 1.0f - 0.335851f,
        0.668104f, 1.0f - 0.000013f,
        0.335973f, 1.0f - 0.335903f,
        0.667979f, 1.0f - 0.335851f,
        0.335973f, 1.0f - 0.335903f,
        0.668104f, 1.0f - 0.000013f,
        0.336098f, 1.0f - 0.000071f,
        0.000103f, 1.0f - 0.336048f,
        0.000004f, 1.0f - 0.671870f,
        0.336024f, 1.0f - 0.671877f,
        0.000103f, 1.0f - 0.336048f,
        0.336024f, 1.0f - 0.671877f,
        0.335973f, 1.0f - 0.335903f,
        0.667969f, 1.0f - 0.671889f,
        1.000004f, 1.0f - 0.671847f,
        0.667979f, 1.0f - 0.335851f
    ];

    // We need the window size to calculate the projection matrix.
    Window window;

    // Selectable projection type.
    ProjectionType _projectionType = ProjectionType.perspective;

    // reference to a GPU buffer containing the vertices.
    GLBuffer vertexBuffer;

    // ditto, but containing UV coordinates.
    GLBuffer uvBuffer;

    // the texture we're going to use for the cube.
    Texture2D texture;

    // kept around for cleanup.
    Shader[] shaders;

    // our main GL program.
    Program program;

    // The vertex positions attribute
    Attribute positionAttribute;

    // ditto for the UV coordinates.
    Attribute uvAttribute;

    // The uniform (location) of the matrix in the shader.
    Uniform mvpUniform;

    // Ditto for the texture sampler.
    Uniform textureSamplerUniform;

    // The currently calculated matrix.
    mat4 mvpMatrix;

private:
    // root path where the 'textures' and 'bin' folders can be found.
    const string workDirPath;
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

    bindTexture(state);
    bindPositionAttribute(state);
    bindUVAttribute(state);

    enum startIndex = 0;

    // cube = 6 squares.
    // square = 2 faces (2 triangles).
    // triangle = 3 vertices.
    enum vertexCount = 6 * 2 * 3;
    glDrawArrays(GL_TRIANGLES, startIndex, vertexCount);

    state.texture.unbind();

    state.positionAttribute.disable();
    state.vertexBuffer.unbind();

    state.uvAttribute.disable();
    state.uvBuffer.unbind();

    state.program.unbind();
}

void bindPositionAttribute(ref ProgramState state)
{
    enum int size = 3;  // (x, y, z) per vertex
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.vertexBuffer.bind(state.positionAttribute, size, type, normalized, stride, offset);
    state.positionAttribute.enable();
}

void bindUVAttribute(ref ProgramState state)
{
    // (u, v) per vertex
    enum int size = 2;
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.uvBuffer.bind(state.uvAttribute, size, type, normalized, stride, offset);
    state.uvAttribute.enable();
}

void bindTexture(ref ProgramState state)
{
    // set our texture sampler to use Texture Unit 0
    enum textureUnit = 0;
    state.program.setUniform1i(state.textureSamplerUniform, textureUnit);

    state.texture.activate();
    state.texture.bind();
}

/** We're using the Derelict SDL binding for image loading. */
void loadDerelictSDL()
{
    DerelictSDL2.load();
    DerelictSDL2Image.load();
}

void main()
{
    loadDerelictSDL();

    auto window = createWindow("Tutorial 05 - Textured Cube");

    auto state = ProgramState(window);

    /**
        We're using a keyboard callback that will update the projection type
        if the user presses the P (perspective) or O (orthographic) keys.
        This will trigger a recalculation of the mvp matrix.
    */
    auto onChangePerspective =
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
    window.on_key_down.strongConnect(onChangePerspective);

    /**
        A keyboard callback that handles Up/Down keys
        which will change the UV coordinates in the UV buffer.
        The buffer is then copied over to a GL buffer.
        This isn't efficient but it serves as an example.
    */
    auto onUpDown =
    (int key, int scanCode, int modifier)
    {
        vec2 offset = vec2.init;

        void updateBuffer()
        {
            foreach (ref uv; state.uvArr.chunks(2))
            {
                uv[0] += offset.x;
                uv[1] += offset.y;
            }

            state.uvBuffer.overwrite(state.uvArr);
        }

        switch (key)
        {
            case GLFW_KEY_UP:
                offset = vec2(0.01, 0);
                updateBuffer();
                break;

            case GLFW_KEY_DOWN:
                offset = vec2(0, 0.01);
                updateBuffer();
                break;

            default:
        }
    };

    // hook the callback
    window.on_key_down.strongConnect(onUpDown);
    window.on_key_repeat.strongConnect(onUpDown);

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
