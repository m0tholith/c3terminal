module terminal;

import window;
import input;
import renderer;
import glfw;
import opengl;
import glyph;
import stb_truetype;

import libc;
import std::io;
import std::core::mem;
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

    glyph::FontAtlas* atlas = glyph::createFontAtlas(20)!!;
    defer atlas.free();

    char[] accepted = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

    atlas.bindTexture();

    double time;
    const int XS = 240;
    const int YS = 54;
    char[XS][YS] grid;
    float xMul = 8.0f;
    float yMul = 20.0f;
    math::random::SimpleRandom rand;
    for (int i = 0; i < XS; i++) for (int j = 0; j < YS; j++) grid[j][i] = accepted[rand.next_byte() % accepted.len];
    while (!window.shouldClose)
    {
        for (int i = 0; i < 1; i++)
        {
            char c = accepted[rand.next_byte() % accepted.len];
            grid[rand.next_byte() % YS][rand.next_byte() % XS] = c;
        }
        
        for (int j = 0; j < YS; j++)
        {
            for (int i = 0; i < XS; i++)
            {
                atlas.renderGlyph(window, grid[j][i], i * xMul, j * yMul, 20)!!;
            }
        }

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.clearColor(0.1176, 0.1176, 0.1803);
        window.refresh();

        time = glfw::getTime();

        GLenum err = gl::getError();
        while (err != 0)
        {
            io::printfn("0x%08X", err);
            err = gl::getError();
        }
    }

	return 0;
}
