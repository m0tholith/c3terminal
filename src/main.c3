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

    window::Window* window = window::create(256, 512, "m0th")!!;
    defer window.free();

    input::InputHandler* inputHandler = input::createHandler(input::InputButton[] {
        { "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 }
    });
    defer inputHandler.free();

    input::InputButton* quitInput = inputHandler.getInput("quit")!!;

    gl::enable(gl::GL_BLEND);
    gl::blendFunc(gl::GL_SRC_ALPHA, gl::GL_ONE_MINUS_SRC_ALPHA);

    glyph::Glyph* glyph = glyph::create('i');
    defer glyph.free();

    while (!window.shouldClose)
    {
        glyph.render();

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.refresh();
        window.clearColor(0.2f, 0.3f, 0.3f);
    }

	return 0;
}
