/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module gltut.texture_loader;

// todo: port one of: nv_dds.cpp:
// C:\dev\projects\nv_dds , loadsavedds.cpp in gpu gems,
// dds.cpp, or mydds.cpp from E:\Downloads

import core.stdc.stdlib;

import std.stdio;
import std.string;

import glad.gl.all;

import glamour.texture;

/** Load a DDS image file (DXT format). */
Texture2D loadDDSImage(const(char)[] imagePath)
{
    auto file = File(cast(string)imagePath, "rb");

    auto fp = file.getFP();

    /* verify the type of file */
    char[4] filecode;
    fread(filecode.ptr, 1, 4, fp);
    if (filecode[] != "DDS ")
        throw new Exception("Not a DDS file.");

    enum HeaderSize = 124;

    /* get the surface desc */
    ubyte[HeaderSize] header;
    fread(&header, HeaderSize, 1, fp);

    uint height      = *cast(uint*)&(header[8]);
    uint width       = *cast(uint*)&(header[12]);
    uint linearSize  = *cast(uint*)&(header[16]);
    uint mipMapCount = *cast(uint*)&(header[24]);
    uint fourCC      = *cast(uint*)&(header[80]);

    /* how big is it going to be including all mipmaps? */
    size_t bufsize = mipMapCount > 1 ? linearSize * 2 : linearSize;
    ubyte* buffer = enforce(cast(ubyte*)malloc(bufsize * ubyte.sizeof));
    scope (exit) free(buffer);

    fread(buffer, 1, bufsize, fp);

    GLint components = (fourCC == FOURCC_DXT1) ? 3 : 4;

    uint formatGL;
    switch (fourCC)
    {
        case FOURCC_DXT1:
            formatGL = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
            break;

        case FOURCC_DXT3:
            formatGL = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
            break;

        case FOURCC_DXT5:
            formatGL = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
            break;

        default:
            throw new Exception(format("DDS: Unhandled format '%s'.", fourCC));
    }

    // Create one OpenGL texture
    GLuint textureID;
    glGenTextures(1, &textureID);

    // "Bind" the newly created texture : all future texture functions will modify this texture
    glBindTexture(GL_TEXTURE_2D, textureID);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    uint blockSize = (formatGL == GL_COMPRESSED_RGBA_S3TC_DXT1_EXT) ? 8 : 16;
    uint offset    = 0;

    /* load the mipmaps */
    for (uint level = 0; level < mipMapCount && (width || height); ++level)
    {
        uint size = ((width + 3) / 4) * ((height + 3) / 4) * blockSize;
        glCompressedTexImage2D(GL_TEXTURE_2D, level, formatGL, width, height,
                               0, size, buffer + offset);

        offset += size;
        width  /= 2;
        height /= 2;

        // Deal with Non-Power-Of-Two textures. This code is not included in the webpage to reduce clutter.
        if (width < 1)
            width = 1;

        if (height < 1)
            height = 1;
    }

    auto tex = new Texture2D();
    tex.texture = textureID;
    tex.format = formatGL;
    tex.internal_format = components;
    tex.type = GL_UNSIGNED_BYTE;
    tex.width = width;
    tex.height = height;
    return tex;
}

enum FOURCC_DXT1 = 0x31545844; // Equivalent to "DXT1" in ASCII
enum FOURCC_DXT3 = 0x33545844; // Equivalent to "DXT3" in ASCII
enum FOURCC_DXT5 = 0x35545844; // Equivalent to "DXT5" in ASCII
