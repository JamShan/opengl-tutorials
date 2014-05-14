/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_14_render_to_texture;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/intermediate-tutorials/tutorial-14-render-to-texture/

    Note: Build with -version=RenderMultipleModels to enable rendering multiple objects.

    Active key / mouse bindings:

    1      => Toggle ambient light.
    2      => Toggle diffuse light.
    3      => Toggle specular light.
    + -    => Increase or decrease the alpha value.
    WASD   => Move camera around.
    P      => Change projection to perspective mode.
    O      => Change projection to ortograpic mode.
    Esc    => Exit.
*/

import std.file : dirEntries, SpanMode, thisExePath;
import std.path : buildPath, dirName;
import std.range : chunks;
import std.string;

import deimos.glfw.glfw3;

import glwtf.window;

import glad.gl.all;

import dgl;

import gl3n.linalg;
import gl3n.math;

import derelict.sdl2.sdl;
import derelict.sdl2.image;

import glamour.fbo;
import glamour.texture;

import gltut.model_indexer;
import gltut.model_loader;
import gltut.text_renderer;
import gltut.texture_loader;
import gltut.window;

/// A model with preloaded GL Buffers.
struct GLModel
{
    void release()
    {
        indexBuffer.release();
        vertexBuffer.release();
        uvBuffer.release();
        normalBuffer.release();
        tangentBuffer.release();
        biTangentBuffer.release();
    }

    size_t indexCount;
    GLBuffer indexBuffer;
    GLBuffer vertexBuffer;
    GLBuffer uvBuffer;
    GLBuffer normalBuffer;
    GLBuffer tangentBuffer;
    GLBuffer biTangentBuffer;
}

GLModel getGLModel(IndexedTangentModel model)
{
    GLModel result;

    enforce(model.indexArr.length);
    result.indexCount = cast(int)model.indexArr.length;
    result.indexBuffer = new GLBuffer(model.indexArr, UsageHint.staticDraw);

    enforce(model.vertexArr.length);
    result.vertexBuffer = new GLBuffer(model.vertexArr, UsageHint.staticDraw);

    enforce(model.uvArr.length);
    result.uvBuffer = new GLBuffer(model.uvArr, UsageHint.staticDraw);

    enforce(model.normalArr.length);
    result.normalBuffer = new GLBuffer(model.normalArr, UsageHint.staticDraw);

    enforce(model.tangentArr.length);
    result.tangentBuffer = new GLBuffer(model.tangentArr, UsageHint.staticDraw);

    enforce(model.biTangentArr.length);
    result.biTangentBuffer = new GLBuffer(model.biTangentArr, UsageHint.staticDraw);

    return result;
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

        string fontTextPath = workDirPath.buildPath("textures").buildPath("holstein.png");
        this.textRenderer = TextRenderer(window, fontTextPath);

        initTextures();
        initModels();
        initShaders();
        initQuadShaders();
        initProgram();
        initQuadProgram();
        initAttributesUniforms();
        updateInputControls();
        updateProjection();
        initVao();
    }

    /** Release all OpenGL resources. */
    ~this()
    {
        normalTexture.remove();
        diffuseTexture.remove();
        specularTexture.remove();
        renderedTexture.remove();
        quadVertexBuffer.release();

        foreach (shader; shaders)
            shader.release();

        foreach (shader; quadShaders)
            shader.release();

        program.release();

        fbo.remove();
        quadProgram.release();
        depthRenderBuffer.remove();

        textRenderer.release();

        foreach (ref model; loadedModels)
            model.release();

        glfwTerminate();
    }

    /// Toggle ambient light.
    public bool useAmbientLight = true;

    /// Toggle diffuse light.
    public bool useDiffuseLight = true;

    /// Toggle specular light.
    public bool useSpecularLight = true;

    /// The alpha value.
    public float colorAlpha = 1.0;

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
        updateViewMatrix();
        updateMvpMatrix();
        updateModelViewMatrix();
        updateModelView3x3Matrix();
    }

