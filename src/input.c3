module input;

import std::core::mem;
import std::collections;
import std::io;

import window;
import glfw;

fault InputHandlerError
{
    INPUT_NAME_NOT_FOUND,
}

struct InputKey
{
    int keycode; // key from glfw (e.g. KEY_ESCAPE)
    int state; // status from glfw (e.g. PRESS)
    int currentState; // the last-reported state of this input
}
struct InputButton
{
    inline InputKey key;
    String name;
}
fn bool InputButton.activated(&self)
{
    return self.currentState == self.state;
}

struct InputHandler
{
    List{InputButton} inputs;
}

fn bool InputHandler.is_initialized(&self) @inline @local => self.inputs.is_initialized();
fn void InputHandler.init(&self, InputButton[] inputs)
{
    if (self.is_initialized()) return;
    self.inputs.init_wrapping_array(mem, inputs);
}
fn void InputHandler.free(&self)
{
    if (!self.is_initialized()) return;
    self.inputs.free();
}
fn void InputHandler.addInput(&self, InputButton input)
{
    if (!self.inputs.is_initialized())
    {
        self.init({input});
    }
    else
    {
        self.inputs.push(input);
    }
}
<*
 @require self.is_initialized()
 *>
fn InputButton*! InputHandler.getInput(&self, String name)
{
    foreach (&input : self.inputs)
    {
        if (input.name == name) return input;
    }
    io::eprintfn("could not find input %s", name);
    return InputHandlerError.INPUT_NAME_NOT_FOUND?;
}
<*
 @param [&in] window
 *>
fn void InputHandler.processInput(&self, window::Window* window)
{
    if (!self.is_initialized()) self.init({});
    foreach (&input : self.inputs)
    {
        input.currentState = glfw::getKey(window.glfwWin, input.keycode);
    }
}
