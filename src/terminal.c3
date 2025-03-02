module terminal;

import glfw;
import opengl;
import glyph;
import renderer;
import window;
import input;

import std::core::mem;
import std::thread;
import std::io;

struct Grid @local
{
    uint[] str;
    uint width; uint height;
    float fontSize;
}
struct Terminal
{
    window::Window* window;
    input::InputHandler* inputHandler;
    glyph::FontAtlas* fontAtlas;
    uint[<2>] cursor;
    Grid grid;
    float[<3>] bg;
    float[<3>] fg;
    // default value of 0 means as much as refresh rate
    double fps;
    double time;
}

<*
 Initializes the following:
 - Window system
 - Window
 - Input system
 - Font atlas
 - Grid of characters

 @require fps >= 0
 *>
fn Terminal*! create(int windowWidth, int windowHeight, String fontName, ZString windowName = "terminal", float fontSize = 20.0f, usz gridSize = 32400, float[<3>] bg = {0,0,0}, float[<3>] fg = {1,1,1}, double fps = 0)
{
    window::initSystem();
    window::Window* window = window::create(windowWidth, windowHeight, windowName)!;
    defer catch { window::terminateSystem(); }

    input::InputHandler* inputHandler = input::createHandler({});
    defer catch { inputHandler.free(); }
    
    glyph::FontAtlas* atlas = glyph::createFontAtlas(fontName, fontSize)!;
    defer catch { atlas.free(); }

    Grid grid = { mem::new_array(uint, gridSize),
                  (uint)((float)windowWidth  / atlas.charMaxX),
                  (uint)((float)windowHeight / atlas.charMaxY),
                  fontSize };
    defer catch { grid.free(); }
    for (usz i = 0; i < gridSize; i++) grid.str[i] = ' ';

    Terminal* result = mem::new(Terminal, { window, inputHandler, atlas, {0,0}, grid, bg, fg, fps == 0 ? 0 : 1.0/fps, 0 });
    return result;
}
<*
 Assigns character to terminal's current cursor position
 *>
fn void Terminal.assignChar(Terminal* self, uint codepoint)
{
    self.grid.str[self.cursor.x + self.grid.width * self.cursor.y] = codepoint;
}
fn void Terminal.preRender(Terminal* self)
{
    if (self.window.sizeChanged)
    {
        for (int i = 0; i < self.grid.width; i++)
        {
            for (int j = 0; j < self.grid.height; j++)
            {
                self.grid.str[i + self.grid.width * j] = ' ';
            }
        }
        self.grid.width  = (uint)((float)self.window.width  / self.fontAtlas.charMaxX);
        self.grid.height = (uint)((float)self.window.height / self.fontAtlas.charMaxY);
    }
    self.inputHandler.processInput(self.window);
}
fn void! Terminal.render(Terminal* self)
{
    gl::uniform3f(self.fontAtlas.renderer.uniformBg, self.bg.x, self.bg.y, self.bg.z);
    gl::uniform3f(self.fontAtlas.renderer.uniformFg, self.fg.x, self.fg.y, self.fg.z);
    self.fontAtlas.renderGrid(self.grid.str.ptr, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize)!;

    GLenum err = gl::getError();
    while (err != 0)
    {
        io::eprintfn("GL error 0x%08X", err);
        err = gl::getError();
    }

    self.window.clearColor(self.bg.r, self.bg.g, self.bg.b);
    self.window.refresh();

    double newTime = glfw::getTime();
    double dt = newTime - self.time;
    if (dt < self.fps) thread::sleep_ms((ulong)((self.fps - dt) * 1000));
    self.time = newTime;
}
fn void Grid.free(Grid* self) @local
{
    mem::free(self.str);
}
fn void Terminal.free(Terminal* self)
{
    self.grid.free();
    self.fontAtlas.free();
    self.inputHandler.free();
    window::terminateSystem();
    mem::free(self);
}
