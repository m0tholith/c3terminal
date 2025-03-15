module terminal;

import glfw;
import opengl;
import glyph;
import window;
import input;

import std::core::mem;
import std::thread;
import std::io;
import std::math;

struct Grid @local
{
    font_atlas::GridCharFg[] fg;
    font_atlas::GridCharBg[] bg;
    union
    {
        struct
        {
            uint width;
            uint height;
        }
        uint[<2>] dimensions;
    }
    float fontSize;
    usz size;
}
struct Terminal
{
    window::Window window;
    font_atlas::FontAtlas fontAtlas;
    uint[<2>] cursor;
    Grid grid;
    float[<3>] bg;
    float[<3>] fg;
    uint[<2>] sco;
    uint[<2>] dec;
    // number of lines that will be clipped from the top of the screen
    uint scroll;
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

    self.grid = {
        .fg = mem::new_array(font_atlas::GridCharFg, grid_size),
        .bg = mem::new_array(font_atlas::GridCharBg, grid_size),
        .dimensions = {
            (uint)((float)window_width  / self.fontAtlas.charMaxX),
            (uint)((float)window_height / self.fontAtlas.charMaxY),
        },
        .fontSize = font_size,
        .size = grid_size,
    };
    defer catch { self.grid.free(); }
    self.bg = bg;
    self.fg = fg;
    for (usz i = 0; i < grid_size; i++)
    {
        self.grid.fg[i] = { ' ', fg };
        self.grid.bg[i].color = self.bg;
    }
}
<*
 Assigns character to terminal's current cursor position

 @require self.grid.fg.ptr != null
 *>
fn void Terminal.assign_char(&self, uint codepoint)
{
    self.grid.fg[self.get_grid_idx(self.cursor)].codepoint = codepoint;
}
<*
 Assigns background color to terminal's current cursor position

 @require self.grid.bg.ptr != null
 *>
fn void Terminal.assign_char_bg(&self, float[<3>] bg)
{
    self.grid.bg[self.get_grid_idx(self.cursor)].color = bg;
}
<*
 Assigns foreground color to terminal's current cursor position

 @require self.grid.fg.ptr != null
 *>
fn void Terminal.assign_char_fg(&self, float[<3>] fg)
{
    self.grid.fg[self.get_grid_idx(self.cursor)].color = fg;
}
macro void Terminal.clear(&self) => self.erase({ 0, 0 }, self.grid.size);
fn void Terminal.erase(&self, uint[<2>] start, usz length)
{
    for (usz i = self.get_grid_idx(start); i < length; i++)
    {
        self.grid.fg[i].codepoint = ' ';
        self.grid.bg[i].color = self.bg;
    }
}
macro usz Terminal.get_grid_idx(&self, uint[<2>] position) => ((usz)position.x + self.grid.width * (usz)(position.y + self.scroll)) % self.grid.size;
fn void Terminal.set_cursor(&self, uint[<2>] position) @inline
{
    self.cursor = { math::clamp(position.x, 0, self.grid.width), math::clamp(position.y, 0, self.grid.height) };
}
fn void Terminal.move_cursor_clamp(&self, long[<2>] translation) @inline
{
    long[<2>] new_cursor = (long[<2>])self.cursor + translation;
    self.cursor = { (uint)math::clamp(new_cursor.x, 0, self.grid.width - 1), (uint)math::clamp(new_cursor.y, 0, self.grid.height - 1) };
}
fn void Terminal.move_cursor(&self, long[<2>] translation)
{
    long[<2>] new_cursor = (long[<2>])self.cursor + translation + { 0, self.scroll };
    if (new_cursor.x < 0)
    {
        new_cursor.x = (long)self.grid.width - 1;
        new_cursor.y = new_cursor.y <= 0 ? 0 : new_cursor.y - 1;
    }
    else if (new_cursor.x >= self.grid.width)
    {
        new_cursor.x = 0;
        new_cursor.y = new_cursor.y >= self.grid.height ? (long)self.grid.height - 1 : new_cursor.y + 1;
    }
    if (new_cursor.y < 0)
    {
        new_cursor.y = 0;
    }
    else if (new_cursor.y >= self.grid.height)
    {
        self.scroll = (uint)(new_cursor.y - self.grid.height + 1) % (uint)(self.grid.size / self.grid.width);
        new_cursor.y = (long)self.grid.height - 1;
        io::printfn("scroll: %d", self.scroll);
    }
    self.cursor = (uint[<2>])new_cursor;
}
macro void Terminal.save_cursor_sco(&self) => self.sco = self.cursor;
macro void Terminal.save_cursor_dec(&self) => self.dec = self.cursor;
macro void Terminal.restore_cursor_sco(&self) => self.cursor = self.sco;
macro void Terminal.restore_cursor_dec(&self) => self.cursor = self.dec;
macro Terminal.newline(&self, long row_translation = 1)
{
    self.move_cursor({ 0, (uint)((long)self.cursor.y + row_translation) });
    self.cursor.x = 0;
}
fn void Terminal.scroll_lines(&self, long amount) @inline => self.scroll = (uint)((long)(self.scroll + amount) % (self.grid.size / self.grid.width));
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
        self.scroll = 0;
    }
}
fn void! Terminal.render(&self)
{
    usz char_start = (usz)(self.grid.width * self.scroll);
    self.fontAtlas.render_grid_bg(self.grid.bg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize, char_start)!;
    self.fontAtlas.render_grid_fg(self.grid.fg, self.window.width, self.window.height, self.grid.width, self.grid.height, self.grid.fontSize, char_start)!;

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
