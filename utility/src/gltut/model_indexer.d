/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module gltut.model_indexer;

/**
    Contains a converter from a Model to an IndexedModel.

    This code was adapted from Sam Hocevar.
    Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
*/

import core.internal.hash;

import std.array;
import std.math;

import gl3n.linalg;

import gltut.appender;
import gltut.model_loader;

/**
    Turn a model into an indexed model, which can be used with
    glDrawElements rather than glDrawArrays.
*/
IndexedModel getIndexedModel(Model model)
{
    AppenderWrapper!IndexedModel result;
    ushort[PackedVertex] vertexToOutIndex;

    // For each input vertex
    for (uint i = 0; i < model.vertexArr.length; i++)
    {
        PackedVertex packed = { model.vertexArr[i], model.uvArr[i], model.normalArr[i] };

        // Try to find a similar vertex in out_XXXX
        ushort index;
        bool found = getSimilarVertexIndex_fast(packed, vertexToOutIndex, index);

        if (found) // A similar vertex is already in the VBO, use it instead
        {
            result.indexArr ~= index;
        }
        else // If not, it needs to be added in the output data.
        {
            result.vertexArr ~= model.vertexArr[i];
            result.uvArr ~= model.uvArr[i];
            result.normalArr ~= model.normalArr[i];
            ushort newindex = cast(ushort)(result.vertexArr.data.length - 1);
            result.indexArr ~= newindex;
            vertexToOutIndex[packed] = newindex;
        }
    }

    return result.data;
}


IndexedTangentModel getIndexedTangentModel(Model model)
{
    AppenderWrapper!IndexedTangentModel result;

    auto tangents = model.getTangents();

    // For each input vertex
    for (size_t i = 0; i < model.vertexArr.length; i++)
    {
        // Try to find a similar vertex in out_XXXX
        ushort index;
        bool found = getSimilarVertexIndex(
                         model.vertexArr[i],
                         model.uvArr[i],
                         model.normalArr[i],
                         result.vertexArr.data,
                         result.uvArr.data,
                         result.normalArr.data,
                         index);

        if (found) // A similar vertex is already in the VBO, use it instead
        {
            result.indexArr ~= index;

            // Average the tangents and the bitangents
            result.tangentArr.data[index]   += tangents.tangentArr[i];
            result.biTangentArr.data[index] += tangents.biTangentArr[i];
        }
        else // If not, it needs to be added in the output data.
        {
            result.vertexArr ~= model.vertexArr[i];
            result.uvArr ~= model.uvArr[i];
            result.normalArr ~= model.normalArr[i];
            result.tangentArr ~= tangents.tangentArr[i];
            result.biTangentArr ~= tangents.biTangentArr[i];
            result.indexArr ~= cast(ushort)(result.vertexArr.data.length - 1);
        }
    }

    return result.data;
}

struct Tangents
{
    vec3[] tangentArr;
    vec3[] biTangentArr;
}

