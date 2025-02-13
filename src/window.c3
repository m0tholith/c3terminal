module window;
import std::io;
import std::core::mem;
import glfw;
import opengl;
const GL_VERSION = 33;

fault WindowError
{
    WINDOW_FAILED_INIT,
}

struct Window
{
    glfw::Window* glfwWin;
    bool shouldClose;
}

fn void initSystem()
{
    glfw::init();
}
fn void terminateSystem()
{
    glfw::terminate();
}

fn Window*! create(int width, int height, ZString name)
{
    glfw::windowHint(glfw::RESIZABLE, 0);
    glfw::Window* glfwWin = glfw::createWindow(width, height, name, null, null);
    if (glfwWin == null)
    {
        io::eprintf("could not initialize glfw window");
        glfw::terminate();
        return WindowError.WINDOW_FAILED_INIT?;
    }
    glfw::makeContextCurrent(glfwWin);
    gl::viewport(0, 0, width, height);

    Window* window = mem::new(Window);
    window.glfwWin = glfwWin;

    return window;
}
<*
 @require window != null : "window is null"
 *>
fn void Window.free(Window* window)
{
    mem::free(window);
}

<*
 @require window != null : "window is null"
 *>
fn void Window.clearColor(Window* window, float red, float green, float blue)
{
    gl::clearColor(red, green, blue, 1.0f);
}
<*
 @require window != null : "window is null"
 *>
fn void Window.refresh(Window* window)
{
    glfw::swapBuffers(window.glfwWin);
    glfw::pollEvents();

    gl::clear(gl::GL_COLOR_BUFFER_BIT);

    glfw::setWindowShouldClose(window, (int)window.shouldClose);
}
