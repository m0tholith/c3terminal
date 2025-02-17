module terminal;

import window;
import input;
import renderer;
import glfw;
import opengl;
import schrift;
import glyph;

import libc;
import std::io;
import std::math;
import std::collections::map;

fn int main(String[] args)
{
    window::initSystem();
    defer window::terminateSystem();

    window::Window* window = window::create(900, 600, "m0th")!!;

    input::InputHandler* inputHandler = input::createHandler(input::InputButton[] {
        { "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 }
    });
    defer inputHandler.free();

    input::InputButton* quitInput = inputHandler.getInput("quit")!!;

    gl::enable(gl::GL_BLEND);
    gl::blendFunc(gl::GL_SRC_ALPHA, gl::GL_ONE_MINUS_SRC_ALPHA);

    glyph::Font* font = glyph::createFont("test.ttf", 120)!!;

    char[] accepted = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-=_+[]{}\\|/<>,.;':\"`~ ";

    double time;
    const int XS = 160;
    const int YS = 54;
    char[XS][YS] grid;
    double xMul = 12.0;
    double yMul = 20.0;
    math::random::SimpleRandom rand;
    for (int i = 0; i < XS; i++) for (int j = 0; j < YS; j++) grid[j][i] = accepted[rand.next_byte() % accepted.len];
    while (!window.shouldClose)
    {
        double fontSize = 10;

        for (int i = 0; i < XS; i++)
        {
            char c = accepted[rand.next_byte() % accepted.len];
            grid[rand.next_byte() % YS][rand.next_byte() % XS] = c;
        }
        
        for (int i = 0; i < XS; i++)
        {
            for (int j = 0; j < YS; j++)
            {
                if (grid[j][i] != 0) font.renderGlyph(window, grid[j][i], i * xMul, 4 + j * yMul, fontSize)!!;
            }
        }

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.clearColor(0.1176, 0.1176, 0.1803);
        window.refresh();

        time = glfw::getTime();
    }

	return 0;
}
