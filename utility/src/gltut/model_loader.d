/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module gltut.model_loader;

/**
    Contains a very minimal implementation of a .obj model loader.
*/

import std.array;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.stdio;
import std.string;

import gl3n.linalg;

import derelict.assimp3.assimp;
import derelict.assimp3.types;

import gltut.appender;
import gltut.model_indexer;

/// A Model that should be drawn via glDrawArrays.
struct Model
{
    vec3[] vertexArr;
    vec2[] uvArr;
    vec3[] normalArr;
}

/// A Model that should be drawn via glDrawElements.
struct IndexedModel
{
    ushort[] indexArr;
    vec3[] vertexArr;
    vec2[] uvArr;
    vec3[] normalArr;
}

/**
    Load a .obj model.
*/
Model loadObjModel(string path)
{
    Appender!(uint[]) vertexIndices;
    Appender!(uint[]) uvIndices;
    Appender!(uint[]) normalIndices;
    Appender!(vec3[]) temp_vertices;
    Appender!(vec2[]) temp_uvs;
    Appender!(vec3[]) temp_normals;

    enforce(path.exists);
    enforce(path.extension == ".obj");
    auto file = File(path, "r");

    foreach (line; file.byLine())
    {
        line = line.strip;

        if (!line.length || line[0] == '#')
            continue;

        char[][] words = split(line);

        if (words[0] == "v")
        {
            temp_vertices ~= vec3(words[1].to!float, words[2].to!float, words[3].to!float);
        }
        else
        if (words[0] == "vt")
        {
            vec2 uv = vec2(words[1].to!float, words[2].to!float);
            uv.y = uv.y;
            temp_uvs ~= uv;
        }
        else
        if (words[0] == "vn")
        {
            temp_normals ~= vec3(words[1].to!float, words[2].to!float, words[3].to!float);
        }
        else
        if (words[0] == "f")
        {
            uint[3] vertexIndex, uvIndex, normalIndex;

            auto col1 = words[1].split("/").to!(int[]);
            auto col2 = words[2].split("/").to!(int[]);
            auto col3 = words[3].split("/").to!(int[]);

            vertexIndex[0] = col1[0];
            vertexIndex[1] = col2[0];
            vertexIndex[2] = col3[0];

            uvIndex[0] = col1[1];
            uvIndex[1] = col2[1];
            uvIndex[2] = col3[1];

            normalIndex[0] = col1[2];
            normalIndex[1] = col2[2];
            normalIndex[2] = col3[2];

            vertexIndices ~= vertexIndex[0];
            vertexIndices ~= vertexIndex[1];
            vertexIndices ~= vertexIndex[2];
            uvIndices ~= uvIndex[0];
            uvIndices ~= uvIndex[1];
            uvIndices ~= uvIndex[2];
            normalIndices ~= normalIndex[0];
            normalIndices ~= normalIndex[1];
            normalIndices ~= normalIndex[2];
        }
    }

    AppenderWrapper!Model result;

    // For each vertex of each triangle
    foreach (i; 0 .. vertexIndices.data.length)
    {
        // Get the indices of its attributes
        uint vertexIndex = vertexIndices.data[i];
        uint uvIndex     = uvIndices.data[i];
        uint normalIndex = normalIndices.data[i];

        // Get the attributes thanks to the index
        vec3 vertex = temp_vertices.data[vertexIndex - 1];
        vec2 uv     = temp_uvs.data[uvIndex - 1];
        vec3 normal = temp_normals.data[normalIndex - 1];

        // Put the attributes in the buffers
        result.vertexArr ~= vertex;
        result.uvArr ~= uv;
        result.normalArr ~= normal;
    }

    return result.data;
}

/**
    Load a .obj model with AssetImport.
    AssetImport will be lazily loaded if
    it's not loaded already.
*/
Model aiLoadObjModel(string path)
{
    if (!DerelictASSIMP3.isLoaded)
        DerelictASSIMP3.load();

    Model result;

    auto scene = aiImportFile(path.toStringz, 0);
    enforce(scene !is null, aiGetErrorString().to!string());
    const aiMesh* mesh = scene.mMeshes[0];     // In this simple example code we always use the 1rst mesh (in OBJ files there is often only one anyway)

    // Fill vertices positions
    result.vertexArr.reserve(mesh.mNumVertices);

    foreach (i; 0 .. mesh.mNumVertices)
    {
        aiVector3D pos = mesh.mVertices[i];
        result.vertexArr ~= vec3(pos.x, pos.y, pos.z);
    }

    // Fill vertices texture coordinates
    result.uvArr.reserve(mesh.mNumVertices);

    foreach (i; 0 .. mesh.mNumVertices)
    {
        aiVector3D UVW = mesh.mTextureCoords[0][i]; // Assume only 1 set of UV coords; AssImp supports 8 UV sets.
        result.uvArr ~= vec2(UVW.x, UVW.y);
    }

    // Fill vertices normals
    result.normalArr.reserve(mesh.mNumVertices);

    foreach (i; 0 .. mesh.mNumVertices)
    {
        aiVector3D n = mesh.mNormals[i];
        result.normalArr ~= vec3(n.x, n.y, n.z);
    }

    // The "scene" pointer will be deleted automatically by "importer"
    return result;
}
