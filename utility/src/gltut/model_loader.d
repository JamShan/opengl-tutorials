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

import std.conv;
import std.exception;
import std.file;
import std.path;
import std.stdio;
import std.string;

import gl3n.linalg;
import gl3n.math;

///
struct Model
{
    vec3[] vertexArr;
    vec3[] indexArr;
    vec2[] uvArr;
    vec3[] normalArr;
}

/**
    Load a .obj model. It doesn't use VBO indexing,
    but instead converts everything into triangles.
*/
Model loadObjModel(string path)
{
    Model result;

    uint[] vertexIndices, uvIndices, normalIndices;
    vec3[] temp_vertices;
    vec2[] temp_uvs;
    vec3[] temp_normals;

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

    // For each vertex of each triangle
    foreach (i; 0 .. vertexIndices.length)
    {
        // Get the indices of its attributes
        uint vertexIndex = vertexIndices[i];
        uint uvIndex     = uvIndices[i];
        uint normalIndex = normalIndices[i];

        // Get the attributes thanks to the index
        vec3 vertex = temp_vertices[vertexIndex - 1];
        vec2 uv     = temp_uvs[uvIndex - 1];
        vec3 normal = temp_normals[normalIndex - 1];

        // Put the attributes in the buffers
        result.vertexArr ~= vertex;
        result.uvArr ~= uv;
        result.normalArr ~= normal;
    }

    return result;
}
