module terminal;

import window;
import input;
import renderer;
import glfw;
import opengl;
import schrift;
import glyph;

import std::io;
import std::math;
import std::collections::map;

fn int main(String[] args)
{
    window::initSystem();
    defer window::terminateSystem();

    window::Window* window = window::create(800, 600, "m0th")!!;

    input::InputHandler* inputHandler = input::createHandler(input::InputButton[] {
        { "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 }
    });
    defer inputHandler.free();

    input::InputButton* quitInput = inputHandler.getInput("quit")!!;

    gl::enable(gl::GL_BLEND);
    gl::blendFunc(gl::GL_SRC_ALPHA, gl::GL_ONE_MINUS_SRC_ALPHA);

    map::HashMap(<schrift::UChar, glyph::Glyph*>) glyphs;
    glyphs.new_init();
    defer {
        for (char i = 'a'; i <= 'z'; i++) glyphs[i].free()!!;
        glyphs.free();
    }
    for (char i = 'a'; i <= 'z'; i++) glyphs[i] = glyph::create(i, 120);

    while (!window.shouldClose)
    {
        double x = 100;
        double y = 100;
        double fontSize = 24;
        for (char i = 'a'; i <= 'z'; i++)
        {
            glyph::Glyph* g = glyphs[i]!!;

            g.render(window, x, y, 24);
            x += g.metrics.advanceWidth * fontSize / g.scale;
        }

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.refresh();
        window.clearColor(0, 0, 0);
    }

	return 0;
}