Tangents getTangents(Model model)
{
    AppenderWrapper!Tangents result;

    for (size_t i = 0; i < model.vertexArr.length; i += 3)
    {
        // Shortcuts for vertices
        vec3 v0 = model.vertexArr[i + 0];
        vec3 v1 = model.vertexArr[i + 1];
        vec3 v2 = model.vertexArr[i + 2];

        // Shortcuts for UVs
        vec2 uv0 = model.uvArr[i + 0];
        vec2 uv1 = model.uvArr[i + 1];
        vec2 uv2 = model.uvArr[i + 2];

        // Edges of the triangle : postion delta
        vec3 deltaPos1 = v1 - v0;
        vec3 deltaPos2 = v2 - v0;

        // UV delta
        vec2 deltaUV1 = uv1 - uv0;
        vec2 deltaUV2 = uv2 - uv0;

        float r = 1.0f / (deltaUV1.x * deltaUV2.y - deltaUV1.y * deltaUV2.x);
        vec3 tangent   = (deltaPos1 * deltaUV2.y - deltaPos2 * deltaUV1.y) * r;
        vec3 bitangent = (deltaPos2 * deltaUV1.x - deltaPos1 * deltaUV2.x) * r;

        // Set the same tangent for all three vertices of the triangle.
        // They will be merged later, in vboindexer.cpp
        result.tangentArr ~= tangent;
        result.tangentArr ~= tangent;
        result.tangentArr ~= tangent;

        // Same thing for binormals
        result.biTangentArr ~= bitangent;
        result.biTangentArr ~= bitangent;
        result.biTangentArr ~= bitangent;
    }

    // See "Going Further"
    foreach (i; 0 .. model.vertexArr.length)
    {
        vec3* n = &model.normalArr[i];
        vec3* t = &result.tangentArr.data[i];
        vec3* b = &result.biTangentArr.data[i];

        // Gram-Schmidt orthogonalize
        *t = (*t - *n * dot(*n, *t)).normalized();

        // Calculate handedness
        if (dot(cross(*n, *t), *b) < 0.0f)
        {
            *t = *t * -1.0f;
        }
    }

    return result.data;
}

void indexVBO_slow(
    vec3[] in_vertices,
    vec2[] in_uvs,
    vec3[] in_normals,

    ref ushort[] out_indices,
    ref vec3[] out_vertices,
    ref vec2[] out_uvs,
    ref vec3[] out_normals)
{
    // For each input vertex
    for (uint i = 0; i < in_vertices.length; i++)
    {
        // Try to find a similar vertex in out_XXXX
        ushort index;
        bool found = getSimilarVertexIndex(in_vertices[i], in_uvs[i], in_normals[i], out_vertices, out_uvs, out_normals, index);

        if (found)            // A similar vertex is already in the VBO, use it instead !
        {
            out_indices ~= index;
        }
        else           // If not, it needs to be added in the output data.
        {
            out_vertices ~= in_vertices[i];
            out_uvs ~= in_uvs[i];
            out_normals ~= in_normals[i];
            out_indices ~= cast(ushort)(out_vertices.length - 1);
        }
    }
}

// Returns true iif v1 can be considered equal to v2
private bool is_near(float v1, float v2)
{
    return fabs(v1 - v2) < 0.01f;
}

// Searches through all already-exported vertices
// for a similar one.
// Similar = same position + same UVs + same normal
private bool getSimilarVertexIndex(
    vec3 in_vertex,
    vec2 in_uv,
    vec3 in_normal,
    vec3[] out_vertices,
    vec2[] out_uvs,
    vec3[] out_normals,
    ref ushort result)
{
    // Lame linear search
    for (uint i = 0; i < out_vertices.length; i++)
    {
        if (is_near(in_vertex.x, out_vertices[i].x) &&
            is_near(in_vertex.y, out_vertices[i].y) &&
            is_near(in_vertex.z, out_vertices[i].z) &&
            is_near(in_uv.x, out_uvs     [i].x) &&
            is_near(in_uv.y, out_uvs     [i].y) &&
            is_near(in_normal.x, out_normals [i].x) &&
            is_near(in_normal.y, out_normals [i].y) &&
            is_near(in_normal.z, out_normals [i].z))
        {
            result = cast(ushort)i;
            return true;
        }
    }

    // No other vertex could be used instead.
    // Looks like we'll have to add it to the VBO.
    return false;
}

struct PackedVertex
{
    vec3 position;
    vec2 uv;
    vec3 normal;

    // workaround for 2.066.1+
    hash_t toHash() const nothrow
    {
        try
        {
            return hashOf(*cast(ubyte[typeof(this).sizeof]*)&this);
        }
        catch (Throwable) { assert(0, "assert"); }
    }
}

private bool getSimilarVertexIndex_fast(
    ref PackedVertex packed,
    ref ushort[PackedVertex] vertexToOutIndex,
    ref ushort result)
{
    if (auto res = packed in vertexToOutIndex)
    {
        result = *res;
        return true;
    }

    return false;
}
