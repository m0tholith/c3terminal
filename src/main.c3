module terminal;
import window;
import input;
import renderer;
import glfw;

fn int main(String[] args)
{
    window::initSystem();
    defer window::terminateSystem();

    window::Window* window = window::create(800, 600, "m0th")!!;
    defer window.free();

    input::InputHandler* inputHandler = input::createHandler(input::InputButton[] {
        { "quit", glfw::KEY_ESCAPE, glfw::PRESS, -1 }
    });
    defer inputHandler.free();

    input::InputButton* quitInput = inputHandler.getInput("quit")!!;

    renderer::Renderer* renderer = renderer::create();
    defer renderer.free();

    while (!window.shouldClose)
    {
        renderer.render();

        inputHandler.processInput(window);
        if (quitInput.activated()) window.shouldClose = true;

        window.clearColor(0.2f, 0.3f, 0.3f);
        window.refresh();
    }

	return 0;
}
