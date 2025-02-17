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

    glyph::Font* font = glyph::createFont("test.ttf", 120)!!;

    double time;
    while (!window.shouldClose)
    {
        double fontSize = 10;
        font.renderText(window, "abcdefghijklmnopqrstuvwxyz", 100 + 30 * math::sin(30 * time), 100, fontSize)!!;
        font.renderText(window, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 200 + 30 * math::sin(20 * time+10), 200+fontSize*2, fontSize)!!;
        font.renderText(window, "Program linked to executable 'build/terminal'.", 100, 200+fontSize*4 + 40 * math::sin(10 * time+20), fontSize)!!;
        font.renderText(window, "Lorem ipsum dolor sit amet orci aliquam.", 0, 500, fontSize)!!;

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.refresh();
        window.clearColor(0.1176, 0.1176, 0.1803);

        time = glfw::getTime();
    }

	return 0;
}
