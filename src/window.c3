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
    bool sizeChanged; // toggles at the frame when the
                      // size was changed, and then resets
    uint width;
    uint height;
}
List{Window*} windows @local;

fn void init_system()
{
    glfw::initHint(0x00050003, 0x00060004);
    glfw::init();
    windows.init(mem);
}
fn void terminate_system()
{
    glfw::terminate();
    foreach (window : windows)
    {
        window.free();
    }
    windows.free();
}

<*
 @param [&in] name
 @require self.glfwWin == null
 @require name != null
 *>
fn void! Window.init(&self, int width = 0, int height = 0, ZString name)
{
    Monitor* monitor = null;
    if (width == 0 || height == 0) monitor = glfw::getPrimaryMonitor();
    glfw::windowHint(glfw::CONTEXT_VERSION_MAJOR, 4);
    glfw::windowHint(glfw::CONTEXT_VERSION_MINOR, 6);
    glfw::windowHint(glfw::OPENGL_PROFILE, glfw::OPENGL_CORE_PROFILE);
    glfw::windowHint(glfw::OPENGL_FORWARD_COMPAT, 1);
    glfw::Window* glfw_win = glfw::createWindow(width, height, name, monitor, null);
    if (glfw_win == null)
    {
        io::eprintf("could not initialize glfw window");
        glfw::terminate();
        return WindowError.WINDOW_FAILED_INIT?;
    }
    glfw::setWindowSizeCallback(glfw_win, &window_size_callback);
    glfw::makeContextCurrent(glfw_win);
    glfw::swapInterval(0);
    glfw::windowHint(glfw::RESIZABLE, 1);
    glfw::windowHint(glfw::SAMPLES, 2);
    gl::viewport(0, 0, width, height);
    gl::enable(gl::GL_MULTISAMPLE);
    gl::enable(gl::GL_BLEND);
    gl::blendFunc(gl::GL_SRC_ALPHA, gl::GL_ONE_MINUS_SRC_ALPHA);
    glfw::setInputMode(glfw_win, glfw::LOCK_KEY_MODS, glfw::TRUE);

    self.glfwWin = glfw_win;
    self.width = width;
    self.height = height;

    windows.push(self);
}
<*
 @require self.glfwWin != null
 *>
fn void Window.free(&self) @local
{
    glfw::destroyWindow(self.glfwWin);
}

fn void Window.clear_color(&self, float red, float green, float blue)
{
    gl::clearColor(red, green, blue, 1.0f);
}
<*
 @require self.glfwWin != null
 *>
fn void Window.refresh(&self)
{
    update_time();

    self.sizeChanged = false;

    glfw::makeContextCurrent(self.glfwWin);

    glfw::swapBuffers(self.glfwWin);
    glfw::pollEvents();

    gl::clear(gl::GL_COLOR_BUFFER_BIT);

    if (glfw::windowShouldClose(self.glfwWin) != (int)self.shouldClose)
    {
        glfw::setWindowShouldClose(self.glfwWin, (int)self.shouldClose);
    }
    gl::viewport(0, 0, self.width, self.height);
}

fn void window_size_callback(glfw::Window* glfw_win, int width, int height) @private
{
    foreach (window : windows)
    {
        if (window.glfwWin == glfw_win)
        {
            window.width = width;
            window.height = height;

            window.sizeChanged = true;
            break;
        }
    }
}

double time;
fn void update_time() @inline => time = glfw::getTime();
