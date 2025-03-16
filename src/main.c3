module main;

import terminal;
import pty;
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
    { 0xf5, 0xe0, 0xdc },
    { 0xf2, 0xcd, 0xcd },
    { 0xf5, 0xc2, 0xe7 },
    { 0xcb, 0xa6, 0xf7 },
    { 0xf3, 0x8b, 0xa8 },
    { 0xeb, 0xa0, 0xac },
    { 0xfa, 0xb3, 0x87 },
    { 0xf9, 0xe2, 0xaf },
    { 0xa6, 0xe3, 0xa1 },
    { 0x94, 0xe2, 0xd5 },
    { 0x89, 0xdc, 0xeb },
    { 0x74, 0xc7, 0xec },
    { 0x89, 0xb4, 0xfa },
    { 0xb4, 0xbe, 0xfe },
    { 0xcd, 0xd6, 0xf4 },
    { 0xba, 0xc2, 0xde },
    { 0xa6, 0xad, 0xc8 },
    { 0x93, 0x99, 0xb2 },
    { 0x7f, 0x84, 0x9c },
    { 0x6c, 0x70, 0x86 },
    { 0x58, 0x5b, 0x70 },
    { 0x45, 0x47, 0x5a },
    { 0x31, 0x32, 0x44 },
    { 0x1e, 0x1e, 0x2e },
    { 0x18, 0x18, 0x25 },
    { 0x11, 0x11, 0x1b },
};

fn int main(String[] args)
{
    terminal.init(900, 600, "test.ttf", window_name: "m0tty", font_size: 20, bg: { 0x1e, 0x1e, 0x2e }, fg: { 0xcd, 0xd6, 0xf4 })!!;
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

    input_manager.add_map("default", map);

    while (!terminal.window.shouldClose)
    {
        if (catch excuse = terminal.pre_render())
        {
            break;
        }
        if (catch excuse = terminal.render())
        {
            break;
        }
    }

    return 0;
}

fn void paste_clipboard()
{
    ZString clipboard = glfw::getClipboardString(null);
    if (clipboard == null) return;
    uint[] clipboard_string = mem::temp_array(uint, clipboard.len() + (terminal.settings.bracketedPaste ? 6+6 : 0));
    if (catch excuse = conv::utf8to32(clipboard.str_view(), clipboard_string[(terminal.settings.bracketedPaste ? 6 : 0)..]))
    {
        io::printfn("could not convert string to utf32: %s", excuse);
        return;
    }
    usz clipboard_len = get_len(clipboard_string);
    if (terminal.settings.bracketedPaste)
    {
        set_bracketed_paste(clipboard_string, clipboard_len);
        clipboard_len += (terminal.settings.bracketedPaste ? 6+6 : 0);
    }
    foreach (callback : input_manager.keyPressCallbacks) callback(clipboard_string[:clipboard_len]);
}
macro usz get_len(uint[] arr)
{
    for (usz result = 0; result < arr.len; result++) if (arr[result] == 0) return result;
    return arr.len;
}
macro set_bracketed_paste(uint[] arr, usz len)
{
    const char[] START = "\e[200~";
    const char[] END   = "\e[201~";
    for (int i = 0; i < 6; i++)
    {
        arr[i] = START[i];
    }
    for (int i = 0; i < 6; i++)
    {
        arr[i + len] = END[i];
    }
}
