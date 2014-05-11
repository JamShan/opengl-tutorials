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

import std.array;
import std.math;

import gl3n.linalg;

import gltut.appender;
import gltut.model_loader;

/** Turn a model into an indexed model, which can be used with glDrawElements rather than glDrawArrays. */
IndexedModel getIndexedModel(Model model)
{
    AppenderWrapper!IndexedModel result;
    ushort[PackedVertex] VertexToOutIndex;

    // For each input vertex
    for (uint i = 0; i < model.vertexArr.length; i++)
    {
        PackedVertex packed = { model.vertexArr[i], model.uvArr[i], model.normalArr[i] };

        // Try to find a similar vertex in out_XXXX
        ushort index;
        bool found = getSimilarVertexIndex_fast(packed, VertexToOutIndex, index);

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
            VertexToOutIndex[packed] = newindex;
        }
    }

    return result.data;
}

void indexVBO_TBN(
    vec3[] in_vertices,
    vec2[] in_uvs,
    vec3[] in_normals,
    vec3[] in_tangents,
    vec3[] in_bitangents,
    ref ushort[] out_indices,
    ref vec3[] out_vertices,
    ref vec2[] out_uvs,
    ref vec3[] out_normals,
    ref vec3[] out_tangents,
    ref vec3[] out_bitangents)
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

            // Average the tangents and the bitangents
            out_tangents[index]   += in_tangents[i];
            out_bitangents[index] += in_bitangents[i];
        }
        else           // If not, it needs to be added in the output data.
        {
            out_vertices ~= in_vertices[i];
            out_uvs ~= in_uvs[i];
            out_normals ~= in_normals[i];
            out_tangents ~= in_tangents[i];
            out_bitangents ~= in_bitangents[i];
            out_indices ~= cast(ushort)(out_vertices.length - 1);
        }
    }
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
    ref vec3 in_vertex,
    ref vec2 in_uv,
    ref vec3 in_normal,
    ref vec3[] out_vertices,
    ref vec2[] out_uvs,
    ref vec3[] out_normals,
    ref ushort result
    )
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
}

private bool getSimilarVertexIndex_fast(
    ref PackedVertex packed,
    ref ushort[PackedVertex] VertexToOutIndex,
    ref ushort result)
{
    if (auto res = packed in VertexToOutIndex)
    {
        result = *res;
        return true;
    }

    return false;
}
