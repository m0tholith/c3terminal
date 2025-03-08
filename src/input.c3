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

struct InputButton
{
    String name;
    int key; // key from glfw (e.g. KEY_ESCAPE)
    int state; // status from glfw (e.g. PRESS)
    int currentState; // the last-reported state of this input
}
fn bool InputButton.activated(&self)
{
    return self.currentState == self.state;
}

struct InputHandler
{
    List{InputButton} inputs;
}

fn void InputHandler.init(&self, InputButton[] inputs)
{
    self.inputs.init_wrapping_array(mem, inputs);
}
fn void InputHandler.free(self)
{
    self.inputs.free();
}
fn void InputHandler.addInput(&self, InputButton input)
{
    self.inputs.push(input);
}
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
    foreach (&input : self.inputs)
    {
        input.currentState = glfw::getKey(window.glfwWin, input.key);
    }
}
