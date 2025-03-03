module input;
import window;
import glfw;
import std::core::mem;
import std::collections;

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
fn bool InputButton.activated(InputButton* input)
{
    return input.currentState == input.state;
}

struct InputHandler
{
    List{InputButton} inputs;
}

fn InputHandler* createHandler(InputButton[] inputs)
{
    InputHandler* handler = mem::new(InputHandler);
    handler.inputs.init_wrapping_array(mem, inputs);
    return handler;
}
fn void InputHandler.free(InputHandler* handler)
{
    handler.inputs.free();
    mem::free(handler);
}
fn void InputHandler.addInput(InputHandler* handler, InputButton input)
{
    handler.inputs.push(input);
}
fn InputButton*! InputHandler.getInput(InputHandler* handler, String name)
{
    foreach (&input : handler.inputs)
    {
        if (input.name == name) return input;
    }
    return InputHandlerError.INPUT_NAME_NOT_FOUND?;
}
fn void InputHandler.processInput(InputHandler* handler, window::Window* window)
{
    foreach (&input : handler.inputs)
    {
        input.currentState = glfw::getKey(window.glfwWin, input.key);
    }
}
