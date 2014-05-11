/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_07_model_loading;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/beginners-tutorials/tutorial-7-model-loading/
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

import gltut.model_loader;
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
        this.lastTime = glfwGetTime();

        initTextures();
        initModels();
        initShaders();
        initProgram();
        initAttributesUniforms();
        updateInputControls();
        updateProjection();
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
        updateProjection();
    }

    /// Get the current fov.
    @property float fov()
    {
        return _fov;
    }

    /// Set a new fov. This will recalculate the mvp matrix.
    @property void fov(float newFov)
    {
        if (newFov is fov)  // floats are bit-equal (note: don't ever use '==' with floats)
            return;

        _fov = newFov;
        updateProjection();
    }

    /** Update all the game state. */
    void gameTick()
    {
        updateInputControls();
        updateProjection();
    }

    /**
        Recalculate the projection (e.g. after a FOV change or mouse position change).
        Renamed from initProjection from previous tutorials.
    */
    void updateProjection()
    {
        auto projMatrix = getProjMatrix();
        auto viewMatrix = getViewMatrix();
        auto modelMatrix = getModelMatrix();

        // Remember that matrix multiplication is right-to-left.
        this.mvpMatrix = projMatrix * viewMatrix * modelMatrix;
    }

private:

    void initTextures()
    {
        string textPath = workDirPath.buildPath("textures/cube.png");
        this.texture = Texture2D.from_image(textPath);
    }

    void initModels()
    {
        string modelPath = workDirPath.buildPath("models/cube.obj");
        this.model = loadObjModel(modelPath);
        initVertices();
        initUV();
    }

    void initVertices()
    {
        this.vertexBuffer = new GLBuffer(model.vertexArr, UsageHint.staticDraw);
    }

    void initUV()
    {
        this.uvBuffer = new GLBuffer(model.uvArr, UsageHint.staticDraw);
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

    /**
        Check the keyboard and mouse input state against the last game tick,
        and update the camera position and view direction.
    */
    void updateInputControls()
    {
        // Compute time difference between current and last frame
        double currentTime = glfwGetTime();
        float deltaTime = cast(float)(currentTime - lastTime);

        // For the next frame, the "last time" will be "now"
        lastTime = currentTime;

        // Get mouse position
        double xpos, ypos;
        glfwGetCursorPos(window.window, &xpos, &ypos);

        // Reset mouse position for the next update.
        glfwSetCursorPos(window.window, 0, 0);

        /** If the window loses focus the values can become too large. */
        xpos = max(-20, xpos).min(20);
        ypos = max(-20, ypos).min(20);

        // Compute the new orientation
        this.horizontalAngle -= this.mouseSpeed * cast(float)xpos;
        this.verticalAngle   -= this.mouseSpeed * cast(float)ypos;

        // Direction - Spherical coordinates to Cartesian coordinates conversion
        this.direction = vec3(
            cos(this.verticalAngle) * sin(this.horizontalAngle),
            sin(this.verticalAngle),
            cos(this.verticalAngle) * cos(this.horizontalAngle)
        );

        // Right vector
        this.right = vec3(
            sin(this.horizontalAngle - 3.14f / 2.0f), // X
            0,                                        // Y
            cos(this.horizontalAngle - 3.14f / 2.0f)  // Z
        );

        alias KeyForward = GLFW_KEY_W;
        alias KeyBackward = GLFW_KEY_S;
        alias KeyStrafeLeft = GLFW_KEY_A;
        alias KeyStrafeRight = GLFW_KEY_D;
        alias KeyClimb = GLFW_KEY_SPACE;
        alias KeySink = GLFW_KEY_LEFT_SHIFT;

        if (window.is_key_down(KeyForward))
        {
            this.position += deltaTime * this.direction * this.speed;
        }

        if (window.is_key_down(KeyBackward))
        {
            this.position -= deltaTime * this.direction * this.speed;
        }

        if (window.is_key_down(KeyStrafeLeft))
        {
            this.position -= deltaTime * right * this.speed;
        }

        if (window.is_key_down(KeyStrafeRight))
        {
            this.position += deltaTime * right * this.speed;
        }

        if (window.is_key_down(KeyClimb))
        {
            this.position.y += deltaTime * this.speed;
        }

        if (window.is_key_down(KeySink))
        {
            this.position.y -= deltaTime * this.speed;
        }

        void updateUVBuffer(vec2 offset)
        {
            foreach (ref uv; model.uvArr)
            {
                uv.x -= offset.x;
                uv.y -= offset.y;
            }

            this.uvBuffer.overwrite(model.uvArr);
        }

        if (window.is_key_down(GLFW_KEY_LEFT))
        {
            updateUVBuffer(vec2(deltaTime * -0.3, 0));
        }

        if (window.is_key_down(GLFW_KEY_RIGHT))
        {
            updateUVBuffer(vec2(deltaTime * 0.3, 0));
        }

        if (window.is_key_down(GLFW_KEY_UP))
        {
            updateUVBuffer(vec2(0, deltaTime * 0.3));
        }

        if (window.is_key_down(GLFW_KEY_DOWN))
        {
            updateUVBuffer(vec2(0, deltaTime * -0.3));
        }
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
                float near = 0.1f;
                float far = 100.0f;

                int width;
                int height;
                glfwGetWindowSize(window.window, &width, &height);
                return mat4.perspective(width, height, _fov, near, far);
            }
        }
    }

    // the view (camera) matrix
    mat4 getViewMatrix()
    {
        // Up vector
        vec3 up = cross(this.right, this.direction);

        return mat4.look_at(
            position,              // Camera is here
            position + direction,  // and looks here
            up                     //
        );
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

    Model model;

    // time since the last game tick
    double lastTime = 0;

    // camera position
    vec3 position = vec3(0, 0, 5);

    // camera direction
    vec3 direction;

    vec3 right;

    // Initial horizontal angle : toward -Z
    float horizontalAngle = 3.14f;

    // Initial vertical angle : none
    float verticalAngle = 0.0f;

    // Initial Field of View
    float initialFoV = 45.0f;

    float speed      = 3.0f; // 3 units / second
    float mouseSpeed = 0.003f;

    // We need the window size to calculate the projection matrix.
    Window window;

    // Selectable projection type.
    ProjectionType _projectionType = ProjectionType.perspective;

    // Field of view (note that this was hardcoded in getProjMatrix in previous tutorials)
    float _fov = 45.0;

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

    // note that unlike in previous tutorials 'vertexArr' here is of type vec3[],
    // not float[]. Hence using .length here is appropriate. If you used a plain float[]
    // where each vertex consists of 3 consecutive floats then you would have to divide
    // the length by 3.
    const vertexCount = state.model.vertexArr.length;
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

void hookCallbacks(Window window, ref ProgramState state)
{
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

    auto onFovChange = (double hOffset, double vOffset)
    {
        // change fov but limit it to a sane range.
        // don't make the upper limit too low or
        // you'll make TotalBiscuit angry. :P
        auto fov = state.fov - (5 * vOffset);
        fov = max(45.0, fov).min(100.0);
        state.fov = fov;
    };

    window.on_scroll.strongConnect(onFovChange);
}

void main()
{
    loadDerelictSDL();

    auto window = createWindow("Tutorial 07 - Model Loading");

    // hide the mouse cursor (even when not in client area).
    window.set_input_mode(GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    auto state = ProgramState(window);

    hookCallbacks(window, state);

    // enable z-buffer depth testing.
    glEnable(GL_DEPTH_TEST);

    // accept fragment if it is closer to the camera than another one.
    glDepthFunc(GL_LESS);

    // cull triangles whose normal is not towards the camera.
	glEnable(GL_CULL_FACE);

    while (!glfwWindowShouldClose(window.window))
    {
        /*
            We want to update the camera position (the matrix)
            for every rendered image. Typically the game tick
            is decoupled from the render tick, but for simplicity
            we have a 1:1 match.
        */
        state.gameTick();

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
