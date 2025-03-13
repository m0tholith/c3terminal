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
    terminal.init(900, 600, "test.ttf", window_name: "m0tty", font_size: 20, bg: { 0.1176f, 0.117f, 0.1803f }, fg: { 0.8039f, 0.8392f, 0.9568f })!!;
    defer terminal.free();

    input::Map map;
    map.init({
        {
            { glfw::KEY_ESCAPE, glfw::MOD_ALT, glfw::PRESS },
            "quit",
            fn () => (void)(terminal.window.shouldClose = true)
        },
        {
            { glfw::KEY_V, glfw::MOD_CONTROL, glfw::PRESS | glfw::REPEAT },
            "paste",
            &paste_clipboard
        },
    });

    input_manager.init(&terminal.window);
    input_manager.add_map("default", map);
    defer input_manager.free();

    input_manager.add_key_press_callback(&key_press_callback);

    while (!terminal.window.shouldClose)
    {
        terminal.pre_render();

        terminal.assign_char('_');
        
        terminal.render()!!;
    }

    return 0;
}

fn void key_press_callback(uint codepoint, int mods = 0)
{
    io::printfn("codepoint: |'%c'| (mods %d)", codepoint, mods);
    switch (codepoint)
    {
        case '\n':
            terminal.assign_char(' ');
            terminal.cursor.x = 0;
            terminal.cursor.y++;
            return;
        case '\t':
            terminal.assign_char(' ');
            terminal.cursor.x += 4;
            return;
        case '\b':
            terminal.assign_char(' ');
            if (terminal.cursor.x > 0) terminal.cursor.x--;
            return;
        case '\e':
            return;
    }
    terminal.assign_char(codepoint);
    terminal.cursor.x++;
}
fn void paste_clipboard()
{
    ZString clipboard = glfw::getClipboardString(null);
    io::printfn("got string from clipboard: %s", clipboard);
    if (clipboard == null) return;
    uint[] clipboard_string = mem::temp_array(uint, clipboard.len());
    if (catch excuse = conv::utf8to32(clipboard.str_view(), clipboard_string))
    {
        io::printfn("could not convert string to utf32: %s", excuse);
        return;
    }
    usz clipboard_len = get_len(clipboard_string);
    io::printfn("converted string to utf32: %s", clipboard_string);
    for (int i = 0; i < clipboard_len; i++)
    {
        uint codepoint = clipboard_string[i];
        foreach (callback : input_manager.keyPressCallbacks) callback(codepoint);
    }
}
macro usz get_len(uint[] arr)
{
    for (usz result = 0; result < arr.len; result++) if (arr[result] == 0) return result;
    return arr.len;
}
