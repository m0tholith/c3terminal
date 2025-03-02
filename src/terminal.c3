module terminal;

import glyph;
import renderer;
import window;
import input;

import std::core::mem;

struct Grid @local
{
    uint[] str;
    usz width; usz height;
}
struct Terminal
{
    window::Window* window;
    input::InputHandler* inputHandler;
    glyph::FontAtlas* fontAtlas;
    struct cursor
    {
        uint x;
        uint y;
    }
    Grid grid;
}

<*
 Initializes the following:
 - Window system
 - Window
 - Input system
 - Font atlas
 - Grid of characters
 *>
fn Terminal*! create(int windowWidth, int windowHeight, ZString windowName = "terminal", String fontName, float fontSize = 20.0f, usz gridSize = 32400)
{
    window::initSystem();
    window::Window* window = window::create(windowWidth, windowHeight, windowName)!;
    defer catch { window::terminateSystem(); }

    input::InputHandler* inputHandler = input::createHandler({});
    defer catch { inputHandler.free(); }
    
    glyph::FontAtlas* atlas = glyph::createFontAtlas(fontName, fontSize)!;
    defer catch { atlas.free(); }

    Grid grid = { mem::new_array(uint, gridSize),
                  (usz)((float)windowWidth / atlas.charMaxX),
                  (usz)((float)windowHeight / atlas.charMaxY) };
    defer catch { grid.free(); }
    foreach (&c : grid.str) *c = ' ';

    Terminal* result = mem::new(Terminal, { window, inputHandler, atlas, {0,0}, grid });
    return result;
}
fn void Terminal.cursorSet(Terminal* self, uint x, uint y)
{
    self.cursor.x = x;
    self.cursor.y = y;
}
fn void Terminal.cursorAdd(Terminal* self, long x, long y)
{
    self.cursor.x = (uint)((long)self.cursor.x + x);
    self.cursor.y = (uint)((long)self.cursor.y + y);
}
<*
 Assigns character to terminal's current cursor position
 *>
fn void Terminal.assignChar(Terminal* self, uint codepoint)
{
    self.grid.str[self.cursor.x + self.grid.width * self.cursor.y] = codepoint;
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
