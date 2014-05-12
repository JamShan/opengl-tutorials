/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module gltut.text_renderer;

import deimos.glfw.glfw3;

import dgl;

import glad.gl.all;

import gl3n.linalg;
import gl3n.math;

import glamour.texture;

import glwtf.window;

import gltut.scopebuffer;

///
struct TextRenderer
{
    ///
    this(Window window, string fontTexturePath)
    {
        this.window = window;

        // Initialize texture
        texture = Texture2D.from_image(fontTexturePath);

        shaders ~= Shader.fromText(ShaderType.vertex, textVertexShader);
        shaders ~= Shader.fromText(ShaderType.fragment, textFragmentShader);
        program = new Program(shaders);

        this.vertexBuffer = new GLBuffer((float[]).init, UsageHint.staticDraw);
        this.uvBuffer = new GLBuffer((float[]).init, UsageHint.staticDraw);

        // Initialize uniform IDs
        textureSamplerUniform = program.getUniform("textureSampler");
        windowWidthUniform = program.getUniform("windowWidth");
        windowHeightUniform = program.getUniform("windowHeight");

        this.positionAttribute = program.getAttribute("vertexPosition_screenspace");
        this.uvAttribute = program.getAttribute("vertexUV");
    }

    void render(const(char)[] text, int xOffset, int yOffset, int fontSize)
    {
        if (!text.length)
            return;

        vec2[256 * 6] vertexBuf = void;
        auto vertexArr = vertexBuf.scopeBuffer();

        vec2[256 * 6] uvBuf = void;
        auto uvArr = uvBuf.scopeBuffer();

        foreach (i, char ch; text)
        {
            vec2 vertex_up_left    = vec2(xOffset + i * fontSize,
                                          yOffset + fontSize);

            vec2 vertex_up_right   = vec2(xOffset + i * fontSize + fontSize,
                                          yOffset + fontSize);

            vec2 vertex_down_left  = vec2(xOffset + i * fontSize,
                                          yOffset);

            vec2 vertex_down_right = vec2(xOffset + i * fontSize + fontSize,
                                          yOffset);

            vertexArr ~= vertex_up_left;
            vertexArr ~= vertex_down_left;
            vertexArr ~= vertex_up_right;
            vertexArr ~= vertex_down_right;
            vertexArr ~= vertex_up_right;
            vertexArr ~= vertex_down_left;

            float uv_x = (ch % 16) / 16.0f;
            float uv_y = (ch / 16) / 16.0f;

            vec2 uv_up_left    = vec2(uv_x, uv_y);

            vec2 uv_up_right   = vec2(uv_x + 1.0f / 16.0f,
                                      uv_y);

            vec2 uv_down_left  = vec2(uv_x,
                                      uv_y + 1.0f / 16.0f);

            vec2 uv_down_right = vec2(uv_x + 1.0f / 16.0f,
                                      uv_y + 1.0f / 16.0f);

            uvArr ~= uv_up_left;
            uvArr ~= uv_down_left;
            uvArr ~= uv_up_right;
            uvArr ~= uv_down_right;
            uvArr ~= uv_up_right;
            uvArr ~= uv_down_left;
        }

        program.bind();

        bindPositionAttribute();
        bindUVAttribute();

        vertexBuffer.write(vertexBuf[0 .. vertexArr.length], UsageHint.staticDraw);
        uvBuffer.write(uvBuf[0 .. uvArr.length], UsageHint.staticDraw);

        int width;
        int height;
        glfwGetWindowSize(window.window, &width, &height);

        // set the window size
        glUniform1f(windowWidthUniform.ID, width);
        glUniform1f(windowHeightUniform.ID, height);

        // Bind texture
        texture.activate();
        texture.bind();

        // Set our "textureSampler" sampler to user Texture Unit 0
        glUniform1i(textureSamplerUniform.ID, 0);

        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        glDrawArrays(GL_TRIANGLES, 0, vertexArr.length);

        glDisable(GL_BLEND);

        vertexBuffer.unbind();
        uvBuffer.unbind();
        positionAttribute.disable();
        uvAttribute.disable();

        vertexArr.free();
        uvArr.free();
    }

    void bindPositionAttribute()
    {
        enum int size = 2;  // (x, y) per vertex
        enum GLenum type = GL_FLOAT;
        enum bool normalized = false;
        enum int stride = 0;
        enum int offset = 0;

        this.vertexBuffer.bind(this.positionAttribute, size, type, normalized, stride, offset);
        this.positionAttribute.enable();
    }

    void bindUVAttribute()
    {
        // (u, v) per vertex
        enum int size = 2;
        enum GLenum type = GL_FLOAT;
        enum bool normalized = false;
        enum int stride = 0;
        enum int offset = 0;

        this.uvBuffer.bind(this.uvAttribute, size, type, normalized, stride, offset);
        this.uvAttribute.enable();
    }

    /** Release all OpenGL resources. */
    void release()
    {
        foreach (shader; shaders)
            shader.release();

        texture.remove();

        vertexBuffer.release();
        uvBuffer.release();

        program.release();
    }

    Texture2D texture;

    Shader[] shaders;

    GLBuffer vertexBuffer;
    GLBuffer uvBuffer;

    Attribute positionAttribute;
    Attribute uvAttribute;

    Uniform textureSamplerUniform;
    Uniform windowWidthUniform;
    Uniform windowHeightUniform;
    Program program;

    Window window;
}

string textVertexShader = q{
    #version 330 core

    // Input vertex data, different for all executions of this shader.
    layout(location = 0) in vec2 vertexPosition_screenspace;
    layout(location = 1) in vec2 vertexUV;

    // Output data ; will be interpolated for each fragment.
    out vec2 UV;

    uniform float windowWidth;
    uniform float windowHeight;

    void main()
    {
        // Output position of the vertex, in clip space
        // map [0..800][0..600] to [-1..1][-1..1]
        // [0..800][0..600] -> [-400..400][-300..300]
        vec2 vertexPositionClipSpace = vertexPosition_screenspace - vec2(windowWidth / 2, windowHeight / 2);
        vertexPositionClipSpace /= vec2(windowWidth / 2, windowHeight / 2);

        gl_Position = vec4(vertexPositionClipSpace, 0, 1);

        // UV of the vertex. No special space for this one.
        UV = vertexUV;
    }
};

string textFragmentShader = q{
    #version 330 core

    // Interpolated values from the vertex shaders
    in vec2 UV;

    // Ouput data
    out vec4 color;

    // Values that stay constant for the whole mesh.
    uniform sampler2D textureSampler;

    void main()
    {
        color = texture2D(textureSampler, UV);
    }
};
