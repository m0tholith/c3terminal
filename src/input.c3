module input;

import std::core::mem;
import std::collections::list;
import std::collections::map;
import std::io;

import window;
import glfw;

fault InputError
{
    BUTTON_NAME_NOT_FOUND,
    MAP_NAME_NOT_FOUND,
}

struct Key
{
    int keycode; // key from glfw (e.g. KEY_ESCAPE)
    int modifiers; // modifier from glfw (e.g. MOD_LEFT_ALT), can be more than one but has to be exact
    int state; // status from glfw (e.g. PRESS), can be more than one but enables when any one of them
}
const INPUT_MODIFIERS @private = glfw::MOD_SHIFT | glfw::MOD_CONTROL | glfw::MOD_ALT | glfw::MOD_SUPER | glfw::MOD_CAPS_LOCK | glfw::MOD_NUM_LOCK;
fn bool Key.compare(self, int keycode, int modifiers, int state)
{
    return self.keycode == keycode && !(self.modifiers ^ modifiers) && self.state & state;
}
def ButtonCallback = fn void();
struct Button (Printable)
{
    inline Key key;
    String name;
    ButtonCallback callback;
}
fn String Button.to_constant_string(&self) @dynamic
{
    DString builder;
    builder.appendf("{ {%d,%d,%d}, \"%s\" }", self.keycode, self.modifiers, self.state, self.name);
    return builder.str_view();
}

struct Map
{
    inline List{Button} buttons;
}
fn void Map.init(&self, Button[] buttons)
{
    if (self.is_initialized()) return;
    self.buttons.init(mem);
    foreach (button : buttons)
    {
        self.add_input(button);
    }
}
fn void Map.free(&self)
{
    self.buttons.free();
}
fn void Map.add_input(&self, Button button)
{
    if (!self.buttons.is_initialized()) self.init({});
    self.buttons.push(button);
}
<*
 @require self.buttons.is_initialized()
 *>
fn Button*! Map.find(&self, String name)
{
    foreach (&button : self.buttons)
    {
        if (button.name == name) return button;
    }
    return InputError.BUTTON_NAME_NOT_FOUND?;
}

def KeyPressCallback = fn void(Char32[] codepoints, int mods = 0);
struct Manager
{
    HashMap{String, Map} maps;
    String currentMap;
    List{KeyPressCallback} keyPressCallbacks;
}
Manager input_manager @public @builtin;
<*
 @param [&in] window
 *>
fn void Manager.init(&self, window::Window* window)
{
    self.maps.init(mem);
    self.keyPressCallbacks.init(mem);

    glfw::setKeyCallback(window.glfwWin, &key_callback);
    glfw::setCharCallback(window.glfwWin, &char_callback);
}
fn bool Manager.is_initialized(&self) @inline => self.maps.is_initialized() && self.keyPressCallbacks.is_initialized();
<*
 @require map_name.len != 0
 *>
fn void Manager.add_map(&self, String map_name, Map map, bool activate = true)
{
    if (!self.maps.is_initialized()) self.maps.init(mem);
    self.maps[map_name] = map;
    if (activate) self.currentMap = map_name;
}
fn void Manager.add_key_press_callback(&self, KeyPressCallback callback)
{
    if (!self.keyPressCallbacks.is_initialized()) self.keyPressCallbacks.init(mem);
    self.keyPressCallbacks.push(callback);
}
<*
 @require map_name.len != 0
 *>
fn void! Manager.activate_map(&self, String map_name)
{
    if (!self.maps.is_initialized())
    {
        self.maps.init(mem);
        return InputError.MAP_NAME_NOT_FOUND?;
    }
    if (catch excuse = self.maps[map_name]) return InputError.MAP_NAME_NOT_FOUND?;
    self.currentMap = map_name;
}
fn void Manager.free(&self)
{
    self.maps.@each(; String map_name, Map map)
    {
        self.maps.get_ref(map_name).free()!!;
    };
    self.maps.free();
    self.keyPressCallbacks.free();
}

module input @private;

import glfw;

import std::io;
import std::collections::range;
import std::ascii;

macro @run_callbacks(#codepoint, mods = 0)
{
    $if $typeof(#codepoint).typeid == uint.typeid:
        foreach (callback : input_manager.keyPressCallbacks) callback({ #codepoint }, mods);
    $else
        $if $typeof(#codepoint).typeid == char.typeid:
            foreach (callback : input_manager.keyPressCallbacks) callback({ (char)#codepoint }, mods);
        $else
            foreach (callback : input_manager.keyPressCallbacks) callback(#codepoint, mods);
        $endif
    $endif
}

<*
 @param [&in] window
 @require input_manager.is_initialized()
 *>
fn void key_callback(glfw::Window* window, int key, int scancode, int action, int mods)
{
    if (try map = input_manager.maps[input_manager.currentMap])
    {
        foreach (button : map.buttons)
        {
            if (button.compare(key, mods, action))
            {
                button.callback();
                break;
            }
        }
    }
    if (action == glfw::RELEASE) return;
    uint codepoint = key;
    mods &= ~glfw::MOD_CAPS_LOCK & ~glfw::MOD_NUM_LOCK;
    switch (key)
    {
        case glfw::KEY_ESCAPE:
            @run_callbacks('\e', 0);
            return;
        case glfw::KEY_ENTER:
            @run_callbacks('\n', 0);
            return;
        case glfw::KEY_TAB:
            @run_callbacks('\t', 0);
            return;
        case glfw::KEY_BACKSPACE:
            @run_callbacks('\b', 0);
            return;
        case glfw::KEY_DELETE:
            @run_callbacks(0x7F, 0);
            return;
        case glfw::KEY_RIGHT:
            @run_callbacks((uint[]){ '\e', '[', 'C' }, mods);
            return;
        case glfw::KEY_LEFT:
            @run_callbacks((uint[]){ '\e', '[', 'D' }, mods);
            return;
        case glfw::KEY_DOWN:
            @run_callbacks((uint[]){ '\e', '[', 'B' }, mods);
            return;
        case glfw::KEY_UP:
            @run_callbacks((uint[]){ '\e', '[', 'A' }, mods);
            return;
        case glfw::KEY_LEFT_BRACKET:
            switch (mods)
            {
                case glfw::MOD_ALT:
                    @run_callbacks((uint[]){ '\e', '[' }, 0);
                    return;
                case glfw::MOD_CONTROL:
                    @run_callbacks('\e', 0);
                    return;
            }
    }
    if (' ' <= key && key <= '~') if (mods == 0 || mods == glfw::MOD_SHIFT) return;
    // means only modifier keypresses
    if (key >= glfw::KEY_LEFT_SHIFT) return;

    @run_callbacks(codepoint, mods);
}
fn void char_callback(glfw::Window* window, uint codepoint)
{
    @run_callbacks(codepoint);
}
