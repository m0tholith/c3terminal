module input;

import std::core::mem;
import std::collections;
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
    return self.keycode == keycode && (((self.modifiers & modifiers) | (~self.modifiers & ~modifiers)) & INPUT_MODIFIERS) && self.state & state;
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

struct PressedKey
{
    int keycode;
    double pressTime;
}
struct Manager
{
    HashMap{String, Map} maps;
    String currentMap;
    List{PressedKey} pressedKeys; // glfw key ints (e.g. KEY_A)
}
Manager input_manager @public @builtin;
<*
 @param [&in] window
 *>
fn void Manager.init(&self, window::Window* window)
{
    self.maps.init(mem);
    self.pressedKeys.init(mem);

    glfw::setKeyCallback(window.glfwWin, &key_callback);
}
fn bool Manager.is_initialized(&self) @inline => self.maps.is_initialized() && self.pressedKeys.is_initialized();
<*
 @require map_name.len != 0
 *>
fn void Manager.add_map(&self, String map_name, Map map, bool activate = true)
{
    if (!self.maps.is_initialized()) self.maps.init(mem);
    self.maps[map_name] = map;
    if (activate) self.currentMap = map_name;
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
    self.pressedKeys.free();
}
<*
 @param [&in] window
 @require input_manager.is_initialized()
 *>
fn void key_callback(glfw::Window* window, int key, int scancode, int action, int mods) @private
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
    foreach (idx, inputKey : input_manager.pressedKeys)
    {
        if (inputKey.keycode == key)
        {
            switch (action)
            {
                case glfw::PRESS:
                case glfw::REPEAT:
                    break;

                case glfw::RELEASE:
                default:
                    input_manager.pressedKeys.remove_at(idx);
            }
            return;
        }
    }
    input_manager.pressedKeys.push({ key, glfw::getTime() });
}