private:

    void updateViewMatrix()
    {
        this.viewMatrix = getViewMatrix();
    }

    void updateMvpMatrix()
    {
        this.projMatrix = getProjMatrix();

        // Remember that matrix multiplication is right-to-left.
        this.mvpMatrix = projMatrix * viewMatrix * modelMatrix;
    }

    void updateModelViewMatrix()
    {
        this.modelViewMatrix = viewMatrix * modelMatrix;
    }

    void updateModelView3x3Matrix()
    {
        this.modelView3x3Matrix = mat3(modelViewMatrix);
    }

    void initTextures()
    {
        const texturesPath = workDirPath.buildPath("textures");

        this.normalTexture = Texture2D.from_image(texturesPath.buildPath("normal.png"));
        this.diffuseTexture = texturesPath.buildPath("diffuse.DDS").loadDDSImage();
        this.specularTexture = texturesPath.buildPath("specular.DDS").loadDDSImage();
    }

    void initModels()
    {
        version (RenderMultipleModels)
        {
            foreach (modelPath; workDirPath.buildPath("models").dirEntries(SpanMode.shallow))
                loadedModels ~= aiLoadObjModel(modelPath).getIndexedTangentModel().getGLModel();
        }
        else
        {
            loadedModels ~= aiLoadObjModel(workDirPath.buildPath("models/cylinder.obj")).getIndexedTangentModel().getGLModel();
        }
    }

    void initShaders()
    {
        this.shaders ~= Shader.fromText(ShaderType.vertex, vertexShader);
        this.shaders ~= Shader.fromText(ShaderType.fragment, fragmentShader);
    }

    void initQuadShaders()
    {
        this.quadShaders ~= Shader.fromText(ShaderType.vertex, quadVertexShader);
        this.quadShaders ~= Shader.fromText(ShaderType.fragment, quadFragmentShader);
    }

    void initProgram()
    {
        this.program = new Program(shaders);
    }

    void initQuadProgram()
    {
        this.quadProgram = new Program(quadShaders);
        this.quadPositionAttribute = quadProgram.getAttribute("vertexPositionModelspace");

        this.fbo = new FrameBuffer();
        fbo.bind();

        // The framebuffer, which regroups 0, 1, or more textures, and 0 or 1 depth buffer.

        int width;
        int height;
        glfwGetWindowSize(window.window, &width, &height);

        this.renderedTexture = new Texture2D();
        void* ptr;  // typeof(null) issues
        renderedTexture.set_data(ptr, GL_RGB, width, height, GL_RGB, GL_UNSIGNED_BYTE);
        renderedTexture.bind();

        // filtering
        renderedTexture.set_parameter(GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        renderedTexture.set_parameter(GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        renderedTexture.set_parameter(GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        renderedTexture.set_parameter(GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        // The depth buffer
        this.depthRenderBuffer = fbo.attach_new_renderbuffer(GL_DEPTH_ATTACHMENT, GL_DEPTH_COMPONENT, width, height);

        // Set "renderedTexture" as our colour attachement #0
        fbo.attach(renderedTexture, GL_COLOR_ATTACHMENT0);

        // Set the list of draw buffers, in the fragment shader we can pick one via:
        // layout(location = 0) out vec3 color; (location = 1, etc)
        static GLenum[1] drawBuffers = [GL_COLOR_ATTACHMENT0];
        glDrawBuffers(1, drawBuffers.ptr);     // "1" is the size of DrawBuffers

        // Always check that our framebuffer is ok
        enforce(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

        // The fullscreen quad's FBO.
        static const GLfloat[] quadVertexArr = [
            -1.0f, -1.0f, 0.0f,
             1.0f, -1.0f, 0.0f,
            -1.0f,  1.0f, 0.0f,
            -1.0f,  1.0f, 0.0f,
             1.0f, -1.0f, 0.0f,
             1.0f,  1.0f, 0.0f,
        ];

        this.quadVertexBuffer = new GLBuffer(quadVertexArr, UsageHint.staticDraw);

        this.renderedTextureUniform = quadProgram.getUniform("renderedTexture");
        this.timeUniform = quadProgram.getUniform("time");
        this.windowSizeUniform = quadProgram.getUniform("windowSize");

        renderedTexture.unbind();
        fbo.unbind();
    }

    void initAttributesUniforms()
    {
        this.positionAttribute = program.getAttribute("vertexPositionModelspace");
        this.uvAttribute = program.getAttribute("vertexUV");
        this.normalAttribute = program.getAttribute("vertexNormalModelspace");
        this.tangentAttribute = program.getAttribute("vertexTangentModelspace");
        this.biTangentAttribute = program.getAttribute("vertexBitangentModelspace");

        this.mvpUniform = program.getUniform("mvpMatrix");
        this.modelMatrixUniform = program.getUniform("modelMatrix");
        this.viewMatrixUniform = program.getUniform("viewMatrix");
        this.modelView3x3MatrixUniform = program.getUniform("modelView3x3Matrix");

        this.lightUniform = program.getUniform("lightPositionWorldspace");

        this.useAmbientLightUniform = program.getUniform("useAmbientLight");
        this.useDiffuseLightUniform = program.getUniform("useDiffuseLight");
        this.useSpecularLightUniform = program.getUniform("useSpecularLight");
        this.colorAlphaUniform = program.getUniform("colorAlpha");

        this.diffuseTextureUniform = program.getUniform("diffuseTextureSampler");
        this.normalTextureUniform = program.getUniform("normalTextureSampler");
        this.specularTextureUniform = program.getUniform("specularTextureSampler");
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

        if (window.is_key_down(GLFW_KEY_MINUS) ||
            window.is_key_down(GLFW_KEY_KP_SUBTRACT))
        {
            this.colorAlpha -= deltaTime * 0.4;
        }

        if (window.is_key_down(GLFW_KEY_EQUAL) ||
            window.is_key_down(GLFW_KEY_KP_ADD))
        {
            // note: normally we wouldn't use just 'equal' but also
            // check the shift modifier. glwtf doesn't expose this currently,
            // although glfw does. Note however that we've already mapped the
            // shift key to do something else.
            this.colorAlpha += deltaTime * 0.4;
        }

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

    GLModel[] loadedModels;

    GLModel model;

    // time since the last game tick
    double lastTime = 0;

    // camera position
    vec3 position = vec3(0, 0, 6);

    // camera direction
    vec3 direction;

    vec3 right;

    // Initial horizontal angle - toward -Z
    float horizontalAngle = 3.14f;

    // Initial vertical angle - none
    float verticalAngle = 0.0f;

    // Initial Field of View
    float initialFoV = 45.0f;

    float speed = 3.0f; // 3 units / second
    float mouseSpeed = 0.003f;

    // We need the window size to calculate the projection matrix.
    Window window;

    // Selectable projection type.
    ProjectionType _projectionType = ProjectionType.perspective;

    // Field of view (note that this was hardcoded in getProjMatrix in previous tutorials)
    float _fov = 45.0;

    // the texture's we're going to use for the cylinder object.
    Texture2D normalTexture;
    Texture2D diffuseTexture;
    Texture2D specularTexture;

    // the uniforms for the above textures.
    Uniform diffuseTextureUniform;
    Uniform normalTextureUniform;
    Uniform specularTextureUniform;

    // kept around for cleanup.
    Shader[] shaders;
    Shader[] quadShaders;

    // our main GL program.
    Program program;

    Uniform renderedTextureUniform;
    Uniform timeUniform;
    Uniform windowSizeUniform;
    Program quadProgram;

    FrameBuffer fbo;

    GLBuffer quadVertexBuffer;

    // The vertex positions attribute
    Attribute positionAttribute;
    Attribute quadPositionAttribute;

    // ditto for the fragmentUV coordinates.
    Attribute uvAttribute;

    // ditto for the normals.
    Attribute normalAttribute;
    Attribute tangentAttribute;
    Attribute biTangentAttribute;

    // The uniform (location) of the matrix in the shader.
    Uniform mvpUniform;

    // ditto for the model matrix.
    Uniform modelMatrixUniform;

    // ditto for the view matrix.
    Uniform viewMatrixUniform;

    Uniform modelViewMatrixUniform;

    Uniform modelView3x3MatrixUniform;

    // ditto for the light.
    Uniform lightUniform;

    // ditto for the light settings.
    Uniform useAmbientLightUniform;
    Uniform useDiffuseLightUniform;
    Uniform useSpecularLightUniform;

    // ditto for the alpha.
    Uniform colorAlphaUniform;

    // The currently calculated matrix.
    mat4 mvpMatrix;

    version (RenderMultipleModels)
    {
        // ditto for the model matrix.
        mat4 modelMatrix = mat4.identity();
    }
    else
    {
        // move the cylinder a little bit lower.
        mat4 modelMatrix = mat4.identity().translate(0, -1.0, 0);
    }

    mat4 projMatrix;

    // ditto for the view matrix.
    mat4 viewMatrix;

    mat4 modelViewMatrix;

    mat3 modelView3x3Matrix;

    RenderBuffer depthRenderBuffer;
    TextRenderer textRenderer;

    Texture2D renderedTexture;

private:
    // root path where the 'textures' and 'bin' folders can be found.
    const string workDirPath;
}

enum vertexShader = q{
    #version 330 core

    // Input vertex data, different for all executions of this shader.
    layout(location = 0) in vec3 vertexPositionModelspace;
    layout(location = 1) in vec2 vertexUV;
    layout(location = 2) in vec3 vertexNormalModelspace;
    layout(location = 3) in vec3 vertexTangentModelspace;
    layout(location = 4) in vec3 vertexBitangentModelspace;

    // Output data ; will be interpolated for each fragment.
    out vec2 fragmentUV;
    out vec3 positionWorldspace;
    out vec3 eyeDirectionCameraspace;
    out vec3 lightDirectionCameraspace;

    out vec3 lightDirectionTangentspace;
    out vec3 eyeDirectionTangentspace;

    // Values that stay constant for the whole mesh.
    uniform mat4 mvpMatrix;
    uniform mat4 viewMatrix;
    uniform mat4 modelMatrix;
    uniform mat3 modelView3x3Matrix;
    uniform vec3 lightPositionWorldspace;

    void main()
    {
        // Output position of the vertex, in clip space : mvpMatrix * position
        gl_Position = mvpMatrix * vec4(vertexPositionModelspace, 1);

        // Position of the vertex, in worldspace : modelMatrix * position
        positionWorldspace = (modelMatrix * vec4(vertexPositionModelspace, 1)).xyz;

        // Vector that goes from the vertex to the camera, in camera space.
        // In camera space, the camera is at the origin (0,0,0).
        vec3 vertexPosition_cameraspace = (viewMatrix * modelMatrix * vec4(vertexPositionModelspace, 1)).xyz;
        eyeDirectionCameraspace = vec3(0, 0, 0) - vertexPosition_cameraspace;

        // Vector that goes from the vertex to the light, in camera space. modelMatrix is ommited because it's identity.
        vec3 lightPositionCamerspace = (viewMatrix * vec4(lightPositionWorldspace, 1)).xyz;
        lightDirectionCameraspace = lightPositionCamerspace + eyeDirectionCameraspace;

        // fragmentUV of the vertex. No special space for this one.
        fragmentUV = vertexUV;

        // model to camera = ModelView
        vec3 vertexTangent_cameraspace   = modelView3x3Matrix * vertexTangentModelspace;
        vec3 vertexBitangent_cameraspace = modelView3x3Matrix * vertexBitangentModelspace;
        vec3 vertexNormal_cameraspace    = modelView3x3Matrix * vertexNormalModelspace;

        // You can use dot products instead of building this matrix and transposing it. See References for details.
        mat3 tbn = transpose(mat3(vertexTangent_cameraspace,
                                  vertexBitangent_cameraspace,
                                  vertexNormal_cameraspace));

        lightDirectionTangentspace = tbn * lightDirectionCameraspace;
        eyeDirectionTangentspace   = tbn * eyeDirectionCameraspace;
    }
};

enum fragmentShader = q{
    #version 330 core

    // Interpolated values from the vertex shaders
    in vec2 fragmentUV;
    in vec3 positionWorldspace;
    in vec3 eyeDirectionCameraspace;
    in vec3 lightDirectionCameraspace;

    in vec3 lightDirectionTangentspace;
    in vec3 eyeDirectionTangentspace;

    // Ouput data
    out vec4 color;

    // Values that stay constant for the whole mesh.
    uniform sampler2D diffuseTextureSampler;
    uniform sampler2D normalTextureSampler;
    uniform sampler2D specularTextureSampler;
    uniform mat4 viewMatrix;
    uniform mat4 modelMatrix;
    uniform mat3 modelView3x3Matrix;
    uniform vec3 lightPositionWorldspace;

    uniform bool useAmbientLight;
    uniform bool useDiffuseLight;
    uniform bool useSpecularLight;

    uniform float colorAlpha;

    void main()
    {
        // Light emission properties
        // You probably want to put them as uniforms
        vec3 lightColor = vec3(1, 1, 1);
        float lightPower = 40.0;

        // Material properties
        vec3 materialDiffuseColor  = texture2D(diffuseTextureSampler, fragmentUV).rgb;
        vec3 materialAmbientColor  = vec3(0.1, 0.1, 0.1) * materialDiffuseColor;
        vec3 materialSpecularColor = texture2D(specularTextureSampler, fragmentUV).rgb * 0.3;

        // Local normal, in tangent space. viewMatrix tex coordinate is inverted because normal map is in TGA (not in DDS) for better quality
        vec3 textureNormalTangentspace = normalize(texture2D(normalTextureSampler,
                                                             vec2(fragmentUV.x, -fragmentUV.y)).rgb * 2.0 - 1.0);

        // Distance to the light
        float distance = length(lightPositionWorldspace - positionWorldspace);

        // Normal of the computed fragment, in camera space
        vec3 n = textureNormalTangentspace;

        // Direction of the light (from the fragment to the light)
        vec3 l = normalize(lightDirectionTangentspace);

        // Cosine of the angle between the normal and the light direction,
        // clamped above 0
        // - light is at the vertical of the triangle -> 1
        // - light is perpendicular to the triangle -> 0
        // - light is behind the triangle -> 0
        float cosTheta = clamp(dot(n, l), 0, 1);

        // Eye vector (towards the camera)
        vec3 E = normalize(eyeDirectionTangentspace);

        // Direction in which the triangle reflects the light
        vec3 R = reflect(-l, n);

        // Cosine of the angle between the Eye vector and the Reflect vector,
        // clamped to 0
        // - Looking into the reflection -> 1
        // - Looking elsewhere -> < 1
        float cosAlpha = clamp(dot(E, R), 0, 1);

        color.rgb =
            // ambient - simulates indirect lighting
            (useAmbientLight ? materialAmbientColor : vec3(0)) +

            // diffuse - the color of the object
            (useDiffuseLight ? (materialDiffuseColor * lightColor * lightPower * cosTheta / (distance * distance)) : vec3(0)) +

            // specular - reflective highlight, like a mirror
            (useSpecularLight ? (materialSpecularColor * lightColor * lightPower * pow(cosAlpha, 5) / (distance * distance)) : vec3(0));

        color.a = colorAlpha;
    }
};

string quadVertexShader = q{
    #version 330 core

    // Input vertex data, different for all executions of this shader.
    layout(location = 0) in vec3 vertexPositionModelspace;

    // Output data - will be interpolated for each fragment.
    out vec2 fragmentUV;

    void main()
    {
        gl_Position = vec4(vertexPositionModelspace, 1);
        fragmentUV = (vertexPositionModelspace.xy + vec2(1, 1)) / 2.0;
    }
};

string quadFragmentShader = q{
    #version 330 core

    in vec2 fragmentUV;

    out vec3 color;

    uniform sampler2D renderedTexture;
    uniform float time;
    uniform vec2 windowSize;

    void main()
    {
        color = texture(renderedTexture,
                        fragmentUV + 0.005 * vec2(sin(time + windowSize.x * fragmentUV.x),
                                          cos(time + windowSize.y * fragmentUV.y))).xyz;
    }
};

/** Our main render routine. */
void render(ref ProgramState state)
{
    glClearColor(0.0f, 0.0f, 0.4f, 0.0f);  // dark blue

    int width, height;
    glfwGetWindowSize(state.window.window, &width, &height);

    state.fbo.bind();

    // Render on the whole framebuffer,
    // complete from the lower left corner to the upper right
    glViewport(0, 0, width, height);

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    state.program.bind();

    /** Render each loaded object at a different position. */
    foreach (idx, model; state.loadedModels)
    {
        state.model = model;

        version (RenderMultipleModels)
        {
            state.modelMatrix = mat4.identity()
                                    .translate(-3.0, 0, 0)
                                    .translate(idx * 3.0, 0, 0);
        }

        state.updateProjection();
        renderImpl(state);
    }

    state.fbo.unbind();
    state.program.unbind();

    renderToScreen(state);
}

void renderToScreen(ref ProgramState state)
{
    int width, height;
    glfwGetWindowSize(state.window.window, &width, &height);

    // Render to the screen
    glBindFramebuffer(GL_FRAMEBUFFER, 0);

     // Render on the whole framebuffer, complete from the lower left corner to the upper right
    glViewport(0, 0, width, height);

    // Clear the screen
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Use our shader
    state.quadProgram.bind();

    // Bind our texture in Texture Unit 0
    state.renderedTexture.activate();
    state.renderedTexture.bind();

    // Set our "renderedTexture" sampler to user Texture Unit 0
    glUniform1i(state.renderedTextureUniform.ID, 0);
    glUniform1f(state.timeUniform.ID, cast(float)(glfwGetTime() * 10.0f));
    glUniform2f(state.windowSizeUniform.ID, width, height);

    int size        = 3; // (x, y, z) per vertex
    GLenum type     = GL_FLOAT;
    bool normalized = false;
    int stride     = 0;
    int offset     = 0;

    state.quadVertexBuffer.bind(state.quadPositionAttribute, size, type, normalized, stride, offset);
    state.quadPositionAttribute.enable();

    // Draw the triangles
    glDrawArrays(GL_TRIANGLES, 0, 6); // 2 * 3 indices starting at 0 -> 2 triangles

    state.renderedTexture.unbind();
    state.quadPositionAttribute.disable();
    state.quadVertexBuffer.unbind();
    state.quadProgram.unbind();
}

void renderImpl(ref ProgramState state)
{
    // set this to true when converting matrices from row-major order
    // to column-major order. Note that gl3n uses row-major ordering,
    // unlike the C++ glm library.
    enum doTranspose = GL_TRUE;
    enum matrixCount = 1;

    // set the matrices
    glUniformMatrix4fv(state.mvpUniform.ID, matrixCount, doTranspose, &state.mvpMatrix[0][0]);
    glUniformMatrix4fv(state.modelMatrixUniform.ID, matrixCount, doTranspose, &state.modelMatrix[0][0]);
    glUniformMatrix4fv(state.viewMatrixUniform.ID, matrixCount, doTranspose, &state.viewMatrix[0][0]);
    glUniformMatrix4fv(state.modelViewMatrixUniform.ID, matrixCount, doTranspose, &state.modelViewMatrix[0][0]);

    // note: this is a 3x3 matrix
    glUniformMatrix3fv(state.modelView3x3MatrixUniform.ID, matrixCount, doTranspose, &state.modelView3x3Matrix[0][0]);

    // set the light
    version (RenderMultipleModels)
    {
        vec3 lightPos = vec3(0, 0, 4);
    }
    else
    {
        vec3 lightPos = vec3(0, -1, 4);
    }

    glUniform3f(state.lightUniform.ID, lightPos.x, lightPos.y, lightPos.z);

    // set the light settings
    glUniform1i(state.useAmbientLightUniform.ID, state.useAmbientLight);
    glUniform1i(state.useDiffuseLightUniform.ID, state.useDiffuseLight);
    glUniform1i(state.useSpecularLightUniform.ID, state.useSpecularLight);

    // set the alpha
    glUniform1f(state.colorAlphaUniform.ID, state.colorAlpha);

    bindTextures(state);
    bindIndices(state);
    bindPositionAttribute(state);
    bindUVAttribute(state);
    bindNormalAttribute(state);
    bindTangentAttribute(state);
    bindBiTangentAttribute(state);

    // note: we're no longer using glDrawArrays, but glDrawElements instead.
    // the glDrawElements will use the indices which were last bound to
    // the builtin GL_ELEMENT_ARRAY_BUFFER (see bindIndices).
    auto indexCount = state.model.indexCount;
    glDrawElements(
        GL_TRIANGLES,      // mode
        indexCount,        // count
        GL_UNSIGNED_SHORT, // type
        null               // element array buffer offset
    );

    state.normalTexture.unbind();
    state.diffuseTexture.unbind();
    state.specularTexture.unbind();

    state.positionAttribute.disable();
    state.uvAttribute.disable();
    state.normalAttribute.disable();
    state.tangentAttribute.disable();
    state.biTangentAttribute.disable();

    state.model.vertexBuffer.unbind();
    state.model.uvBuffer.unbind();
    state.model.normalBuffer.unbind();
    state.model.tangentBuffer.unbind();
    state.model.biTangentBuffer.unbind();
}

void bindIndices(ref ProgramState state)
{
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, state.model.indexBuffer.ID);
}

void bindPositionAttribute(ref ProgramState state)
{
    enum int size = 3;  // (x, y, z) per vertex
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.model.vertexBuffer.bind(state.positionAttribute, size, type, normalized, stride, offset);
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

    state.model.uvBuffer.bind(state.uvAttribute, size, type, normalized, stride, offset);
    state.uvAttribute.enable();
}

void bindNormalAttribute(ref ProgramState state)
{
    // Normals are vectors and have (X, Y, Z)
    enum int size = 3;
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.model.normalBuffer.bind(state.normalAttribute, size, type, normalized, stride, offset);
    state.normalAttribute.enable();
}

void bindTangentAttribute(ref ProgramState state)
{
    enum int size = 3;  // (r, g, b)
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.model.tangentBuffer.bind(state.tangentAttribute, size, type, normalized, stride, offset);
    state.tangentAttribute.enable();
}

void bindBiTangentAttribute(ref ProgramState state)
{
    enum int size = 3;  // (r, g, b)
    enum GLenum type = GL_FLOAT;
    enum bool normalized = false;
    enum int stride = 0;
    enum int offset = 0;

    state.model.biTangentBuffer.bind(state.biTangentAttribute, size, type, normalized, stride, offset);
    state.biTangentAttribute.enable();
}

void bindTextures(ref ProgramState state)
{
    state.diffuseTexture.activate(GL_TEXTURE0);
    state.diffuseTexture.bind();
    state.program.setUniform1i(state.diffuseTextureUniform, 0);

    state.normalTexture.activate(GL_TEXTURE1);
    state.normalTexture.bind();
    state.program.setUniform1i(state.normalTextureUniform, 1);

    state.specularTexture.activate(GL_TEXTURE2);
    state.specularTexture.bind();
    state.program.setUniform1i(state.specularTextureUniform, 2);

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

        Additionally, the 1 / 2 / 3 keys will toggle the ambient, diffuse, and
        specular lighting models.
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

            case GLFW_KEY_1:
                state.useAmbientLight ^= 1;
                break;

            case GLFW_KEY_2:
                state.useDiffuseLight ^= 1;
                break;

            case GLFW_KEY_3:
                state.useSpecularLight ^= 1;
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

    auto window = createWindow("Tutorial 14 - Render To Texture");

    // hide the mouse cursor (even when not in client area).
    window.set_input_mode(GLFW_CURSOR, GLFW_CURSOR_DISABLED);

    auto state = ProgramState(window);

    hookCallbacks(window, state);

    // enable z-buffer depth testing.
    glEnable(GL_DEPTH_TEST);

    // accept fragment if it is closer to the camera than another one.
    glDepthFunc(GL_LESS);

    // we don't want to cull triangles whose normal is not towards the camera,
    // because if the object is transparent we want to see the back of the face.
	glDisable(GL_CULL_FACE);

    // Enable blending
    glEnable(GL_BLEND);

    /*
    New color in framebuffer =
           current alpha in framebuffer * current color in framebuffer +
           (1 - current alpha in framebuffer) * shader's output color

    Example from the image above, with red on top :

        // (the red was already blended with the white background)
        new color = 0.5*(0,1,0) + (1-0.5)*(1,0.5,0.5);
        new color = (1, 0.75, 0.25) // the same orange
    */
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    version (DisplayFrameRate)
    {
        import std.datetime;
        auto sw = StopWatch(AutoStart.yes);
        char[] text = "Benchmarking..".dup;  // initial text
        char[256] textBuffer;
    }

    size_t frameCount;

    while (!glfwWindowShouldClose(window.window))
    {
        version (DisplayFrameRate)
        {
            // Enable blending (we have to do this on every cycle due to the text routine disabling it).
            glEnable(GL_BLEND);
        }

        /*
            We want to update the camera position (the matrix)
            for every rendered image. Typically the game tick
            is decoupled from the render tick, but for simplicity
            we have a 1:1 match.
        */
        state.gameTick();

        /* Render to the back buffer. */
        render(state);

        version (DisplayFrameRate)
        {
            frameCount++;

            // update the text at a certain rate.
            // if (sw.peek >= 1.seconds)
            if (sw.peek.msecs >= 1000)
            {
                text = sformat(textBuffer, "%.3s msecs per frame.", 1000.0 / cast(double)frameCount);
                frameCount = 0;
                sw.reset();
            }

            /* display the time taken to render a frame. */
            const xOffset = 20;
            const yOffset = 20;
            const size = 30;
            state.textRenderer.render(text, xOffset, yOffset, size);
        }

        /* Swap front and back buffers. */
        window.swap_buffers();

        /* Poll for and process events. */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }
}
