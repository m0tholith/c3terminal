module terminal;

import glfw;
import opengl;
import glyph;
import window;
import input;

import std::core::mem;
import std::thread;
import std::io;

struct Grid @local
{
    font_atlas::GridChar[] str;
    uint width; uint height;
    float fontSize;
}
struct Terminal
{
    window::Window window;
    input::InputHandler inputHandler;
    font_atlas::FontAtlas fontAtlas;
    uint[<2>] cursor;
    Grid grid;
    float[<3>] bg;
    float[<3>] fg;
    // default value of 0 means as much as refresh rate
    double time;
}

<*
 Initializes the following:
 - Window system
 - Window
 - Input system
 - Font atlas
 - Grid of characters
 *>
fn void! Terminal.init(&self, int windowWidth = 0, int windowHeight = 0, String fontName, ZString windowName = "terminal", float fontSize = 20.0f, usz gridSize = 32400, float[<3>] bg = {0,0,0}, float[<3>] fg = {1,1,1})
{
    window::initSystem();
    window::Window window;
    window.init(windowWidth, windowHeight, windowName)!;
    defer catch { window::terminateSystem(); }

    gl::enable(gl::GL_DEBUG_OUTPUT);
    gl::debugMessageCallback(&debugMessageCallback, null);

    input::InputHandler inputHandler;
    inputHandler.init({});
    defer catch { inputHandler.free(); }
    
    font_atlas::FontAtlas atlas;
    atlas.init(fontName, fontSize)!;
    defer catch { atlas.free(); }

    Grid grid = { mem::new_array(font_atlas::GridChar, gridSize),
                  (uint)((float)windowWidth  / atlas.charMaxX),
                  (uint)((float)windowHeight / atlas.charMaxY),
                  fontSize };
    defer catch { grid.free(); }
    for (usz i = 0; i < gridSize; i++) grid.str[i] = { ' ', fg };

    self.window = window;
    self.inputHandler = inputHandler;
    self.fontAtlas = atlas;
    self.grid = grid;
    self.bg = bg;
    self.fg = fg;
}
<*
 Assigns character to terminal's current cursor position

 @require self.grid.str.ptr != null
 *>
fn void Terminal.assignChar(&self, uint codepoint)
{
    self.grid.str[self.cursor.x + self.grid.width * self.cursor.y].codepoint = codepoint;
}
<*
 Assigns background color to terminal's current cursor position

 @require self.grid.str.ptr != null
 *>
fn void Terminal.assignCharBg(&self, float[<3>] bg) @deprecated
{
    // self.grid.str[self.cursor.x + self.grid.width * self.cursor.y].bg = bg;
}
<*
 Assigns foreground color to terminal's current cursor position

 @require self.grid.str.ptr != null
 *>
fn void Terminal.assignCharFg(&self, float[<3>] fg)
{
    self.grid.str[self.cursor.x + self.grid.width * self.cursor.y].color = fg;
}
fn void Terminal.preRender(&self)
{
    if (self.window.sizeChanged)
    {
        for (int i = 0; i < self.grid.width; i++)
        {
            for (int j = 0; j < self.grid.height; j++)
            {
                self.grid.str[i + self.grid.width * j].codepoint = ' ';
            }
        }
        self.grid.width  = (uint)((float)self.window.width  / self.fontAtlas.charMaxX);
        self.grid.height = (uint)((float)self.window.height / self.fontAtlas.charMaxY);
    }
    self.inputHandler.processInput(&self.window);
}
fn void! Terminal.render(&self)
{
    self.fontAtlas.renderGrid(self.grid.str, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize)!;

    self.window.clearColor(self.bg.r, self.bg.g, self.bg.b);
    self.window.refresh();

    self.time = glfw::getTime();
}
fn void Grid.free(self) @local
{
    mem::free(self.str);
}
fn void Terminal.free(&self)
{
    self.grid.free();
    self.fontAtlas.free();
    self.inputHandler.free();
    window::terminateSystem();
}

fn void debugMessageCallback(GLenum source,
                             GLenum type,
                             uint id,
                             GLenum severity,
                             usz length,
                             ZString message,
                             void* userParam) @private
{
    io::eprintfn("GL CALLBACK: type = 0x%x, severity = 0x%x, message = %s\n", type, severity, message);
}
