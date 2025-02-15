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

    glyph::Glyph* glyph = glyph::create('i', 25);
    defer glyph.free();

    while (!window.shouldClose)
    {
        glyph.render(window, 200, 100, 12, 20);

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.refresh();
        window.clearColor(0, 0, 0);
    }

	return 0;
}
