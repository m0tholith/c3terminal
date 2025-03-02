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

def Vec2ui = uint[<2>];

const FPS = 60.0;

fn int main(String[] args)
{
    terminal::Terminal* terminal = terminal::create(900, 600, "test.ttf", windowName: "m0tty", fontSize: 20, bg: { 0.1176f, 0.117f, 0.1803f }, fg: { 0.8039f, 0.8392f, 0.9568f }, fps: 0)!!;
    defer terminal.free();
    terminal.inputHandler.addInput({ "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 });
    input::InputButton* quitInput = terminal.inputHandler.getInput("quit")!!;

    double time;
    Vec2ui[4] cursors;
    while (!terminal.window.shouldClose)
    {
        terminal.preRender();
        foreach (&cursor : cursors)
        {
            if (rnd() < 0.1f || terminal.window.sizeChanged)
            {
                cursor.y = terminal.grid.height - 1;
                cursor.x = rand(terminal.grid.width);
            }
            terminal.cursor = *cursor;
            terminal.assignChar((char)rand_in_range(33, 126));
            cursor.y--;
            cursor.y %= terminal.grid.height;
        }
        
        terminal.render()!!;

        if (quitInput.activated()) terminal.window.shouldClose = true;
    }

	return 0;
}
