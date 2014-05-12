/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module gltut.scopebuffer;

/// Wrapper around std.internal.scopebuffer that defines binary operators.
struct ScopeBuffer(E)
{
    static if (__VERSION__ >= 2066)
        import std.internal.scopebuffer : ScopeBuffer;
    else
        import gltut.internal.scopebuffer;

    ScopeBuffer!E scopeBuffer;
    alias scopeBuffer this;

    this(size_t Len)(ref E[Len] buf)
    {
        scopeBuffer = ScopeBuffer!E(buf);
    }

    void opOpAssign(string op : "~", T)(T t)
    {
        scopeBuffer.put(t);
    }
}

auto scopeBuffer(T : E[], E)(ref T buf)
{
    return ScopeBuffer!E(buf);
}
