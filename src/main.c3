module main;

import terminal;
import input;
import window;
import glfw;

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

    while (!terminal.window.shouldClose)
    {
        terminal.preRender();

        foreach (key : input_manager.pressedKeys)
        {
            int keycode = translate_keycode(key);
            if (keycode != -1 &&
                (key.pressTime == window::time ||
                window::time - key.pressTime > 1))
            {
                terminal.assignChar(keycode);
                terminal.cursor.x++;
            }
        }

        terminal.assignChar('_');
        
        terminal.render()!!;
    }

	return 0;
}

macro bool check_modifier(input::PressedKey key, int modifier) => key.modifier ^ modifier == 0;
fn int translate_keycode(input::PressedKey key)
{
    if ((Range{int}){ glfw::KEY_0, glfw::KEY_9 }.contains(key.keycode))
    {
        if (check_modifier(key, glfw::MOD_SHIFT))
        {
            switch (key.keycode)
            {
                case glfw::KEY_1: return '!';
                case glfw::KEY_2: return '@';
                case glfw::KEY_3: return '#';
                case glfw::KEY_4: return '$';
                case glfw::KEY_5: return '%';
                case glfw::KEY_6: return '^';
                case glfw::KEY_7: return '&';
                case glfw::KEY_8: return '*';
                case glfw::KEY_9: return '(';
                case glfw::KEY_0: return ')';
            }
        }
        return key.keycode;
    }
    if ((Range{int}){ glfw::KEY_A, glfw::KEY_Z }.contains(key.keycode))
    {
        return key.keycode + (int)!check_modifier(key, glfw::MOD_SHIFT) * 32;
    }
    switch (key.keycode)
    {
        case glfw::KEY_SPACE:      return ' ';
        case glfw::KEY_APOSTROPHE: return check_modifier(key, glfw::MOD_SHIFT) ? '"' : '\'';
        case glfw::KEY_MINUS:      return check_modifier(key, glfw::MOD_SHIFT) ? '_' : '_';
        case glfw::KEY_COMMA:      return check_modifier(key, glfw::MOD_SHIFT) ? '<' : ',';
        case glfw::KEY_PERIOD:     return check_modifier(key, glfw::MOD_SHIFT) ? '>' : '.';
        case glfw::KEY_SLASH:      return check_modifier(key, glfw::MOD_SHIFT) ? '?' : '/';

        case glfw::KEY_SEMICOLON: return check_modifier(key, glfw::MOD_SHIFT) ? ':' : ';';
        case glfw::KEY_EQUAL:     return check_modifier(key, glfw::MOD_SHIFT) ? '=' : '+';

        case glfw::KEY_LEFT_BRACKET:   return check_modifier(key, glfw::MOD_SHIFT) ? '{' : '[';
        case glfw::KEY_BACKSLASH:      return check_modifier(key, glfw::MOD_SHIFT) ? '|' : '\\';
        case glfw::KEY_RIGHT_BRACKET:  return check_modifier(key, glfw::MOD_SHIFT) ? '}' : ']';
        case glfw::KEY_GRAVE_ACCENT:   return check_modifier(key, glfw::MOD_SHIFT) ? '~' : '`';
    }
    return -1;
}
