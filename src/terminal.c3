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
    font_atlas::FontAtlas fontAtlas;
    uint[<2>] cursor;
    Grid grid;
    float[<3>] bg;
    float[<3>] fg;
}

<*
 Initializes the following:
 - Window system
 - Window
 - Input system
 - Font atlas
 - Grid of characters

 @require window_width > 0 && window_height > 0
 @require font_name.ptr != null && font_name.len > 0
 @require window_name != null
 @require font_size > 0
 @require grid_size > 0
 *>
fn void! Terminal.init(&self, int window_width = 0, int window_height = 0, String font_name, ZString window_name = "terminal", float font_size = 20.0f, usz grid_size = 32400, float[<3>] bg = {0,0,0}, float[<3>] fg = {1,1,1})
{
    window::init_system();
    self.window.init(window_width, window_height, window_name)!;
    defer catch { window::terminate_system(); }

    gl::enable(gl::GL_DEBUG_OUTPUT);
    gl::debugMessageCallback(&debug_message_callback, null);
    
    self.fontAtlas.init(font_name, font_size)!;
    defer catch { self.fontAtlas.free(); }

    self.grid = { mem::new_array(font_atlas::GridCharFg, grid_size),
                  mem::new_array(font_atlas::GridCharBg, grid_size),
                  (uint)((float)window_width  / self.fontAtlas.charMaxX),
                  (uint)((float)window_height / self.fontAtlas.charMaxY),
                  font_size };
    defer catch { self.grid.free(); }
    for (usz i = 0; i < grid_size; i++)
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
fn void Terminal.assign_char(&self, uint codepoint)
{
    self.grid.fg[self.cursor.x + self.grid.width * self.cursor.y].codepoint = codepoint;
}
<*
 Assigns background color to terminal's current cursor position

 @require self.grid.bg.ptr != null
 *>
fn void Terminal.assign_char_bg(&self, float[<3>] bg)
{
    self.grid.bg[self.cursor.x + self.grid.width * self.cursor.y].color = bg;
}
fn void Terminal.clear(&self)
{
    for (usz i = 0; i < self.grid.fg.len; i++)
    {
        self.grid.fg[i].codepoint = ' ';
        self.grid.bg[i].color = self.bg;
    }
}
<*
 Assigns foreground color to terminal's current cursor position

 @require self.grid.fg.ptr != null
 *>
fn void Terminal.assign_char_fg(&self, float[<3>] fg)
{
    self.grid.fg[self.cursor.x + self.grid.width * self.cursor.y].color = fg;
}
fn void Terminal.set_cursor(&self, uint[<2>] position) @inline
{
    self.cursor = position % { self.grid.width, self.grid.height };
}
fn void Terminal.move_cursor(&self, long[<2>] translation) @inline
{
    self.cursor = ((uint[<2>])((long[<2>])self.cursor + translation) % { self.grid.width, self.grid.height } + { self.grid.width, self.grid.height }) % { self.grid.width, self.grid.height };
}
macro Terminal.newline(&self, long row_translation = 1)
{
    self.set_cursor({ 0, (uint)((long)self.cursor.y + row_translation) });
}
fn void Terminal.pre_render(&self)
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
        self.cursor = { 0, 0 };
    }
}
fn void! Terminal.render(&self)
{
    self.fontAtlas.render_grid_bg(self.grid.bg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize)!;
    self.fontAtlas.render_grid_fg(self.grid.fg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize)!;

    self.window.clear_color(self.bg.r, self.bg.g, self.bg.b);
    self.window.refresh();
}
fn void Grid.free(&self) @local
{
    mem::free(self.bg);
    mem::free(self.fg);
}
fn void Terminal.free(&self)
{
    self.grid.free();
    self.fontAtlas.free();
    window::terminate_system();
}

fn void debug_message_callback(GLenum source,
                             GLenum type,
                             uint id,
                             GLenum severity,
                             usz length,
                             ZString message,
                             void* user_param) @private
{
    io::eprintfn("GL CALLBACK: type = 0x%x, severity = 0x%x, message = %s\n", type, severity, message);
}
