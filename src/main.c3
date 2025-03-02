module terminal;

import terminal;
import input;
import glfw;

import libc;
import std::io;
import std::core::mem;
import std::math;
import std::collections::map;

fn int main(String[] args)
{
    terminal::Terminal terminal = terminal::create(900, 600, "m0tty", "test.ttf", 20)!!;
    defer terminal.free();
    terminal.inputHandler.addInput({ "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 });
    input::InputButton* quit = terminal.inputHandler.getInput("quit");

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
