/*
 *            Copyright (C) 2004 Sam Hocevar <sam@hocevar.net>
 *  Distributed under the WTFPL Public License, Version 2, December 2004
 *         (See license copy at http://www.wtfpl.net/txt/copying)
 */
module tut_01_window;

/**
    D2 Port of:
    http://www.opengl-tutorial.org/beginners-tutorials/tutorial-1-opening-a-window
*/

import deimos.glfw.glfw3;

import gltut.utility;

void main()
{
    auto window = createWindow("Tutorial 01 - Show Window");

    while (!glfwWindowShouldClose(window.window))
    {
        /* Swap front and back buffers. */
        window.swap_buffers();

        /* Poll for and process events. */
        glfwPollEvents();

        if (window.is_key_down(GLFW_KEY_ESCAPE))
            glfwSetWindowShouldClose(window.window, true);
    }
}
