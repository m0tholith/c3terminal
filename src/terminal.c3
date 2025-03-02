module terminal;

import glyph;
import renderer;
import window;
import input;

import std::core::mem;

struct Cursor @local
{
    uint x;
    uint y;
}
struct Grid @local
{
    char[] str;
    uint width; uint height;
    float fontSize;
}
struct Terminal
{
    window::Window* window;
    input::InputHandler* inputHandler;
    glyph::FontAtlas* fontAtlas;
    Cursor cursor;
    Grid grid;
    struct bg { float r; float g; float b; }
    struct fg { float r; float g; float b; }
}

<*
 Initializes the following:
 - Window system
 - Window
 - Input system
 - Font atlas
 - Grid of characters
 *>
fn Terminal*! create(int windowWidth, int windowHeight, ZString windowName = "terminal", String fontName, float fontSize = 20.0f, usz gridSize = 32400, float bgR = 0, float bgG = 0, float bgB = 0, float fgR = 0, float fgG = 0, float fgB = 0)
{
    window::initSystem();
    window::Window* window = window::create(windowWidth, windowHeight, windowName)!;
    defer catch { window::terminateSystem(); }

    input::InputHandler* inputHandler = input::createHandler({});
    defer catch { inputHandler.free(); }
    
    glyph::FontAtlas* atlas = glyph::createFontAtlas(fontName, fontSize)!;
    defer catch { atlas.free(); }

    Grid grid = { mem::new_array(char, gridSize),
                  (uint)((float)windowWidth  / atlas.charMaxX),
                  (uint)((float)windowHeight / atlas.charMaxY),
                  fontSize };
    defer catch { grid.free(); }
    for (usz i = 0; i < gridSize; i++) grid.str[i] = ' ';

    Terminal* result = mem::new(Terminal, { window, inputHandler, atlas, {0,0}, grid, {bgR,bgG,bgB}, {fgR,fgG,fgB} });
    return result;
}
fn void Cursor.set(Cursor* self, uint x, uint y)
{
    self.x = x;
    self.y = y;
}
fn void Cursor.add(Cursor* self, long x, long y)
{
    self.x = (uint)((long)self.x + x);
    self.y = (uint)((long)self.y + y);
}
<*
 Assigns character to terminal's current cursor position
 *>
fn void Terminal.assignChar(Terminal* self, char codepoint)
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
    self.fontAtlas.renderGrid(self.grid.str.ptr, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize)!;

    self.window.clearColor(0.1176, 0.1176, 0.1803);
    self.window.refresh();
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
