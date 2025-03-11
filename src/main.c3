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
import std::collections::range;

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

terminal::Terminal terminal;
fn int main(String[] args)
{
    terminal.init(900, 600, "test.ttf", windowName: "m0tty", fontSize: 20, bg: { 0.1176f, 0.117f, 0.1803f }, fg: { 0.8039f, 0.8392f, 0.9568f })!!;
    defer terminal.free();

    input::Map map;
    map.init({
        (input::Button){
            { glfw::KEY_ESCAPE, glfw::MOD_ALT, glfw::PRESS },
            "quit",
            fn () => (void)(terminal.window.shouldClose = true)
        }
    });

    input_manager.init(&terminal.window);
    input_manager.add_map("default", map);
    defer input_manager.free();

    double time;
    while (!terminal.window.shouldClose)
    {
        terminal.preRender();

        foreach (key : input_manager.pressedKeys)
        {
            if (((Range{int}){glfw::KEY_0, glfw::KEY_9}.contains(key.keycode) ||
                (Range{int}){glfw::KEY_A, glfw::KEY_Z}.contains(key.keycode)) &&
                (key.pressTime == glfw::getTime() ||
                glfw::getTime() - key.pressTime > 1))
            {
                terminal.assignChar(key.keycode);
                terminal.cursor.x++;
            }
        }
        terminal.assignCharFg(COLORS[rand(COLORS.len)]);
        terminal.assignCharBg(COLORS[rand(COLORS.len)]);
        
        terminal.render()!!;
    }

	return 0;
}
