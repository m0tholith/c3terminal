module terminal;

import glyph;
import renderer;
import window;
import input;

struct Terminal
{
    window::Window* window;
    input::InputHandler* inputHandler;
    glyph::FontAtlas* fontAtlas;
    struct cursor
    {
        int x;
        int y;
    }
}

<*
 Initializes the following:
 - Window system
 - Window
 - Input system
 - Font atlas
 *>
fn Terminal*! create(int width, int height, ZString windowName, String fontName, float fontSize)
{
    window::initSystem();
    window::Window* window = window::create(width, height, windowName)!;

    input::InputHandler* inputHandler = input::createHandler({});
    
    glyph::FontAtlas* atlas = glyph::createFontAtlas(fontName, fontSize)!;

    Terminal* result = mem::new(Terminal, { window, inputHandler, atlas, {0,0} });
    return result;
}
fn void Terminal.free(Terminal* self)
{
    self.fontAtlas.free();
    self.inputHandler.free();
    window::terminateSystem();
    mem::free(self);
}
