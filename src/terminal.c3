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
    font_atlas::GridCharFg[] fg;
    font_atlas::GridCharBg[] bg;
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
    self.window.init(windowWidth, windowHeight, windowName)!;
    defer catch { window::terminateSystem(); }

    gl::enable(gl::GL_DEBUG_OUTPUT);
    gl::debugMessageCallback(&debugMessageCallback, null);

    self.inputHandler.init({});
    defer catch { self.inputHandler.free(); }
    
    self.fontAtlas.init(fontName, fontSize)!;
    defer catch { self.fontAtlas.free(); }

    self.grid = { mem::new_array(font_atlas::GridCharFg, gridSize),
                  mem::new_array(font_atlas::GridCharBg, gridSize),
                  (uint)((float)windowWidth  / self.fontAtlas.charMaxX),
                  (uint)((float)windowHeight / self.fontAtlas.charMaxY),
                  fontSize };
    defer catch { self.grid.free(); }
    for (usz i = 0; i < gridSize; i++)
    {
        self.grid.fg[i] = { ' ', fg };
        self.grid.bg[i].color = self.bg;
    }

    self.bg = bg;
    self.fg = fg;
}
<*
 Assigns character to terminal's current cursor position

 @require self.grid.fg.ptr != null
 *>
fn void Terminal.assignChar(&self, uint codepoint)
{
    self.grid.fg[self.cursor.x + self.grid.width * self.cursor.y].codepoint = codepoint;
}
<*
 Assigns background color to terminal's current cursor position

 @require self.grid.bg.ptr != null
 *>
fn void Terminal.assignCharBg(&self, float[<3>] bg)
{
    self.grid.bg[self.cursor.x + self.grid.width * self.cursor.y].color = bg;
}
<*
 Assigns foreground color to terminal's current cursor position

 @require self.grid.fg.ptr != null
 *>
fn void Terminal.assignCharFg(&self, float[<3>] fg)
{
    self.grid.fg[self.cursor.x + self.grid.width * self.cursor.y].color = fg;
}
fn void Terminal.preRender(&self)
{
    if (self.window.sizeChanged)
    {
        for (int i = 0; i < self.grid.width; i++)
        {
            for (int j = 0; j < self.grid.height; j++)
            {
                self.grid.fg[i + self.grid.width * j] = { ' ', self.fg };
                self.grid.bg[i + self.grid.width * j].color = self.bg;
            }
        }
        self.grid.width  = (uint)((float)self.window.width  / self.fontAtlas.charMaxX);
        self.grid.height = (uint)((float)self.window.height / self.fontAtlas.charMaxY);
    }
    self.inputHandler.processInput(&self.window);
}
fn void! Terminal.render(&self)
{
    self.fontAtlas.renderGridBg(self.grid.bg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize)!;
    self.fontAtlas.renderGridFg(self.grid.fg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize)!;

    self.window.clearColor(self.bg.r, self.bg.g, self.bg.b);
    self.window.refresh();

    self.time = glfw::getTime();
}
fn void Grid.free(self) @local
{
    mem::free(self.bg);
    mem::free(self.fg);
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
