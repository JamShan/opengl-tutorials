/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module gltut.appender;

/**
    This is an implementation of ER Issue 12732:
    https://issues.dlang.org/show_bug.cgi?id=12732
*/

import std.array : Appender, join;
import std.string : format;
import std.typetuple : staticMap;

///
struct AppenderWrapper(T)
{
    alias Fields = staticMap!(ApplyAppender, typeof(T.tupleof));
    Fields fields;

    mixin(generateAliases!T);

    @property T data()
    {
        T res;

        foreach (idx, field; fields)
        {
            static if (is(typeof(res.tupleof[idx]) : E[], E))
                res.tupleof[idx] = field.data;
            else
                res.tupleof[idx] = field;
        }

        return res;
    }
}

///
unittest
{
    alias vec3 = int[3];

    struct Model
    {
        vec3[] indices;
        vec3[] vertices;
        vec3[] normals;
        int other;
    }

    Model loadModel(string path)
    {
        AppenderWrapper!(typeof(return)) result;

        vec3 vector;

        result.indices ~= vector;
        result.vertices ~= vector;
        result.normals ~= vector;
        result.other = 1;

        return result.data;
    }
}

private alias ApplyAppender(T : E[], E) = Appender!T;
private alias ApplyAppender(T) = T;

private enum Identifier(alias S) = __traits(identifier, S);

private string generateAliases(T)()
{
    string[] res;

    foreach (idx, str; staticMap!(Identifier, T.tupleof))
        res ~= format("alias %s = fields[%s];", str, idx);

    return res.join("\n");
}
