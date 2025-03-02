module main;

import terminal;
import input;
import glfw;
import opengl;

import libc;
import std::io;
import std::time;
import std::thread;
import std::core::mem;
import std::math;
import std::collections::map;

struct Cursor { uint x; uint y; }

const FPS = 60.0;

fn int main(String[] args)
{
    terminal::Terminal* terminal = terminal::create(900, 600, "m0tty", "test.ttf", fontSize: 20, fps: 0)!!;
    defer terminal.free();
    terminal.inputHandler.addInput({ "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 });
    input::InputButton* quitInput = terminal.inputHandler.getInput("quit")!!;

    double time;
    Cursor[4] cursors;
    while (!terminal.window.shouldClose)
    {
        terminal.preRender();
        foreach (&cursor : cursors)
        {
            if (rnd() < 0.1f)
            {
                cursor.y = 0;
                cursor.x = rand(terminal.grid.width);
            }
            terminal.cursor.set(cursor.x, cursor.y);
            terminal.assignChar((char)rand_in_range(33, 126));
            cursor.y++;
        }
        
        terminal.render()!!;

        if (quitInput.activated()) terminal.window.shouldClose = true;
    }

	return 0;
}
