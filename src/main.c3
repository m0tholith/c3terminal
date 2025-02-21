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

    char[] accepted = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

    for (int c = 0; c < accepted.len; c++)
    {
        char i = accepted[c];
        io::printfn("%03d '%c' \t x0 %03d  y0 %03d    x1 %03d  y1 %03d    xoff %d  yoff %d", i, i, atlas.chars[c].x0, atlas.chars[c].y0, atlas.chars[c].x1, atlas.chars[c].y1, atlas.chars[c].xoff, atlas.chars[c].yoff);
    }
    atlas.bindTexture();

    double time;
    const int XS = 160;
    const int YS = 54;
    char[XS][YS] grid;
    float xMul = 12.0f;
    float yMul = 20.0f;
    math::random::SimpleRandom rand;
    for (int i = 0; i < XS; i++) for (int j = 0; j < YS; j++) grid[j][i] = accepted[rand.next_byte() % accepted.len];
    while (!window.shouldClose)
    {
        for (int i = 0; i < XS; i++)
        {
            char c = accepted[rand.next_byte() % accepted.len];
            grid[rand.next_byte() % YS][rand.next_byte() % XS] = c;
        }
        
        for (int i = 0; i < XS; i++)
        {
            for (int j = 0; j < YS; j++)
            {
                atlas.renderGlyph(window, grid[j][i], i * xMul, (j+1.0f) * yMul, atlas.fontSize)!!;
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
