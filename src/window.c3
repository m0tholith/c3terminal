module window;
import std::io;
import std::core::mem;
import std::collections::list;

import glfw;
import opengl;

fault WindowError
{
    WINDOW_FAILED_INIT,
}

struct Window
{
    glfw::Window* glfwWin;
    bool shouldClose;
    uint width;
    uint height;
}
List(<Window*>) windows @local;

fn void initSystem()
{
    glfw::initHint(0x00050003, 0x00060004);
    glfw::init();
    windows.new_init();
}
fn void terminateSystem()
{
    glfw::terminate();
    foreach (window : windows)
    {
        window.free();
    }
    windows.free();
}

fn Window*! create(int width, int height, ZString name)
{
    glfw::windowHint(glfw::CONTEXT_VERSION_MAJOR, 4);
    glfw::windowHint(glfw::CONTEXT_VERSION_MINOR, 6);
    glfw::windowHint(glfw::OPENGL_PROFILE, glfw::OPENGL_CORE_PROFILE);
    glfw::windowHint(glfw::OPENGL_FORWARD_COMPAT, 1);
    glfw::windowHint(glfw::RESIZABLE, 1);
    glfw::Window* glfwWin = glfw::createWindow(width, height, name, null, null);
    if (glfwWin == null)
    {
        io::eprintf("could not initialize glfw window");
        glfw::terminate();
        return WindowError.WINDOW_FAILED_INIT?;
    }
    glfw::setWindowSizeCallback(glfwWin, &windowSizeCallback);
    glfw::makeContextCurrent(glfwWin);
    glfw::windowHint(glfw::SAMPLES, 2);
    gl::viewport(0, 0, width, height);
    gl::enable(gl::GL_MULTISAMPLE);

    Window* window = mem::new(Window);
    window.glfwWin = glfwWin;
    window.width = width;
    window.height = height;

    windows.push(window);

    return window;
}
<*
 @require window != null : "window is null"
 *>
fn void Window.free(Window* window)
{
    glfw::destroyWindow(window.glfwWin);
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
    glfw::makeContextCurrent(window.glfwWin);

    glfw::swapBuffers(window.glfwWin);
    glfw::pollEvents();

    gl::clear(gl::GL_COLOR_BUFFER_BIT);

    if (glfw::windowShouldClose(window.glfwWin) != (int)window.shouldClose)
    {
        glfw::setWindowShouldClose(window.glfwWin, (int)window.shouldClose);
    }
    gl::viewport(0, 0, window.width, window.height);
}

fn void windowSizeCallback(glfw::Window* glfwWin, int width, int height)
{
    foreach (window : windows)
    {
        if (window.glfwWin == glfwWin)
        {
            window.width = width;
            window.height = height;
        }
    }
}
