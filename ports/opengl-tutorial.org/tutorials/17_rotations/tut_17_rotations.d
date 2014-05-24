/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_17_rotations;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-17-quaternions/
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

import AntTweakBar;

import gltut.model_loader;
import gltut.window;

/** Convert GLFW2 keys to GLFW3. This is only a partial implementation. */
static int keyGLFW2ToGLFW3(int key)
{
    static import glfw2 = deimos.glfw.glfw2;

    switch (key)
    {
        case GLFW_KEY_LEFT_CONTROL:
            return glfw2.GLFW_KEY_LCTRL;

        default:
    }

    return key;
}

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

        initTweakBarGUI();
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

        TwTerminate();
        glfwTerminate();
    }

    void initTweakBarGUI()
    {
        TwInit(TW_OPENGL_CORE, null);

        int width;
        int height;
        glfwGetWindowSize(window.window, &width, &height);
        TwWindowSize(width, height);

        TwBar* EulerGUI = TwNewBar("Euler settings");
        TwBar* QuaternionGUI = TwNewBar("Quaternion settings");
        TwSetParam(EulerGUI, null, "refresh", TW_PARAM_CSTRING, 1, "0.1".toStringz);
        TwSetParam(QuaternionGUI, null, "position", TW_PARAM_CSTRING, 1, "808 16".toStringz);

        TwAddVarRW(EulerGUI, "Euler X", TW_TYPE_FLOAT, &gOrientation1.vector[0], "step=0.01".toStringz);
        TwAddVarRW(EulerGUI, "Euler Y", TW_TYPE_FLOAT, &gOrientation1.vector[1], "step=0.01".toStringz);
        TwAddVarRW(EulerGUI, "Euler Z", TW_TYPE_FLOAT, &gOrientation1.vector[2], "step=0.01".toStringz);
        TwAddVarRW(EulerGUI, "Pos X"  , TW_TYPE_FLOAT, &gPosition1.vector[0], "step=0.1".toStringz);
        TwAddVarRW(EulerGUI, "Pos Y"  , TW_TYPE_FLOAT, &gPosition1.vector[1], "step=0.1".toStringz);
        TwAddVarRW(EulerGUI, "Pos Z"  , TW_TYPE_FLOAT, &gPosition1.vector[2], "step=0.1".toStringz);

        TwAddVarRW(QuaternionGUI, "Quaternion", TW_TYPE_QUAT4F, &gOrientation2, "showval=true open=true ".toStringz);
        TwAddVarRW(QuaternionGUI, "Use LookAt", TW_TYPE_BOOL8 , &gLookAtOther, "help='Look at the other monkey ?'".toStringz);

        // Set GLFW event callbacks. I removed glfwSetWindowSizeCallback for conciseness
        //~ glfwSetMouseButtonCallback(window.window, &TwEventMouseButtonGLFW); // - Directly redirect GLFW mouse button events to AntTweakBar
        //~ glfwSetCursorPosCallback(window.window, &TwEventMousePosGLFW);          // - Directly redirect GLFW mouse position events to AntTweakBar
        //~ glfwSetScrollCallback(window.window, &TwEventMouseWheelGLFW);    // - Directly redirect GLFW mouse wheel events to AntTweakBar
        //~ glfwSetKeyCallback(window.window, &TwEventKeyGLFW);                         // - Directly redirect GLFW key events to AntTweakBar
        //~ glfwSetCharCallback(window.window, &TwEventCharGLFW);                      // - Directly redirect GLFW char events to AntTweakBar

        /** Hook all input events. */
        glfwSetWindowSizeCallback(window.window, &onWindowResize);
        glfwSetMouseButtonCallback(window.window, &onMouseButton);
        glfwSetCursorPosCallback(window.window, &onCursorPos);
        glfwSetScrollCallback(window.window, &onScroll);
        glfwSetKeyCallback(window.window, &onKey);
        glfwSetCharCallback(window.window, &onChar);
    }

    extern(C) static void onWindowResize(GLFWwindow* window, int width, int height)
    {
        int x = 0;
        int y = 0;
        glViewport(x, y, width, height);

        // ~ glMatrixMode(GL_PROJECTION);
        // ~ glLoadIdentity();
        // ~ gluPerspective(40, (double)width/height, 1, 10);
        // ~ gluLookAt(-1,0,3, 0,0,0, 0,1,0);

        TwWindowSize(width, height);
    }

    extern(C) static void onMouseButton(GLFWwindow* window, int button, int action, int mods)
    {
        if (TwEventMouseButtonGLFW3(window, button, action, mods))
            return;

        // handle it ourselves
    }

    extern(C) static void onCursorPos(GLFWwindow* window, double xpos, double ypos)
    {
        if (TwEventMousePosGLFW3(window, xpos, ypos))
            return;

        // handle it ourselves
    }

    extern(C) static void onScroll(GLFWwindow* window, double xoffset, double yoffset)
    {
        if (TwEventMouseWheelGLFW3(window, xoffset, yoffset))
            return;

        // handle it ourselves
    }

    extern(C) static void onKey(GLFWwindow* window, int key, int scancode, int action, int mods)
    {
        if (TwEventKeyGLFW3(window, key, scancode, action, mods))
            return;

        // handle it ourselves
        if (action == GLFW_PRESS && key == GLFW_KEY_ESCAPE)
            glfwSetWindowShouldClose(window, true);
    }

    extern(C) static void onChar(GLFWwindow* window, uint codepoint)
    {
        if (TwEventCharGLFW3(window, codepoint))
            return;

        // handle it ourselves
    }

    static int TwEventMouseButtonGLFW3(GLFWwindow* window, int button, int action, int mods)
    {
        return TwEventMouseButtonGLFW(button, action);
    }

    static int TwEventMousePosGLFW3(GLFWwindow* window, double xpos, double ypos)
    {
        return TwMouseMotion(cast(int)xpos, cast(int)ypos);
    }

    static int TwEventMouseWheelGLFW3(GLFWwindow* window, double xoffset, double yoffset)
    {
        return TwEventMouseWheelGLFW(cast(int)yoffset);
    }

    static int TwEventKeyGLFW3(GLFWwindow* window, int key, int scancode, int action, int mods)
    {
        return TwEventKeyGLFW(key.keyGLFW2ToGLFW3(), action);
    }

    static int TwEventCharGLFW3(GLFWwindow* window, int codepoint)
    {
        return TwEventCharGLFW(codepoint, GLFW_PRESS);
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
        string textPath = workDirPath.buildPath("textures/suzanne_uvmap.png");
        this.texture = Texture2D.from_image(textPath);
    }

    void initModels()
    {
        string modelPath = workDirPath.buildPath("models/suzanne.obj");
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
        //~ double xpos, ypos;
        //~ glfwGetCursorPos(window.window, &xpos, &ypos);

        // Reset mouse position for the next update.
        //~ glfwSetCursorPos(window.window, 0, 0);

        /** If the window loses focus the values can become too large. */
        //~ xpos = max(-20, xpos).min(20);
        //~ ypos = max(-20, ypos).min(20);

        // Compute the new orientation
        //~ this.horizontalAngle -= this.mouseSpeed * cast(float)xpos;
        //~ this.verticalAngle   -= this.mouseSpeed * cast(float)ypos;

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


        //~ import std.stdio;
        //~ stderr.writeln(horizontalAngle, " ", verticalAngle);
        //~ stderr.writeln(this.direction);
        //~ stderr.writeln();
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

    /+
		{ // Euler

			// As an example, rotate arount the vertical axis at 180Яsec
			gOrientation1.y += 3.14159f/2.0f * deltaTime;

			// Build the model matrix
			glm::mat4 RotationMatrix = eulerAngleYXZ(gOrientation1.y, gOrientation1.x, gOrientation1.z);
			glm::mat4 TranslationMatrix = translate(mat4(), gPosition1); // A bit to the left
			glm::mat4 ScalingMatrix = scale(mat4(), vec3(1.0f, 1.0f, 1.0f));
			glm::mat4 ModelMatrix = TranslationMatrix * RotationMatrix * ScalingMatrix;

			glm::mat4 MVP = ProjectionMatrix * ViewMatrix * ModelMatrix;

			// Send our transformation to the currently bound shader,
			// in the "MVP" uniform
			glUniformMatrix4fv(MatrixID, 1, GL_FALSE, &MVP[0][0]);
			glUniformMatrix4fv(ModelMatrixID, 1, GL_FALSE, &ModelMatrix[0][0]);
			glUniformMatrix4fv(ViewMatrixID, 1, GL_FALSE, &ViewMatrix[0][0]);



			// Draw the triangles !
			glDrawElements(
				GL_TRIANGLES,      // mode
				indices.size(),    // count
				GL_UNSIGNED_SHORT,   // type
				(void*)0           // element array buffer offset
			);

		}

        // It the box is checked...
        if (gLookAtOther){
            vec3 desiredDir = gPosition1-gPosition2;
            vec3 desiredUp = vec3(0.0f, 1.0f, 0.0f); // +Y

            // Compute the desired orientation
            quat targetOrientation = normalize(LookAt(desiredDir, desiredUp));

            // And interpolate
            gOrientation2 = RotateTowards(gOrientation2, targetOrientation, 1.0f * deltaTime);
        }

        glm::mat4 RotationMatrix = mat4_cast(gOrientation2);
        glm::mat4 TranslationMatrix = translate(mat4(), gPosition2); // A bit to the right
        glm::mat4 ScalingMatrix = scale(mat4(), vec3(1.0f, 1.0f, 1.0f));
        glm::mat4 ModelMatrix = TranslationMatrix * RotationMatrix * ScalingMatrix;
        +/

    //
    mat4 getModelMatrix()
    {
        // A bit to the left
        return mat4.identity().translate(gPosition1.x, gPosition1.y, gPosition1.z);
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
    vec3 position = vec3(-2.24282, 5.35371, -9.67096);

    // camera direction (note: change horizontalAngle/verticalAngle for the initial direction)
    vec3 direction;

    vec3 right;

    // Initial horizontal angle
    float horizontalAngle = 6.47;

    // Initial vertical angle
    float verticalAngle = -0.198;

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

    /** TweakBar variables. */
    vec3 gPosition1 = vec3(-1.5f, 0.0f, 0.0f);
    vec3 gOrientation1 = vec3(0, 0, 0);
    vec3 gPosition2 = vec3(1.5f, 0.0f, 0.0f);
    quat gOrientation2 = quat(0, 0, 0, 0);
    bool gLookAtOther = true;

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

    auto window = createWindow("Tutorial 17 - Rotations");

    // hide the mouse cursor (even when not in client area).
    //~ window.set_input_mode(GLFW_CURSOR, GLFW_CURSOR_DISABLED);

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

        // Draw GUI
		TwDraw();

        /* Swap front and back buffers. */
        window.swap_buffers();

        /* Poll for and process events. */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }
}
