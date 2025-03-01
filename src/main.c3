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

    const FONT_SIZE = 20;
    glyph::FontAtlas* atlas = glyph::createFontAtlas(FONT_SIZE)!!;
    defer atlas.free();

    char[] accepted = {' ', '!', '"', '#', '$', '%', '&', '\'', '(', ')', '*', '+', ',', '-', '.', '/', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ':', ';', '<', '=', '>', '?', '@', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '[', '\\', ']', '^', '_', '`', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '{', '|', '}', '~'};

    atlas.bindTexture();

    double time;
    int xs = 240;
    int ys = 54;
    char[1920 * 1080] grid;
    float xMul = atlas.getChar('#')!!.xadvance;
    float yMul = FONT_SIZE;
    math::random::SimpleRandom rand;
    for (int i = 0; i < grid.len; i++) grid[i] = ' ';
    renderer::Vector2[4] cursors;
    while (!window.shouldClose)
    {
        if (window.sizeChanged)
        {
            for (int i = 0; i < xs; i++) for (int j = 0; j < ys; j++) grid[j + ys * i] = ' ';
            xs = (int)(window.width  / xMul);
            ys = (int)(window.height / yMul);
        }
        foreach (&cursor : cursors)
        {
            if ((float)rand.next_byte() / char.max < 0.1f)
            {
                cursor.y = 0;
                cursor.x = (float)rand.next_byte() / (float)char.max * xs;
            }
            grid[(int)cursor.x + xs * (int)cursor.y++] = accepted[(rand.next_byte() % (accepted.len - 1)) + 1];
        }
        
        atlas.renderGrid((char*)&grid, window.width, window.height, xs, ys, 20)!!;

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
