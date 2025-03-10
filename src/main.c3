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

const float[<3>][] COLORS = {
    { 1.000f, 0.933f, 0.867f },
    { 1.000f, 0.800f, 0.800f },
    { 1.000f, 0.800f, 0.933f },
    { 0.800f, 0.667f, 1.000f },
    { 1.000f, 0.533f, 0.667f },
    { 0.933f, 0.667f, 0.667f },
    { 1.000f, 0.733f, 0.533f },
    { 1.000f, 0.933f, 0.667f },
    { 0.667f, 0.933f, 0.667f },
    { 0.600f, 0.933f, 0.867f },
    { 0.533f, 0.867f, 0.933f },
    { 0.467f, 0.800f, 0.933f },
    { 0.533f, 0.733f, 1.000f },
    { 0.733f, 0.733f, 1.000f },
    { 0.800f, 0.867f, 1.000f },
    { 0.733f, 0.800f, 0.867f },
    { 0.667f, 0.667f, 0.800f },
    { 0.600f, 0.600f, 0.733f },
    { 0.467f, 0.533f, 0.600f },
    { 0.400f, 0.467f, 0.533f },
    { 0.333f, 0.333f, 0.467f },
    { 0.267f, 0.267f, 0.333f },
    { 0.200f, 0.200f, 0.267f },
    { 0.067f, 0.067f, 0.133f },
    { 0.067f, 0.067f, 0.133f },
    { 0.067f, 0.067f, 0.067f },
};

fn int main(String[] args)
{
    terminal::Terminal terminal;
    terminal.init(900, 600, "test.ttf", windowName: "m0tty", fontSize: 20, bg: { 0.1176f, 0.117f, 0.1803f }, fg: { 0.8039f, 0.8392f, 0.9568f })!!;
    defer terminal.free();
    terminal.inputHandler.addInput({ { glfw::KEY_ESCAPE, glfw::PRESS, -1 }, "quit" });
    input::InputButton* quitInput = terminal.inputHandler.getInput("quit")!!;

    double time;
    while (!terminal.window.shouldClose)
    {
        terminal.preRender();
        for (int i = 0; i < terminal.grid.width; i++)
        {
            $typeof(terminal.cursor)* cursor = &terminal.cursor;
            cursor.x = rand(terminal.grid.width);
            cursor.y = rand(terminal.grid.height);
            terminal.cursor = *cursor;
            terminal.assignChar((char)rand_in_range(33, 126));
            terminal.assignCharFg(COLORS[rand(COLORS.len)]);
            terminal.assignCharBg(COLORS[rand(COLORS.len)]);
        }
        
        terminal.render()!!;

        if (quitInput.activated()) terminal.window.shouldClose = true;
    }

	return 0;
}
